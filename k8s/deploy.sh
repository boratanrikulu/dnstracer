#!/bin/bash

set -e

echo "=== DNS Tracer Kubernetes Deployment ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connection
echo "1. Checking cluster connection..."
kubectl cluster-info --request-timeout=5s || {
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
}

# Build the Docker image (if needed)
echo ""
echo "2. Building dnstracer Docker image..."
cd ..
make build-static
docker build -t dnstracer:latest .
cd k8s

# Load image into kind/minikube if needed
if kubectl get nodes -o json | grep -q '"containerRuntimeVersion":"containerd://.*-k3s"'; then
    echo "Detected k3s - image should be available"
elif kubectl get nodes -o json | grep -q 'minikube'; then
    echo "Detected minikube - loading image..."
    minikube image load dnstracer:latest
elif kubectl get nodes -o json | grep -q 'kind'; then
    echo "Detected kind - loading image..."
    kind load docker-image dnstracer:latest
fi

echo ""
echo "3. Deploying Kubernetes resources..."

# Apply all manifests
echo "   - Creating namespace and RBAC..."
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-rbac.yaml

echo "   - Deploying DaemonSet..."
kubectl apply -f 03-daemonset.yaml

echo "   - Deploying nginx server..."
kubectl apply -f 04-nginx.yaml

echo "   - Deploying DNS test clients..."
kubectl apply -f 05-dns-test-client.yaml

echo ""
echo "4. Waiting for pods to be ready..."
kubectl -n dns-tracing wait --for=condition=ready pod --all --timeout=60s || {
    echo "Warning: Some pods may not be ready yet"
    kubectl -n dns-tracing get pods
}

echo ""
echo "5. Deployment completed!"
echo ""
echo "=== Next Steps ==="
echo "Check pod status:"
echo "  kubectl -n dns-tracing get pods -o wide"
echo ""
echo "View dnstracer logs (adjust node name):"
echo "  kubectl -n dns-tracing logs -l app=dnstracer -f"
echo ""
echo "View test client logs:"
echo "  kubectl -n dns-tracing logs dns-test-client -f"
echo "  kubectl -n dns-tracing logs dns-test-external -f"
echo ""
echo "Check CNI interface (may need adjustment in DaemonSet):"
echo "  kubectl get nodes -o wide"
echo "  # SSH to node and run: ip link show | grep -E '(cni|flannel|weave|calico)'"
echo ""

# Show current status
echo "Current pod status:"
kubectl -n dns-tracing get pods -o wide