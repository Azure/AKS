#!/usr/bin/env bash
# Create or validate the two-node managed A100 pool used by the service.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_lab_context

step "Creating the managed GPU node pool"
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
  VALIDATION=$(python3 - "$LAB_GPU_SKU" "$LAB_GPU_NODE_COUNT" "$LAB_GPU_TAINT" \
    "$LAB_OWNER_TAG" "$LAB_OWNER_VALUE" "$POOL_JSON" 2>&1 <<'PY'
import json
import sys

(
    expected_sku,
    expected_count,
    expected_taint,
    owner_tag,
    owner_value,
    pool_json,
) = sys.argv[1:]
pool = json.loads(pool_json)
errors = []
if pool.get("vmSize") != expected_sku:
    errors.append(f"VM size is {pool.get('vmSize')}, expected {expected_sku}")
if int(pool.get("count", -1)) != int(expected_count):
    errors.append(f"node count is {pool.get('count')}, expected {expected_count}")
if pool.get("osType") != "Linux":
    errors.append(f"OS type is {pool.get('osType')}, expected Linux")
if pool.get("mode") != "User":
    errors.append(f"mode is {pool.get('mode')}, expected User")
if pool.get("osDiskType") != "Managed":
    errors.append(f"OS disk type is {pool.get('osDiskType')}, expected Managed")
if pool.get("enableAutoScaling"):
    errors.append("cluster autoscaler is enabled")
if expected_taint not in (pool.get("nodeTaints") or []):
    errors.append(f"taint {expected_taint} is missing")
if (pool.get("tags") or {}).get(owner_tag) != owner_value:
    errors.append(f"ownership tag {owner_tag}={owner_value} is missing")
profile = pool.get("gpuProfile") or {}
nvidia = profile.get("nvidia") or {}
if profile.get("driver") != "Install":
    errors.append(f"GPU driver profile is {profile.get('driver')}, expected Install")
if nvidia.get("managementMode") != "Managed":
    errors.append(f"management mode is {nvidia.get('managementMode')}, expected Managed")
if errors:
    raise SystemExit("; ".join(errors))
print("compatible")
PY
  ) || fail "Existing pool $LAB_GPU_POOL is incompatible: $VALIDATION"
  pass "$LAB_GPU_POOL already exists with the expected configuration"
else
  az aks nodepool add \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --cluster-name "$LAB_CLUSTER" \
    --name "$LAB_GPU_POOL" \
    --mode User \
    --node-count "$LAB_GPU_NODE_COUNT" \
    --node-vm-size "$LAB_GPU_SKU" \
    --node-osdisk-type Managed \
    --node-taints "$LAB_GPU_TAINT" \
    --enable-managed-gpu=true \
    --tags "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" \
    -o none
  pass "Created $LAB_GPU_POOL"
fi

step "Waiting for the GPU nodes"
for attempt in $(seq 1 90); do
  ready=$(ready_node_count "agentpool=$LAB_GPU_POOL")
  [[ "$ready" == "$LAB_GPU_NODE_COUNT" ]] && break
  [[ "$attempt" != "90" ]] || fail "The GPU nodes didn't become ready within 30 minutes."
  sleep 20
done

pass "$LAB_GPU_NODE_COUNT GPU nodes are ready"
