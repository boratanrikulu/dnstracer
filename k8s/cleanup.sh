#!/bin/bash

echo "=== Cleaning up DNS Tracer Deployment ==="
echo ""

echo "Deleting all resources in dns-tracing namespace..."
kubectl delete namespace dns-tracing --ignore-not-found=true

echo "Cleaning up cluster role bindings..."
kubectl delete clusterrolebinding dnstracer --ignore-not-found=true
kubectl delete clusterrole dnstracer --ignore-not-found=true

echo ""
echo "Cleanup completed!"
echo ""
echo "To verify cleanup:"
echo "  kubectl get namespace dns-tracing"
echo "  kubectl get clusterrole dnstracer"
echo "  kubectl get clusterrolebinding dnstracer"