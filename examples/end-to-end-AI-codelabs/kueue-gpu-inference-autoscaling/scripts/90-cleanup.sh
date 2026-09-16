#!/usr/bin/env bash
# Remove either the GPU workload resources or the entire lab resource group.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ "${1:-}" == "--all" ]]; then
  step "Deleting resource group $LAB_RESOURCE_GROUP"
  resource_group_is_owned || fail "Refusing to delete $LAB_RESOURCE_GROUP: it isn't tagged $LAB_OWNER_TAG=$LAB_OWNER_VALUE."
  az group delete --name "$LAB_RESOURCE_GROUP" --yes --no-wait
  pass "Deletion started. Azure continues deleting resources in the background."
  exit 0
fi

step "Deleting inference workload and queue"
if kubectl get namespace "$LAB_NAMESPACE" >/dev/null 2>&1; then
  NAMESPACE_OWNER=$(kubectl get namespace "$LAB_NAMESPACE" \
    -o jsonpath="{.metadata.labels.$LAB_OWNER_TAG}" 2>/dev/null || true)
  [[ "$NAMESPACE_OWNER" == "$LAB_OWNER_VALUE" ]] || fail "Refusing cleanup: namespace $LAB_NAMESPACE isn't owned by this codelab."
  kubectl delete -f "$ROOT/manifests/inference-job.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/manifests/kueue-gpu-queue.yaml" --ignore-not-found
else
  warn "Namespace $LAB_NAMESPACE doesn't exist; skipped workload and queue cleanup."
fi
pass "Deleted the workload and owned queue resources. The GPU pool can now scale to zero."

cat <<EOF

Watch the pool:
  az aks nodepool show -g $LAB_RESOURCE_GROUP --cluster-name $LAB_CLUSTER \\
    -n $LAB_GPU_POOL --query count -o tsv

Delete every lab resource when you finish:
  $ROOT/scripts/90-cleanup.sh --all
EOF
