# DNS Tracer

A high-performance DNS monitoring tool that uses eBPF to capture and analyze DNS queries and responses in real-time on Linux systems.

## Features

- **Real-time DNS monitoring** - Captures DNS traffic as it flows through network interfaces
- **eBPF-powered** - Uses efficient kernel-space filtering with minimal performance overhead
- **Dual buffer support** - Supports both modern ring buffers and legacy perf buffers
- **Detailed logging** - Structured logging of DNS queries, responses, and metadata
- **Multi-architecture** - Supports both x86_64 and ARM64 architectures

## Requirements

- Linux kernel with eBPF support (4.1+, recommended 5.8+ for ring buffers)
- Go 1.24 or later
- Clang compiler
- Root privileges (required for raw socket operations)

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/akshatagarwl/dnstracer.git
cd dnstracer
```

2. Install dependencies:
```bash
make deps
```

3. Build the project:
```bash
make build
```

### Docker Installation

1. Build multi-architecture Docker image:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t dnstracer .
```

2. Or build for current platform only:
```bash
docker build -t dnstracer .
```

3. Run with Docker Compose:
```bash
docker-compose up -d
```

### Quick Start

```bash
# Build and run locally
make run

# Or run with perf buffer mode
make run-perfbuf

# Docker
docker-compose up
```

## Usage

### Basic Usage

Run the DNS tracer with default settings:
```bash
sudo ./dnstracer
```

### Configuration

The tracer can be configured using environment variables:

- `DNSTRACER_USE_PERFBUF=true` - Force use of perf buffers instead of ring buffers
- `DNSTRACER_INTERFACE=eth0` - Specify network interface to monitor (defaults to eth0)

#### Docker Configuration

Set environment variables in `docker-compose.yml` or pass them with docker run:

```bash
docker run --privileged --network=host \
  -e DNSTRACER_INTERFACE=wlp3s0 \
  -v /sys/fs/bpf:/sys/fs/bpf:rw \
  dnstracer
```

### Example Output

```
time=2024-01-15T10:30:45.123Z level=INFO msg=dns type=query src=192.168.1.100:54321 dst=8.8.8.8:53 id=12345 question=google.com. qtype=A
time=2024-01-15T10:30:45.145Z level=INFO msg=dns type=response src=8.8.8.8:53 dst=192.168.1.100:54321 id=12345 question=google.com. qtype=A answer=142.250.191.78
```

## How It Works

1. **eBPF Program**: A socket filter program written in C that:
   - Attaches to raw sockets to intercept network packets
   - Parses Ethernet, IP, and UDP headers
   - Extracts DNS packets (port 53 traffic)
   - Stores events in kernel-space buffers

2. **Go Application**: A userspace program that:
   - Loads and attaches the eBPF program
   - Reads DNS events from kernel buffers
   - Parses DNS packet contents using the `miekg/dns` library
   - Outputs structured logs with query/response details

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Network       │    │   eBPF Program   │    │   Go App        │
│   Interface     │───▶│   (Kernel)       │───▶│   (Userspace)   │
│                 │    │   - Packet Parse │    │   - DNS Parse   │
└─────────────────┘    │   - Event Filter │    │   - Logging     │
                       └──────────────────┘    └─────────────────┘
```

## Development

### Build Commands

```bash
# Generate eBPF code
make generate

# Build binary
make build

# Clean artifacts
make clean

# Run tests
make test

# Install system-wide
make install
```

### Development Mode

For active development with automatic rebuilds:
```bash
make dev
```

### Testing eBPF Support

Check if your system supports eBPF:
```bash
make check-bpf
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure you're running with `sudo` or as root
   - Raw sockets require elevated privileges

2. **Interface Not Found**
   - Set your network interface using `DNSTRACER_INTERFACE=your_interface`
   - The program defaults to `eth0` if no interface is specified
   - Common interfaces: `eth0`, `ens33`, `wlan0`, `wlp3s0`

3. **eBPF Load Failures**
   - Check kernel eBPF support with `make check-bpf`
   - Ensure kernel headers are installed
   - Try using perf buffer mode: `DNSTRACER_USE_PERFBUF=true`

4. **Build Errors**
   - Install required dependencies: `make deps`
   - Ensure clang is installed: `sudo apt install clang` (Ubuntu/Debian)

### Checking Network Interface

List available network interfaces:
```bash
ip link show
```

Set a specific interface:
```bash
sudo DNSTRACER_INTERFACE=wlp3s0 ./dnstracer
```

## Use Cases

- **Network Security Monitoring** - Detect suspicious DNS queries and responses
- **DNS Forensics** - Analyze DNS traffic patterns and troubleshoot resolution issues
- **Performance Analysis** - Monitor DNS response times and query patterns
- **Compliance Auditing** - Track DNS queries for regulatory compliance

## License

Apache 2.0 License - see [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues and questions:
- Create an issue on GitHub
- Check existing issues for solutions
- Review troubleshooting section above
