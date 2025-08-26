# DNS Tracer Kubernetes Deployment

This directory contains Kubernetes manifests to deploy the DNS tracer as a DaemonSet and test DNS tracing with example pods.

## Files

- `01-namespace.yaml` - Creates the `dns-tracing` namespace
- `02-rbac.yaml` - ServiceAccount, ClusterRole, and ClusterRoleBinding for the tracer
- `03-daemonset.yaml` - DaemonSet that runs the DNS tracer on each node
- `04-nginx.yaml` - Nginx deployment and services for testing
- `05-dns-test-client.yaml` - Test pods that generate DNS queries

## Quick Start

### 1. Deploy Everything
```bash
./deploy.sh
```

### 2. Monitor DNS Tracing
```bash
./test.sh monitor
```

### 3. View Logs
```bash
# DNS Tracer logs (captures DNS packets)
kubectl -n dns-tracing logs -l app=dnstracer -f

# Test client logs (shows DNS queries being made)
kubectl -n dns-tracing logs dns-test-client -f
```

### 4. Cleanup
```bash
./cleanup.sh
```

## Testing Scenarios

The deployment creates the following DNS test scenarios:

### Internal Pod-to-Service DNS Queries
- `dns-test-client` queries `nginx-service.dns-tracing.svc.cluster.local`
- `dns-test-client` queries `nginx-headless.dns-tracing.svc.cluster.local`
- These should generate DNS queries to CoreDNS that the tracer captures

### External DNS Queries  
- `dns-test-client` queries `google.com`, `kubernetes.io`
- `dns-test-external` queries `example.com`, `cloudflare.com`, `github.com`
- These go to external DNS servers and should be captured

## CNI Interface Configuration

The DaemonSet defaults to monitoring the `cni0` interface. You may need to adjust this based on your CNI:

### Common CNI Interfaces:
- **Flannel**: `flannel.1`
- **Calico**: `cali*` (multiple interfaces)  
- **Weave**: `weave`
- **Kind**: `kind-br-*`
- **Docker Desktop**: `docker0`

### Check Your CNI Interface:
```bash
# On a cluster node
ip link show | grep -E '(cni|flannel|weave|calico|docker|bridge)'
```

### Update Interface:
```bash
kubectl -n dns-tracing patch daemonset dnstracer -p '{"spec":{"template":{"spec":{"containers":[{"name":"dnstracer","env":[{"name":"DNSTRACER_INTERFACE","value":"flannel.1"}]}]}}}}'
```

## Expected Results

If working correctly, you should see:

1. **DNS Tracer Logs**: Captured DNS queries and responses with:
   - Source/destination IPs
   - DNS question names (e.g., `nginx-service.dns-tracing.svc.cluster.local`)
   - Query types (A, AAAA)
   - Response data

2. **Test Client Logs**: Successful DNS lookups and HTTP requests

## Troubleshooting

### No DNS Queries Captured
1. Check if the CNI interface is correct
2. Verify pods are generating DNS queries
3. Check if eBPF is supported on the nodes

### Pods Not Starting
1. Check if the Docker image is loaded: `minikube image load dnstracer:latest`
2. Verify cluster permissions
3. Check node resources

### Permission Errors
1. Ensure the cluster supports privileged pods
2. Check if security policies allow eBPF programs

## Manual Testing

```bash
# Check pod status
kubectl -n dns-tracing get pods -o wide

# Test DNS resolution from client pod
kubectl -n dns-tracing exec dns-test-client -- nslookup nginx-service

# Check service endpoints
kubectl -n dns-tracing get endpoints

# View network interfaces on a node (requires node access)
kubectl get nodes -o wide
```