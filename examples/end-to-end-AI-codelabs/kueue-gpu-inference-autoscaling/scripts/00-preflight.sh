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

step "Checking $LAB_GPU_SKU in $LAB_LOCATION"
SKU_JSON=$(az vm list-skus --location "$LAB_LOCATION" --size "$LAB_GPU_SKU" --all -o json)
SKU_COUNT=$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$SKU_JSON")
[[ "$SKU_COUNT" -gt 0 ]] || fail "$LAB_GPU_SKU isn't listed in $LAB_LOCATION. Set LAB_LOCATION or LAB_GPU_SKU."

LOCATION_RESTRICTIONS=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(r.get("type") == "Location" for r in d[0].get("restrictions", [])))' <<<"$SKU_JSON")
[[ "$LOCATION_RESTRICTIONS" -eq 0 ]] || fail "$LAB_GPU_SKU is restricted for this subscription in $LAB_LOCATION."
ZONE_RESTRICTIONS=$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(r.get("type") == "Zone" for r in d[0].get("restrictions", [])))' <<<"$SKU_JSON")
if [[ "$ZONE_RESTRICTIONS" -gt 0 ]]; then
  warn "$LAB_GPU_SKU has availability-zone restrictions; this lab creates a regional node pool without --zones."
fi

VCPUS=$(python3 -c 'import json,sys; d=json.load(sys.stdin)[0]; c={x["name"]:x["value"] for x in d.get("capabilities",[])}; print(c.get("vCPUs","unknown"))' <<<"$SKU_JSON")
FAMILY=$(python3 -c 'import json,sys; print(json.load(sys.stdin)[0].get("family","unknown"))' <<<"$SKU_JSON")
pass "$LAB_GPU_SKU is available ($VCPUS vCPUs, quota family $FAMILY)"

USAGE_JSON=$(az vm list-usage --location "$LAB_LOCATION" -o json)
QUOTA_RESULT=$(USAGE_JSON="$USAGE_JSON" python3 -c '
import json, os, sys
family, needed = sys.argv[1], sys.argv[2]
data = json.loads(os.environ["USAGE_JSON"])
normalize = lambda value: value.replace(" ", "").replace("_", "").lower()
row = next((x for x in data if normalize(x.get("name", {}).get("value", "")) == normalize(family)), None)
if row is None or needed == "unknown":
    print("unknown")
else:
    print(int(row["limit"]) - int(row["currentValue"]) - int(needed))
' "$FAMILY" "$VCPUS")
if [[ "$QUOTA_RESULT" == "unknown" ]]; then
  warn "Couldn't map the SKU to a quota row. Confirm quota in the Azure portal before continuing."
elif [[ "$QUOTA_RESULT" -lt 0 ]]; then
  fail "The $FAMILY quota doesn't have $VCPUS free vCPUs in $LAB_LOCATION."
else
  pass "The $FAMILY quota has capacity for one $LAB_GPU_SKU node"
fi

step "Result"
pass "Preflight passed. Continue with modules/02-create-cluster.md."
