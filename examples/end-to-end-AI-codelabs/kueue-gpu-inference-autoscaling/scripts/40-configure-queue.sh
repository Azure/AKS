#!/usr/bin/env bash
# Verify AKS ProvisioningRequest support and configure the Kueue queue.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

step "Checking ProvisioningRequest support"
if ! kubectl get crd provisioningrequests.autoscaling.x-k8s.io >/dev/null 2>&1; then
  fail "The ProvisioningRequest CRD isn't installed. Confirm Kubernetes 1.33+ and feature availability in this region before continuing."
fi
pass "ProvisioningRequest CRD is installed"

step "Applying the GPU queue"
kubectl apply -f "$ROOT/manifests/kueue-gpu-queue.yaml"
kubectl wait --for=condition=Active clusterqueue/gpu-inference-cluster-queue --timeout=2m
pass "GPU inference queue is active"
