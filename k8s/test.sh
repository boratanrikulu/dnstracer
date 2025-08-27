#!/bin/bash

echo "=== DNS Tracer Testing Script ==="
echo ""

# Function to show logs from all dnstracer pods
show_tracer_logs() {
    echo "=== DNS Tracer Logs ==="
    kubectl -n dns-tracing logs -l app=dnstracer --tail=50 --prefix=true 2>/dev/null || {
        echo "No dnstracer logs available yet"
    }
    echo ""
}

# Function to show test client logs
show_client_logs() {
    echo "=== DNS Test Client Logs ==="
    kubectl -n dns-tracing logs dns-test-client --tail=20 2>/dev/null || {
        echo "DNS test client not ready"
    }
    echo ""
    
    echo "=== External DNS Test Client Logs ==="
    kubectl -n dns-tracing logs dns-test-external --tail=20 2>/dev/null || {
        echo "External DNS test client not ready"
    }
    echo ""
}

# Function to check CNI interface
check_cni_interface() {
    echo "=== Checking CNI Interface ==="
    echo "Current DaemonSet interface setting:"
    kubectl -n dns-tracing get daemonset dnstracer -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DNSTRACER_INTERFACE")].value}' 2>/dev/null || echo "Not found"
    echo ""
    
    echo "Available network interfaces on nodes:"
    kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' '\n' | head -1 | while read node_ip; do
        echo "Node IP: $node_ip"
        echo "Run this on the node to check interfaces:"
        echo "  ip link show | grep -E '(cni|flannel|weave|calico|docker|bridge)'"
        echo ""
    done
}

# Main testing loop
main() {
    if [[ "$1" == "monitor" ]]; then
        echo "Monitoring mode - press Ctrl+C to exit"
        echo ""
        while true; do
            clear
            echo "=== DNS Tracer Monitoring - $(date) ==="
            echo ""
            
            # Show pod status
            echo "Pod Status:"
            kubectl -n dns-tracing get pods -o wide
            echo ""
            
            show_tracer_logs
            show_client_logs
            
            sleep 10
        done
    else
        # One-time status check
        echo "Pod Status:"
        kubectl -n dns-tracing get pods -o wide
        echo ""
        
        show_tracer_logs
        show_client_logs
        check_cni_interface
        
        echo "=== Commands for further investigation ==="
        echo "Monitor in real-time:"
        echo "  ./test.sh monitor"
        echo ""
        echo "Follow dnstracer logs:"
        echo "  kubectl -n dns-tracing logs -l app=dnstracer -f"
        echo ""
        echo "Follow test client logs:"
        echo "  kubectl -n dns-tracing logs dns-test-client -f"
        echo ""
        echo "Check services:"
        echo "  kubectl -n dns-tracing get svc"
        echo ""
        echo "Debug pod networking:"
        echo "  kubectl -n dns-tracing exec dns-test-client -- nslookup nginx-service"
        echo ""
        echo "Update CNI interface (if needed):"
        echo "  kubectl -n dns-tracing patch daemonset dnstracer -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"dnstracer\",\"env\":[{\"name\":\"DNSTRACER_INTERFACE\",\"value\":\"flannel.1\"}]}]}}}}'"
    fi
}

main "$@"