# DNS Tracer Makefile
.PHONY: generate build clean test install deps help

# Variables
BINARY_NAME := dnstracer
BUILD_DIR := .
BPF_SOURCE := bpf/tracer.bpf.c
BPF_INCLUDES := -I./bpf -I./bpf/include
BPF_CFLAGS := -O2 -g -Wall $(BPF_INCLUDES)
GO_LDFLAGS := -ldflags "-X main.version=$(shell git describe --tags --always --dirty 2>/dev/null || echo dev) -X main.buildTime=$(shell date -u +%Y-%m-%dT%H:%M:%S%Z)"

# Check required tools
CLANG := $(shell which clang 2>/dev/null)
ifeq ($(CLANG),)
$(error clang is required but not found)
endif

# Default target
all: build

# Generate eBPF Go code
generate:
	@echo "Generating eBPF Go code..."
	go generate ./internal/bpf/

# Build the binary
build: generate
	@echo "Building $(BINARY_NAME)..."
	go build $(GO_LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/dnstracer/

# Build static binary for Docker/Alpine
build-static: generate
	@echo "Building static $(BINARY_NAME) for Docker/Alpine..."
	CGO_ENABLED=0 GOOS=linux go build $(GO_LDFLAGS) -ldflags "-extldflags '-static'" -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/dnstracer/

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	go install github.com/cilium/ebpf/cmd/bpf2go@latest

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BUILD_DIR)/$(BINARY_NAME)
	rm -f internal/bpf/bpf_*.go
	rm -f internal/bpf/bpfringbuf_*.go
	rm -f internal/bpf/bpfperfbuf_*.go
	rm -f internal/bpf/*.o

# Test the project
test:
	@echo "Running tests..."
	go test -v ./...

# Install system-wide (requires sudo)
install: build
	@echo "Installing $(BINARY_NAME) to /usr/local/bin/"
	sudo cp $(BUILD_DIR)/$(BINARY_NAME) /usr/local/bin/
	sudo chmod +x /usr/local/bin/$(BINARY_NAME)

# Run the tracer (requires sudo)
run: build
	@echo "Running DNS tracer (requires sudo)..."
	sudo ./$(BINARY_NAME)

# Run with perf buffer
run-perfbuf: build
	@echo "Running DNS tracer with perf buffer (requires sudo)..."
	sudo DNSTRACER_USE_PERFBUF=true ./$(BINARY_NAME)

# Check BPF requirements
check-bpf:
	@echo "Checking eBPF requirements..."
	@echo "Kernel version: $$(uname -r)"
	@echo "Architecture: $$(uname -m)"
	@echo "Clang version: $$(clang --version | head -n1)"
	@if [ ! -f /proc/config.gz ] && [ ! -f /boot/config-$$(uname -r) ]; then \
		echo "Warning: Kernel config not found, cannot verify eBPF support"; \
	else \
		echo "Checking eBPF config..."; \
		(zcat /proc/config.gz 2>/dev/null || cat /boot/config-$$(uname -r) 2>/dev/null) | grep -E "CONFIG_BPF|CONFIG_HAVE_EBPF_JIT" || true; \
	fi

# Development mode - watch for changes and rebuild
dev:
	@echo "Development mode - watching for changes..."
	@while true; do \
		inotifywait -r -e modify --include='.*\.(go|c|h)$$' . 2>/dev/null || sleep 1; \
		echo "Files changed, rebuilding..."; \
		make build; \
	done

# Docker targets
docker-build: build-static
	@echo "Building Docker image for current platform..."
	docker build -t dnstracer .

docker-build-multi:
	@echo "Building multi-arch Docker image with buildx..."
	docker buildx build --platform linux/amd64,linux/arm64 -t dnstracer .

docker-build-push:
	@echo "Building and pushing multi-arch Docker image..."
	docker buildx build --platform linux/amd64,linux/arm64 -t dnstracer --push .

docker-run: docker-build
	@echo "Running DNS tracer in Docker..."
	docker-compose up

docker-run-bg: docker-build
	@echo "Running DNS tracer in Docker (background)..."
	docker-compose up -d

docker-stop:
	@echo "Stopping Docker containers..."
	docker-compose down

docker-clean:
	@echo "Cleaning Docker artifacts..."
	docker-compose down --rmi all --volumes --remove-orphans

# Show help
help:
	@echo "DNS Tracer Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Build the project (default)"
	@echo "  generate    - Generate eBPF Go code"
	@echo "  build       - Build the binary"
	@echo "  build-static - Build static binary for Docker/Alpine"
	@echo "  deps        - Install dependencies"
	@echo "  clean       - Clean build artifacts"
	@echo "  test        - Run tests"
	@echo "  install     - Install system-wide (requires sudo)"
	@echo "  run         - Run the tracer (requires sudo)"
	@echo "  run-perfbuf - Run with perf buffer (requires sudo)"
	@echo "  check-bpf   - Check eBPF requirements"
	@echo "  dev         - Development mode with file watching"
	@echo "  docker-build - Build Docker image for current platform"
	@echo "  docker-build-multi - Build multi-arch Docker image with buildx"
	@echo "  docker-build-push - Build and push multi-arch Docker image"
	@echo "  docker-run  - Run in Docker with logs"
	@echo "  docker-run-bg - Run in Docker in background"
	@echo "  docker-stop - Stop Docker containers"
	@echo "  docker-clean - Clean Docker artifacts"
	@echo "  help        - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make run"
	@echo "  make docker-build"
	@echo "  make docker-run-bg"
	@echo "  make clean && make all"
