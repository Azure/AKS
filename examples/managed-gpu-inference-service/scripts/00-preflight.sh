#!/usr/bin/env bash
# Check local tools, Azure access, feature registration, SKU availability, and quota.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Checking tools"
require_command az "Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
require_command kubectl "Run: az aks install-cli"
require_command python3 "Install Python 3 from https://python.org/downloads/"

AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || true)
[[ -n "$AZ_VERSION" ]] || fail "Azure CLI did not report a version."
version_ge "$AZ_VERSION" "$MIN_AZ_VERSION" ||
  fail "Azure CLI $AZ_VERSION is older than $MIN_AZ_VERSION."

AKS_PREVIEW_VERSION=$(az extension show --name aks-preview --query version -o tsv 2>/dev/null || true)
[[ -n "$AKS_PREVIEW_VERSION" ]] ||
  fail "aks-preview isn't installed. Run: az extension add --name aks-preview"
version_ge "$AKS_PREVIEW_VERSION" "$MIN_AKS_PREVIEW_VERSION" ||
  fail "aks-preview $AKS_PREVIEW_VERSION is older than $MIN_AKS_PREVIEW_VERSION."
KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' ||
  true)
[[ -n "$KUBECTL_VERSION" ]] || fail "kubectl did not report a client version."
version_ge "$KUBECTL_VERSION" "$MIN_KUBECTL_VERSION" ||
  fail "kubectl $KUBECTL_VERSION is older than $MIN_KUBECTL_VERSION."
pass "Azure CLI, aks-preview, kubectl, and Python 3 are ready"

step "Checking Azure sign-in"
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
[[ -n "$SUBSCRIPTION_ID" ]] ||
  fail "Sign in with 'az login', then select a subscription."
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
pass "Using $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

step "Checking required resource providers"
for provider in Microsoft.Compute Microsoft.ContainerService Microsoft.Network Microsoft.ManagedIdentity Microsoft.Storage; do
  state=$(az provider show \
    --namespace "$provider" \
    --query registrationState \
    -o tsv 2>/dev/null || true)
  [[ "$state" == "Registered" ]] ||
    fail "$provider is ${state:-not registered}. Run: az provider register --namespace $provider"
  pass "$provider is registered"
done

step "Checking managed GPU feature registration"
FEATURE_STATE=$(az feature show \
  --namespace "$FEATURE_NAMESPACE" \
  --name "$FEATURE_NAME" \
  --query properties.state \
  -o tsv 2>/dev/null || true)
[[ "$FEATURE_STATE" == "Registered" ]] ||
  fail "$FEATURE_NAME is ${FEATURE_STATE:-not registered}. Run 'az feature register --namespace $FEATURE_NAMESPACE --name $FEATURE_NAME', wait for Registered, then rerun preflight."
pass "$FEATURE_NAME is registered"

step "Propagating the managed GPU feature"
az provider register \
  --namespace "$FEATURE_NAMESPACE" \
  --wait \
  -o none
pass "$FEATURE_NAMESPACE registration is current"

step "Checking Kubernetes version availability"
VERSION_COUNT=$(az aks get-versions \
  --location "$LAB_LOCATION" \
  --query "length(values[?version=='$LAB_KUBERNETES_VERSION'])" \
  -o tsv)
[[ "$VERSION_COUNT" != "0" ]] ||
  fail "Kubernetes $LAB_KUBERNETES_VERSION isn't available in $LAB_LOCATION."
pass "Kubernetes $LAB_KUBERNETES_VERSION is available in $LAB_LOCATION"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

az vm list-usage --location "$LAB_LOCATION" -o json >"$TMP_DIR/usage.json"

check_sku() {
  local sku=$1
  local count=$2
  local require_gpu=$3
  local role=$4
  local output
  local sku_file="$TMP_DIR/${role// /-}.json"

  step "Checking $role SKU $sku"
  az vm list-skus \
    --location "$LAB_LOCATION" \
    --size "$sku" \
    --all \
    -o json >"$sku_file"

  output=$(python3 - "$sku_file" "$TMP_DIR/usage.json" "$sku" "$count" "$require_gpu" 2>&1 <<'PY'
import json
import re
import sys

sku_file, usage_file, expected_name, count, require_gpu = sys.argv[1:]
count = int(count)
require_gpu = require_gpu == "true"
matches = [item for item in json.load(open(sku_file)) if item.get("name") == expected_name]
if not matches:
    raise SystemExit(f"{expected_name} isn't listed in this region")
sku = matches[0]
if any(item.get("type") == "Location" for item in sku.get("restrictions", [])):
    raise SystemExit(f"{expected_name} isn't available for this subscription in this region")
capabilities = {item["name"]: item["value"] for item in sku.get("capabilities", [])}
try:
    vcpus = int(capabilities["vCPUs"])
except (KeyError, TypeError, ValueError):
    raise SystemExit(f"{expected_name} doesn't report a numeric vCPUs capability")
try:
    gpus = int(capabilities.get("GPUs", "0"))
except (TypeError, ValueError):
    gpus = 0
if require_gpu and gpus != 1:
    raise SystemExit(f"{expected_name} advertises {gpus} GPUs per node; this example requires exactly one")

def normalize(value):
    return re.sub(r"[ _]", "", value).lower()

family = sku.get("family", "")
quota = next(
    (
        item
        for item in json.load(open(usage_file))
        if normalize(item.get("name", {}).get("value", "")) == normalize(family)
    ),
    None,
)
if quota is None:
    raise SystemExit(f"quota family {family!r} isn't present in the regional usage list")
used = int(quota["currentValue"])
limit = int(quota["limit"])
required = vcpus * count
if limit - used < required:
    raise SystemExit(f"{family} has {limit-used} free virtual CPUs; {count} {expected_name} nodes need {required}")
print(f"{expected_name}: {vcpus} virtual CPUs, {gpus} GPU(s), quota {used}/{limit}; room for {count} node(s)")
PY
  ) || fail "$output"

  pass "$output"
}

check_sku "$LAB_SYSTEM_SKU" 2 false "system-node"
check_sku "$LAB_GPU_SKU" "$LAB_GPU_NODE_COUNT" true "GPU-node"

step "Checking total regional virtual CPU quota"
TOTAL_OUTPUT=$(python3 - "$TMP_DIR/system-node.json" "$TMP_DIR/GPU-node.json" \
  "$TMP_DIR/usage.json" "$LAB_GPU_NODE_COUNT" 2>&1 <<'PY'
import json
import sys

system_file, gpu_file, usage_file, gpu_count = sys.argv[1:]

def vcpus(path):
    sku = json.load(open(path))[0]
    values = {item["name"]: item["value"] for item in sku.get("capabilities", [])}
    return int(values["vCPUs"])

required = 2 * vcpus(system_file) + int(gpu_count) * vcpus(gpu_file)
quota = next(
    (
        item
        for item in json.load(open(usage_file))
        if item.get("name", {}).get("value") == "cores"
    ),
    None,
)
if quota is None:
    raise SystemExit("Total Regional vCPUs quota isn't present in the usage list")
used = int(quota["currentValue"])
limit = int(quota["limit"])
if limit - used < required:
    raise SystemExit(f"Total Regional vCPUs has {limit-used} free; the example needs {required}")
print(f"Total Regional vCPUs quota is {used}/{limit}; the example needs {required}")
PY
) || fail "$TOTAL_OUTPUT"
pass "$TOTAL_OUTPUT"

step "Result"
pass "Preflight passed. Continue with modules/01-cluster.md."
