#!/usr/bin/env bash
# Validate local tools, Azure access, RDMA SKU capabilities, and quota.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Checking tools"
require_command az "Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
require_command kubectl "Run: az aks install-cli"
require_command helm "Install Helm: https://helm.sh/docs/intro/install/"
require_command jq "Install jq: https://jqlang.github.io/jq/download/"
require_command python3 "Install Python 3: https://python.org/downloads/"
pass "Azure CLI, kubectl, Helm, jq, and Python 3 are installed"

step "Checking Azure sign-in"
SUBSCRIPTION_ID=$(subscription_id)
[[ -n "$SUBSCRIPTION_ID" ]] || fail "Sign in with 'az login', then select a subscription."
SUBSCRIPTION_NAME=$(az account show --subscription "$SUBSCRIPTION_ID" --query name -o tsv)
pass "Using $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

step "Checking resource providers"
for provider in Microsoft.Compute Microsoft.ContainerService Microsoft.Network Microsoft.ManagedIdentity; do
  state=$(az provider show --subscription "$SUBSCRIPTION_ID" --namespace "$provider" \
    --query registrationState -o tsv 2>/dev/null || true)
  [[ "$state" == "Registered" ]] || fail \
    "$provider is $state. Run: az provider register --subscription $SUBSCRIPTION_ID --namespace $provider"
  pass "$provider is registered"
done

if [[ "$LAB_REUSE_CLUSTER" == "true" ]]; then
  step "Checking the existing cluster"
  cluster_exists || fail "$LAB_CLUSTER wasn't found in resource group $LAB_RESOURCE_GROUP"
  state=$(az aks show --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" --query provisioningState -o tsv)
  [[ "$state" == "Succeeded" ]] || fail "$LAB_CLUSTER provisioning state is $state"
  pass "$LAB_CLUSTER is ready; Azure SKU and quota checks are skipped in reuse mode"
  exit 0
fi

step "Checking AKS InfiniBand placement support"
feature_state=$(az feature show --subscription "$SUBSCRIPTION_ID" \
  --namespace Microsoft.ContainerService --name AKSInfinibandSupport \
  --query properties.state -o tsv 2>/dev/null || true)
if [[ "$feature_state" == "Registered" ]]; then
  pass "AKSInfinibandSupport is registered"
else
  warn "AKSInfinibandSupport is $feature_state; scripts/10-create-cluster.sh will register it before creating the RDMA pool"
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

step "Checking RDMA GPU SKU $LAB_GPU_SKU in $LAB_LOCATION"
az vm list-skus --subscription "$SUBSCRIPTION_ID" --location "$LAB_LOCATION" \
  --size "$LAB_GPU_SKU" --resource-type virtualMachines -o json >"$TMP_DIR/gpu-sku.json"
GPU_RESULT=$(python3 - "$TMP_DIR/gpu-sku.json" "$LAB_GPU_SKU" 2>&1 <<'PY'
import json, sys
path, expected = sys.argv[1:]
rows = [row for row in json.load(open(path)) if row.get("name") == expected]
if not rows:
    raise SystemExit(f"FAIL|{expected} is not available to this subscription in this region")
row = rows[0]
caps = {item["name"]: item["value"] for item in row.get("capabilities", [])}
if caps.get("RdmaEnabled", "false").lower() != "true":
    raise SystemExit(f"FAIL|{expected} does not advertise RdmaEnabled=True")
try:
    vcpus, gpus = int(caps["vCPUs"]), int(caps["GPUs"])
except (KeyError, TypeError, ValueError):
    raise SystemExit(f"FAIL|{expected} does not report numeric vCPU and GPU capabilities")
print(f"PASS|{row.get('family','')}|{vcpus}|{gpus}")
PY
) || fail "${GPU_RESULT#FAIL|}"
IFS='|' read -r _ GPU_FAMILY GPU_VCPUS GPU_COUNT <<<"$GPU_RESULT"
(( GPU_COUNT >= LAB_GPU_PER_WORKER )) || fail \
  "$LAB_GPU_SKU has $GPU_COUNT GPUs, but each worker requests $LAB_GPU_PER_WORKER"
pass "$LAB_GPU_SKU exposes $GPU_COUNT GPUs, $GPU_VCPUS vCPUs, and RDMA"

step "Checking system SKU $LAB_SYSTEM_SKU"
az vm list-skus --subscription "$SUBSCRIPTION_ID" --location "$LAB_LOCATION" \
  --size "$LAB_SYSTEM_SKU" --resource-type virtualMachines -o json >"$TMP_DIR/system-sku.json"
SYSTEM_RESULT=$(python3 - "$TMP_DIR/system-sku.json" "$LAB_SYSTEM_SKU" 2>&1 <<'PY'
import json, sys
path, expected = sys.argv[1:]
rows = [row for row in json.load(open(path)) if row.get("name") == expected]
if not rows:
    raise SystemExit(f"FAIL|{expected} is not available to this subscription in this region")
row = rows[0]
caps = {item["name"]: item["value"] for item in row.get("capabilities", [])}
print(f"PASS|{row.get('family','')}|{int(caps['vCPUs'])}")
PY
) || fail "${SYSTEM_RESULT#FAIL|}"
IFS='|' read -r _ SYSTEM_FAMILY SYSTEM_VCPUS <<<"$SYSTEM_RESULT"
pass "$LAB_SYSTEM_SKU exposes $SYSTEM_VCPUS vCPUs"

step "Checking regional quota"
az vm list-usage --subscription "$SUBSCRIPTION_ID" --location "$LAB_LOCATION" \
  -o json >"$TMP_DIR/usage.json"
QUOTA_RESULT=$(python3 - "$TMP_DIR/usage.json" "$GPU_FAMILY" "$GPU_VCPUS" \
  "$LAB_GPU_NODE_COUNT" "$SYSTEM_FAMILY" "$SYSTEM_VCPUS" "$LAB_SYSTEM_NODE_COUNT" 2>&1 <<'PY'
import json, re, sys
usage_path, gpu_family, gpu_vcpus, gpu_nodes, system_family, system_vcpus, system_nodes = sys.argv[1:]
usage = json.load(open(usage_path))
def norm(value): return re.sub(r"[ _]", "", value).lower()
def quota(family):
    match = next((q for q in usage if norm(q.get("name", {}).get("value", "")) == norm(family)), None)
    if not match:
        raise SystemExit(f"FAIL|quota family {family!r} is missing")
    return int(match["currentValue"]), int(match["limit"])
g_used, g_limit = quota(gpu_family)
s_used, s_limit = quota(system_family)
g_required = int(gpu_vcpus) * int(gpu_nodes)
s_required = int(system_vcpus) * int(system_nodes)
if g_limit - g_used < g_required:
    raise SystemExit(f"FAIL|{gpu_family} has {g_limit-g_used} free vCPUs; the lab needs {g_required}")
if s_limit - s_used < s_required:
    raise SystemExit(f"FAIL|{system_family} has {s_limit-s_used} free vCPUs; the lab needs {s_required}")
total = next((q for q in usage if q.get("name", {}).get("value") == "cores"), None)
if total is None:
    raise SystemExit("FAIL|Total Regional vCPUs quota is missing")
used, limit = int(total["currentValue"]), int(total["limit"])
if limit - used < g_required + s_required:
    raise SystemExit(f"FAIL|Total Regional vCPUs has {limit-used} free; the lab needs {g_required+s_required}")
print(f"PASS|GPU quota {g_used}/{g_limit}; system quota {s_used}/{s_limit}; required vCPUs {g_required+s_required}")
PY
) || fail "${QUOTA_RESULT#FAIL|}"
pass "${QUOTA_RESULT#PASS|}"

step "Checking Kubernetes version"
RESOLVED_KUBERNETES_VERSION=$(resolve_kubernetes_version "$SUBSCRIPTION_ID") || fail \
  "AKS Kubernetes $LAB_KUBERNETES_VERSION is not offered in $LAB_LOCATION"
pass "AKS Kubernetes $LAB_KUBERNETES_VERSION resolves to patch $RESOLVED_KUBERNETES_VERSION"

step "Result"
pass "Preflight passed. Continue with modules/02-provision-cluster.md."
