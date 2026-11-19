#!/usr/bin/env bash
# Remove the inference workload and GPU pool, or delete the complete resource group.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

[[ "$#" -le 1 ]] || fail "Usage: $0 [--all]"
case "${1:-}" in
  "" | --all) ;;
  *) fail "Usage: $0 [--all]" ;;
esac

if [[ "${1:-}" == "--all" ]]; then
  step "Deleting resource group $LAB_RESOURCE_GROUP"
  resource_group_is_owned ||
    fail "Refusing to delete $LAB_RESOURCE_GROUP: it isn't tagged $LAB_OWNER_TAG=$LAB_OWNER_VALUE."
  az group delete \
    --name "$LAB_RESOURCE_GROUP" \
    --yes \
    --no-wait
  pass "Resource group deletion started"
  exit 0
fi

require_lab_context

step "Checking Kubernetes object ownership"
objects=(
  "serviceaccount vllm $LAB_NAMESPACE"
  "deployment vllm $LAB_NAMESPACE"
  "service vllm $LAB_NAMESPACE"
  "poddisruptionbudget vllm $LAB_NAMESPACE"
  "job stage-model $LAB_NAMESPACE"
  "persistentvolumeclaim model-weights $LAB_NAMESPACE"
  "namespace $LAB_NAMESPACE"
  "storageclass $LAB_STORAGE_CLASS"
)
for object in "${objects[@]}"; do
  read -r kind name namespace <<<"$object"
  require_owned_object_or_absent "$kind" "$name" "${namespace:-}"
done

step "Deleting the inference workload"
if kubectl get namespace "$LAB_NAMESPACE" >/dev/null 2>&1; then
  kubectl delete -f "$ROOT/manifests/vllm-serving.yaml" \
    --ignore-not-found \
    --wait=true
  kubectl delete job stage-model \
    --namespace "$LAB_NAMESPACE" \
    --ignore-not-found \
    --wait=true
  kubectl delete persistentvolumeclaim model-weights \
    --namespace "$LAB_NAMESPACE" \
    --ignore-not-found \
    --wait=true
  kubectl delete namespace "$LAB_NAMESPACE" \
    --ignore-not-found \
    --wait=true
fi
kubectl delete storageclass "$LAB_STORAGE_CLASS" \
  --ignore-not-found \
  --wait=true
pass "Deleted the example-owned Kubernetes resources"

step "Deleting the managed GPU node pool"
POOL_LIST=$(az aks nodepool list \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  -o json)
POOL_JSON=$(python3 - "$LAB_GPU_POOL" "$POOL_LIST" <<'PY'
import json
import sys

name, pool_list = sys.argv[1:]
pool = next((item for item in json.loads(pool_list) if item.get("name") == name), None)
if pool is not None:
    print(json.dumps(pool))
PY
)

if [[ -n "$POOL_JSON" ]]; then
  POOL_OWNER=$(python3 - "$LAB_OWNER_TAG" "$POOL_JSON" <<'PY'
import json
import sys

owner_tag, pool_json = sys.argv[1:]
print((json.loads(pool_json).get("tags") or {}).get(owner_tag, ""))
PY
)
  [[ "$POOL_OWNER" == "$LAB_OWNER_VALUE" ]] ||
    fail "Refusing to delete $LAB_GPU_POOL: it isn't tagged $LAB_OWNER_TAG=$LAB_OWNER_VALUE."
  az aks nodepool delete \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --cluster-name "$LAB_CLUSTER" \
    --name "$LAB_GPU_POOL" \
    -o none
  pass "Deleted $LAB_GPU_POOL"
else
  pass "$LAB_GPU_POOL is already absent"
fi

warn "The AKS cluster and its two CPU system nodes still incur charges."
warn "Run '$ROOT/scripts/90-cleanup.sh --all' to delete the complete resource group."
