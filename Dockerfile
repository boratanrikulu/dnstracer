# Minimal runtime image
FROM alpine:3.19

# Install ca-certificates for any TLS needs
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy pre-built binary from local build
COPY dnstracer /usr/local/bin/dnstracer

# Set executable permissions
RUN chmod +x /usr/local/bin/dnstracer

# Environment variables with defaults
ENV DNSTRACER_USE_PERFBUF=false
ENV DNSTRACER_INTERFACE=eth0

# Expose no ports (this is a network monitoring tool)
# EXPOSE

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep /usr/local/bin/dnstracer || exit 1

# Switch to root user for raw socket access
USER root

# Default command
CMD ["/usr/local/bin/dnstracer"]
