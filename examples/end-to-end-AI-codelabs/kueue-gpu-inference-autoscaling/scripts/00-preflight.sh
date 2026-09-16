#!/usr/bin/env bash
# Check local tools, Azure access, regional SKU availability, and quota.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Checking tools"
require_command az "Install the Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
require_command kubectl "Run: az aks install-cli"
require_command helm "Install Helm: https://helm.sh/docs/intro/install/"
require_command python3 "Install Python 3 from https://python.org/downloads/"
pass "Azure CLI, kubectl, Helm, and Python 3 are installed"

step "Checking Azure sign-in"
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
[[ -n "$SUBSCRIPTION_ID" ]] || fail "Sign in with 'az login', then select a subscription."
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
pass "Using $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

step "Checking required resource providers"
for provider in Microsoft.Compute Microsoft.ContainerService; do
  state=$(az provider show --namespace "$provider" --query registrationState -o tsv 2>/dev/null || true)
  if [[ "$state" == "Registered" ]]; then
    pass "$provider is registered"
  else
    fail "$provider is $state. Run: az provider register --namespace $provider"
  fi
done

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
az vm list-usage --location "$LAB_LOCATION" -o json >"$TMP_DIR/usage.json"

check_sku() {
  local sku=$1
  local count=$2
  local require_gpu=$3
  local role=$4
  local sku_file="$TMP_DIR/${role// /-}-sku.json"

  step "Checking $role SKU $sku in $LAB_LOCATION"
  az vm list-skus --location "$LAB_LOCATION" --size "$sku" --all -o json >"$sku_file"

  result=$(python3 - "$sku_file" "$TMP_DIR/usage.json" "$sku" "$count" "$require_gpu" 2>&1 <<'PY'
import json, re, sys
sku_file, usage_file, expected_sku, count, require_gpu = sys.argv[1:]
count = int(count)
require_gpu = require_gpu == "true"
skus = [s for s in json.load(open(sku_file)) if s.get("name") == expected_sku]
if not skus:
    raise SystemExit(f"FAIL|{expected_sku} isn't listed in this region")
sku = skus[0]
location_blocks = [r for r in sku.get("restrictions", []) if r.get("type") == "Location"]
if location_blocks:
    raise SystemExit(f"FAIL|{expected_sku} isn't available for this subscription in this region")
capabilities = {c["name"]: c["value"] for c in sku.get("capabilities", [])}
try:
    vcpus = int(capabilities["vCPUs"])
except (KeyError, TypeError, ValueError):
    raise SystemExit(f"FAIL|{expected_sku} doesn't report a numeric vCPUs capability")
try:
    gpus = int(capabilities.get("GPUs", "0"))
except (TypeError, ValueError):
    gpus = 0
if require_gpu and gpus != 1:
    raise SystemExit(
        f"FAIL|{expected_sku} advertises {gpus} GPUs per node; this codelab requires exactly one")
def norm(value):
    return re.sub(r"[ _]", "", value).lower()
family = sku.get("family", "")
quota = next((q for q in json.load(open(usage_file))
              if norm(q.get("name", {}).get("value", "")) == norm(family)), None)
if quota is None:
    raise SystemExit(f"FAIL|quota family {family!r} isn't present in the regional usage list")
used, limit = int(quota["currentValue"]), int(quota["limit"])
required = vcpus * count
if limit - used < required:
    raise SystemExit(
        f"FAIL|{family} has {limit-used} free vCPUs; {count} {expected_sku} nodes need {required}")
zone_warning = any(r.get("type") == "Zone" for r in sku.get("restrictions", []))
print(f"PASS|{expected_sku}: {vcpus} vCPUs, {gpus} GPU(s), quota {used}/{limit}; "
      f"room for {count} node(s)|{str(zone_warning).lower()}")
PY
  ) || {
    fail "${result#FAIL|}"
  }

  IFS='|' read -r verdict message zone_warning <<<"$result"
  [[ "$verdict" == "PASS" ]] || fail "$message"
  pass "$message"
  if [[ "$zone_warning" == "true" ]]; then
    warn "$sku has availability-zone restrictions; this codelab creates a regional pool without --zones."
  fi
}

check_sku "$LAB_SYSTEM_SKU" 2 false "system node"
check_sku "$LAB_GPU_SKU" "$LAB_GPU_MAX_COUNT" true "GPU node"

step "Result"
pass "Preflight passed. Continue with modules/02-create-cluster.md."
