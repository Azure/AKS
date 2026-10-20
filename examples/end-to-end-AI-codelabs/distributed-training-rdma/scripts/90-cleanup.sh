#!/usr/bin/env bash
# Remove codelab workloads, or delete every Azure resource created by the lab.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

MODE=${1:---workloads}
[[ "$MODE" == "--workloads" || "$MODE" == "--all" ]] || \
  fail "usage: $0 [--workloads|--all]"
require_command az "Install the Azure CLI."
require_command jq "Install jq."
SUBSCRIPTION_ID=$(subscription_id)

if [[ "$MODE" == "--all" ]]; then
  [[ "$LAB_REUSE_CLUSTER" != "true" ]] || fail \
    "--all is disabled in reuse mode so this script cannot delete a shared cluster"
  if ! GROUP_EXISTS=$(az group exists --subscription "$SUBSCRIPTION_ID" \
    --name "$LAB_RESOURCE_GROUP" -o tsv); then
    fail "could not check whether $LAB_RESOURCE_GROUP exists"
  fi
  case "$GROUP_EXISTS" in
    false)
      pass "$LAB_RESOURCE_GROUP is already absent"
      exit 0
      ;;
    true) ;;
    *) fail "unexpected response from 'az group exists': $GROUP_EXISTS" ;;
  esac
  REUSE_PROTECTED=$(az group show --subscription "$SUBSCRIPTION_ID" \
    --name "$LAB_RESOURCE_GROUP" --query "tags.\"$LAB_REUSE_PROTECTION_TAG\"" \
    -o tsv)
  [[ "$REUSE_PROTECTED" != "true" ]] || fail \
    "$LAB_RESOURCE_GROUP is persistently marked as a reused/shared cluster; --all is forbidden"
  resource_group_is_owned || fail \
    "refusing to delete $LAB_RESOURCE_GROUP without $LAB_OWNER_TAG=$LAB_OWNER_VALUE"

  step "Deleting Azure resources"
  az group delete --subscription "$SUBSCRIPTION_ID" --name "$LAB_RESOURCE_GROUP" \
    --yes --no-wait
  pass "Deletion requested for $LAB_RESOURCE_GROUP"
  exit 0
fi

require_command kubectl "Run: az aks install-cli"
cluster_exists || fail \
  "$LAB_CLUSTER does not exist; refusing to run kubectl against the current context"
require_lab_context
step "Deleting codelab workloads"
if ! namespace=$(kubectl get namespace "$LAB_NAMESPACE" --ignore-not-found -o json); then
  fail "could not inspect namespace $LAB_NAMESPACE"
fi
if [[ -n "$namespace" ]]; then
  owner=$(jq -r --arg key "$LAB_OWNER_TAG" \
    '.metadata.labels[$key] // ""' <<<"$namespace")
  [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail \
    "refusing to delete unowned namespace $LAB_NAMESPACE"
  kubectl delete namespace "$LAB_NAMESPACE" --wait=false
  pass "Namespace deletion requested"
else
  pass "$LAB_NAMESPACE is already absent"
fi
warn "The cluster and two expensive RDMA GPU nodes are still running. Use '$0 --all' when finished."
