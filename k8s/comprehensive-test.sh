#!/bin/bash

echo "=== Comprehensive DNS Tracing Setup ==="
echo ""

# Deploy the comprehensive DaemonSet instead of the single interface one
echo "1. Deploying comprehensive DNS tracer (multiple interfaces)..."
kubectl apply -f 06-comprehensive-daemonset.yaml

echo ""
echo "2. Waiting for pods to be ready..."
kubectl -n dns-tracing wait --for=condition=ready pod -l app=dnstracer-comprehensive --timeout=60s || {
    echo "Warning: Some pods may not be ready yet"
}

echo ""
echo "3. Checking pod status..."
kubectl -n dns-tracing get pods -l app=dnstracer-comprehensive -o wide

echo ""
echo "=== Comprehensive DNS Monitoring Active ==="
echo ""
echo "This setup monitors:"
echo "  • bridge interface (internal K8s DNS)"
echo "  • docker0 interface (Docker DNS)"  
echo "  • eth0 interface (external DNS)"
echo ""
echo "View logs from all tracers:"
echo "  kubectl -n dns-tracing logs -l app=dnstracer-comprehensive --all-containers=true -f --prefix=true"
echo ""
echo "View logs from specific tracer:"
echo "  kubectl -n dns-tracing logs -l app=dnstracer-comprehensive -c dnstracer-bridge -f"
echo "  kubectl -n dns-tracing logs -l app=dnstracer-comprehensive -c dnstracer-docker -f"
echo "  kubectl -n dns-tracing logs -l app=dnstracer-comprehensive -c dnstracer-external -f"
echo ""

# Show current logs from all containers
echo "Current DNS tracing activity:"
kubectl -n dns-tracing logs -l app=dnstracer-comprehensive --all-containers=true --tail=10 --prefix=true 2>/dev/null || echo "No logs available yet"