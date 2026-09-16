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
resources=(
  "namespace/$LAB_NAMESPACE"
  "resourceflavor/gpu-inference"
  "provisioningrequestconfig/gpu-inference"
  "admissioncheck/gpu-inference-provisioning"
  "clusterqueue/gpu-inference-cluster-queue"
  "localqueue/$LAB_NAMESPACE/gpu-inference"
)
for resource in "${resources[@]}"; do
  IFS=/ read -r kind namespace name <<<"$resource"
  if [[ -z "${name:-}" ]]; then
    name=$namespace
    namespace=""
  fi
  kubectl_args=(get "$kind" "$name")
  [[ -z "$namespace" ]] || kubectl_args+=(--namespace "$namespace")
  if kubectl "${kubectl_args[@]}" >/dev/null 2>&1; then
    owner=$(kubectl "${kubectl_args[@]}" \
      -o jsonpath="{.metadata.labels.$LAB_OWNER_TAG}" 2>/dev/null || true)
    [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail "$kind/$name already exists without the $LAB_OWNER_TAG=$LAB_OWNER_VALUE ownership label."
  fi
done
kubectl apply -f "$ROOT/manifests/kueue-gpu-queue.yaml"
kubectl wait --for=condition=Active clusterqueue/gpu-inference-cluster-queue --timeout=2m
pass "GPU inference queue is active"
