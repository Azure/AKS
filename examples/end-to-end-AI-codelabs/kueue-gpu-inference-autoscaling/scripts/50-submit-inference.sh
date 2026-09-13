#!/usr/bin/env bash
# Submit the inference validation Job through Kueue.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

step "Confirming the GPU pool is empty"
COUNT=$(az aks nodepool show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  --name "$LAB_GPU_POOL" \
  --query count -o tsv)
[[ "$COUNT" == "0" ]] || fail "$LAB_GPU_POOL has $COUNT nodes. Start from zero to observe the full flow."
pass "$LAB_GPU_POOL has zero nodes"

step "Submitting the inference workload"
kubectl delete -f "$ROOT/manifests/inference-job.yaml" --ignore-not-found --wait=true
kubectl apply -f "$ROOT/manifests/inference-job.yaml"
pass "Submitted $LAB_JOB in a suspended state"

cat <<EOF

Run this in another terminal:
  $ROOT/scripts/60-watch-flow.sh
EOF
