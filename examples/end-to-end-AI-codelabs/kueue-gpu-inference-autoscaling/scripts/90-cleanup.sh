#!/usr/bin/env bash
# Remove either the GPU workload resources or the entire lab resource group.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ "${1:-}" == "--all" ]]; then
  step "Deleting resource group $LAB_RESOURCE_GROUP"
  az group delete --name "$LAB_RESOURCE_GROUP" --yes --no-wait
  pass "Deletion started. Azure continues deleting resources in the background."
  exit 0
fi

step "Deleting inference workload and queue"
kubectl delete -f "$ROOT/manifests/inference-job.yaml" --ignore-not-found
kubectl delete -f "$ROOT/manifests/kueue-gpu-queue.yaml" --ignore-not-found
pass "Deleted the workload and queue. The GPU pool can now scale to zero."

cat <<EOF

Watch the pool:
  az aks nodepool show -g $LAB_RESOURCE_GROUP --cluster-name $LAB_CLUSTER \\
    -n $LAB_GPU_POOL --query count -o tsv

Delete every lab resource when you finish:
  $ROOT/scripts/90-cleanup.sh --all
EOF
