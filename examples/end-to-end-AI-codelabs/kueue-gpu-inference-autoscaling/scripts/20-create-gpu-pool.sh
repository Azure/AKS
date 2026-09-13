#!/usr/bin/env bash
# Create a conventional GPU node pool that the cluster autoscaler can scale to zero.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

cluster_exists || fail "Cluster $LAB_CLUSTER doesn't exist. Run 10-create-cluster.sh first."

step "Creating autoscaling GPU node pool"
if az aks nodepool show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  --name "$LAB_GPU_POOL" >/dev/null 2>&1; then
  pass "$LAB_GPU_POOL already exists"
else
  az aks nodepool add \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --cluster-name "$LAB_CLUSTER" \
    --name "$LAB_GPU_POOL" \
    --mode User \
    --node-vm-size "$LAB_GPU_SKU" \
    --node-count 0 \
    --enable-cluster-autoscaler \
    --min-count 0 \
    --max-count "$LAB_GPU_MAX_COUNT" \
    --node-taints "$LAB_GPU_TAINT" \
    --labels workload=gpu-inference \
    -o none
  pass "Created $LAB_GPU_POOL with a 0–$LAB_GPU_MAX_COUNT autoscaling range"
fi

step "Checking the zero-node starting state"
COUNT=$(az aks nodepool show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  --name "$LAB_GPU_POOL" \
  --query count -o tsv)
[[ "$COUNT" == "0" ]] || fail "$LAB_GPU_POOL has $COUNT nodes. Scale it to zero before continuing."
pass "$LAB_GPU_POOL starts at zero nodes"

cat <<'EOF'

This lab intentionally doesn't use --enable-managed-gpu=true. Managed GPU node
pools don't support cluster autoscaler during preview. This conventional pool
uses the AKS-installed driver; the next script installs the NVIDIA device plugin.
EOF
