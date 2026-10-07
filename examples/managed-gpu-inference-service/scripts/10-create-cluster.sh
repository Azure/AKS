#!/usr/bin/env bash
# Create the AKS cluster with a CPU-only system node pool and Blob CSI driver.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Creating the resource group"
if az group show --name "$LAB_RESOURCE_GROUP" >/dev/null 2>&1; then
  resource_group_is_owned ||
    fail "$LAB_RESOURCE_GROUP already exists without the $LAB_OWNER_TAG=$LAB_OWNER_VALUE ownership tag."
  pass "$LAB_RESOURCE_GROUP already exists and is owned by this example"
else
  az group create \
    --name "$LAB_RESOURCE_GROUP" \
    --location "$LAB_LOCATION" \
    --tags "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" \
    -o none
  pass "Created and tagged $LAB_RESOURCE_GROUP"
fi

step "Creating the AKS cluster"
if cluster_exists; then
  CLUSTER_JSON=$(az aks show \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" \
    -o json)
  CLUSTER_RESULT=$(python3 - "$LAB_LOCATION" "$LAB_KUBERNETES_VERSION" "$CLUSTER_JSON" 2>&1 <<'PY'
import json
import sys

expected_location, expected_version, cluster_json = sys.argv[1:]
cluster = json.loads(cluster_json)
errors = []
if cluster.get("location") != expected_location:
    errors.append(
        f"location is {cluster.get('location')}, expected {expected_location}"
    )
actual_version = cluster.get("kubernetesVersion", "")
expected_parts = expected_version.split(".")
actual_parts = actual_version.split(".")
if actual_parts[: len(expected_parts)] != expected_parts:
    errors.append(
        "Kubernetes version is "
        f"{actual_version}, expected {expected_version}"
    )
if errors:
    raise SystemExit("; ".join(errors))
print("compatible")
PY
  ) || fail "Existing cluster is incompatible: $CLUSTER_RESULT"
  SYSTEM_POOL=$(az aks nodepool show \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --cluster-name "$LAB_CLUSTER" \
    --name system \
    -o json)
  SYSTEM_RESULT=$(python3 - "$LAB_SYSTEM_SKU" "$SYSTEM_POOL" 2>&1 <<'PY'
import json
import sys

expected_sku, pool_json = sys.argv[1:]
pool = json.loads(pool_json)
errors = []
if pool.get("vmSize") != expected_sku:
    errors.append(f"system VM size is {pool.get('vmSize')}, expected {expected_sku}")
if int(pool.get("count", -1)) != 2:
    errors.append(f"system node count is {pool.get('count')}, expected 2")
if pool.get("mode") != "System":
    errors.append(f"system pool mode is {pool.get('mode')}, expected System")
if pool.get("osType") != "Linux":
    errors.append(f"system pool OS type is {pool.get('osType')}, expected Linux")
if errors:
    raise SystemExit("; ".join(errors))
print("compatible")
PY
  ) || fail "Existing cluster is incompatible: $SYSTEM_RESULT"
  pass "$LAB_CLUSTER already exists in the example-owned resource group"
else
  az aks create \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" \
    --location "$LAB_LOCATION" \
    --kubernetes-version "$LAB_KUBERNETES_VERSION" \
    --nodepool-name system \
    --node-count 2 \
    --node-vm-size "$LAB_SYSTEM_SKU" \
    --enable-managed-identity \
    --enable-blob-driver \
    --generate-ssh-keys \
    -o none
  pass "Created $LAB_CLUSTER"
fi

LAB_CONTEXT=$(lab_context_name)
az aks get-credentials \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --name "$LAB_CLUSTER" \
  --context "$LAB_CONTEXT" \
  --overwrite-existing \
  -o none

require_lab_context

BLOB_DRIVER=$(az aks show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --name "$LAB_CLUSTER" \
  --query storageProfile.blobCsiDriver.enabled \
  -o tsv)
[[ "$BLOB_DRIVER" == "true" ]] || fail "The Blob CSI driver isn't enabled."

READY_SYSTEM_NODES=$(ready_node_count "agentpool=system")
[[ "$READY_SYSTEM_NODES" == "2" ]] ||
  fail "Expected 2 ready system nodes, found $READY_SYSTEM_NODES."

pass "Connected to $LAB_CLUSTER with 2 ready system nodes and Blob CSI enabled"
