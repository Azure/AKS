#!/usr/bin/env bash
# Verify the managed profile, CUDA access, and DCGM metrics on every GPU node.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

DCGM_ONLY=false
case "${1:-}" in
  "") ;;
  --dcgm-only) DCGM_ONLY=true ;;
  *) fail "Usage: $0 [--dcgm-only]" ;;
esac

require_lab_context

step "Checking the managed GPU profile"
PROFILE=$(az aks nodepool show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  --name "$LAB_GPU_POOL" \
  --query gpuProfile \
  -o json)

PROFILE_RESULT=$(python3 - "$PROFILE" 2>&1 <<'PY'
import json
import sys

profile = json.loads(sys.argv[1]) or {}
nvidia = profile.get("nvidia") or {}
if profile.get("driver") != "Install":
    raise SystemExit(f"driver is {profile.get('driver')}, expected Install")
if nvidia.get("managementMode") != "Managed":
    raise SystemExit(
        f"management mode is {nvidia.get('managementMode')}, expected Managed"
    )
print("driver=Install, nvidia.managementMode=Managed")
PY
) || fail "$PROFILE_RESULT"
pass "$PROFILE_RESULT"

GPU_NODES=$(kubectl get nodes \
  -l "agentpool=$LAB_GPU_POOL" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
GPU_NODE_COUNT=$(printf '%s\n' "$GPU_NODES" | grep -c . || true)
[[ "$GPU_NODE_COUNT" == "$LAB_GPU_NODE_COUNT" ]] ||
  fail "Expected $LAB_GPU_NODE_COUNT GPU nodes, found $GPU_NODE_COUNT."

step "Creating the validation namespace"
require_owned_object_or_absent namespace "$LAB_NAMESPACE"
kubectl apply -f "$ROOT/manifests/namespace.yaml" >/dev/null

for node in $GPU_NODES; do
  step "Checking $node"

  READY=$(kubectl get node "$node" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  [[ "$READY" == "True" ]] || fail "$node isn't Ready."

  ALLOCATABLE=$(kubectl get node "$node" \
    -o jsonpath='{.status.allocatable.nvidia\.com/gpu}')
  [[ "$ALLOCATABLE" == "1" ]] ||
    fail "$node advertises ${ALLOCATABLE:-no} GPU, expected 1."

  DCGM_LABEL=$(kubectl get node "$node" \
    -o jsonpath='{.metadata.labels.kubernetes\.azure\.com/dcgm-exporter}')
  [[ "$DCGM_LABEL" == "enabled" ]] ||
    fail "$node doesn't have the managed DCGM exporter label."

  if [[ "$DCGM_ONLY" == "false" ]]; then
    VALIDATION_NAME="gpu-validation-${node##*-}"
    require_owned_object_or_absent pod "$VALIDATION_NAME" "$LAB_NAMESPACE"
    kubectl delete pod "$VALIDATION_NAME" \
      --namespace "$LAB_NAMESPACE" \
      --ignore-not-found \
      --wait=true \
      >/dev/null

    sed \
      -e "s/name: gpu-validation-node/name: $VALIDATION_NAME/" \
      -e "s/NODE_NAME/$node/" \
      "$ROOT/manifests/gpu-smoke-test.yaml" |
      kubectl apply -f - >/dev/null

    if ! kubectl wait \
      --namespace "$LAB_NAMESPACE" \
      --for=jsonpath='{.status.phase}'=Succeeded \
      "pod/$VALIDATION_NAME" \
      --timeout=900s \
      >/dev/null 2>&1; then
      kubectl describe pod "$VALIDATION_NAME" --namespace "$LAB_NAMESPACE"
      kubectl logs "$VALIDATION_NAME" --namespace "$LAB_NAMESPACE" || true
      fail "CUDA validation failed on $node."
    fi

    kubectl logs "$VALIDATION_NAME" --namespace "$LAB_NAMESPACE" |
      grep -q "CUDA_OK" || fail "CUDA validation didn't report success on $node."
    pass "A container allocated CUDA memory on $node"
  fi

  DCGM_NAME="dcgm-validation-${node##*-}"
  require_owned_object_or_absent pod "$DCGM_NAME" "$LAB_NAMESPACE"
  kubectl delete pod "$DCGM_NAME" \
    --namespace "$LAB_NAMESPACE" \
    --ignore-not-found \
    --wait=true \
    >/dev/null

  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: $DCGM_NAME
  namespace: $LAB_NAMESPACE
  labels:
    app.kubernetes.io/name: dcgm-validation
    app.kubernetes.io/part-of: managed-gpu-inference-service
    $LAB_OWNER_LABEL: $LAB_OWNER_VALUE
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  enableServiceLinks: false
  hostNetwork: true
  nodeSelector:
    kubernetes.io/hostname: $node
  tolerations:
    - key: sku
      operator: Equal
      value: gpu
      effect: NoSchedule
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: probe
      image: mcr.microsoft.com/azurelinux/base/core:3.0
      command:
        - /bin/sh
        - -c
        - curl --fail --silent --max-time 15 http://localhost:19400/metrics
      resources:
        requests:
          cpu: 25m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
EOF

  if ! kubectl wait \
    --namespace "$LAB_NAMESPACE" \
    --for=jsonpath='{.status.phase}'=Succeeded \
    "pod/$DCGM_NAME" \
    --timeout=180s \
    >/dev/null 2>&1; then
    kubectl describe pod "$DCGM_NAME" --namespace "$LAB_NAMESPACE"
    fail "DCGM validation failed on $node."
  fi

  kubectl logs "$DCGM_NAME" --namespace "$LAB_NAMESPACE" |
    grep -q "DCGM_FI_DEV_GPU_UTIL" ||
    fail "DCGM metrics on $node don't include DCGM_FI_DEV_GPU_UTIL."
  pass "DCGM metrics are available on $node"

  if [[ "$DCGM_ONLY" == "true" ]]; then
    kubectl delete pod "$DCGM_NAME" \
      --namespace "$LAB_NAMESPACE" \
      --ignore-not-found \
      --wait=true \
      >/dev/null
  else
    kubectl delete pod "$VALIDATION_NAME" "$DCGM_NAME" \
      --namespace "$LAB_NAMESPACE" \
      --ignore-not-found \
      --wait=true \
      >/dev/null
  fi
done

if [[ "$DCGM_ONLY" == "true" ]]; then
  pass "Managed DCGM metrics verified on $GPU_NODE_COUNT node(s)"
else
  pass "Managed GPU access verified on $GPU_NODE_COUNT node(s)"
fi
