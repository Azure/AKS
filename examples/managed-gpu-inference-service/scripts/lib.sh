#!/usr/bin/env bash
# Shared configuration, ownership checks, and output helpers.
# shellcheck disable=SC2034

set -euo pipefail

: "${LAB_LOCATION:=westus2}"
: "${LAB_RESOURCE_GROUP:=aks-managed-gpu-inference}"
: "${LAB_CLUSTER:=aks-managed-gpu-inference}"
: "${LAB_KUBERNETES_VERSION:=1.35}"

readonly LAB_SYSTEM_SKU="Standard_D4s_v5"
readonly LAB_GPU_SKU="Standard_NC24ads_A100_v4"
readonly LAB_GPU_POOL="a100np"
readonly LAB_GPU_NODE_COUNT=2
readonly LAB_GPU_TAINT="sku=gpu:NoSchedule"
readonly LAB_NAMESPACE="managed-gpu-inference"
readonly LAB_STORAGE_CLASS="managed-gpu-model-blob"
readonly LAB_OWNER_LABEL="aks.azure.com/example"
readonly LAB_OWNER_TAG="aks-example"
readonly LAB_OWNER_VALUE="managed-gpu-inference-service"
readonly LAB_MODEL_ID="Qwen/Qwen2.5-7B-Instruct"
readonly MIN_AZ_VERSION="2.85.0"
readonly MIN_AKS_PREVIEW_VERSION="19.0.0b29"
readonly MIN_KUBECTL_VERSION="1.34.0"
readonly FEATURE_NAMESPACE="Microsoft.ContainerService"
readonly FEATURE_NAME="ManagedGPUExperiencePreview"

if [[ -t 1 ]]; then
  readonly GREEN=$'\033[32m'
  readonly YELLOW=$'\033[33m'
  readonly RED=$'\033[31m'
  readonly RESET=$'\033[0m'
else
  readonly GREEN="" YELLOW="" RED="" RESET=""
fi

step() { printf '\n=== %s ===\n' "$1"; }
pass() { printf '%sPASS%s  %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '%sWARN%s  %s\n' "$YELLOW" "$RESET" "$1"; }
fail() { printf '%sFAIL%s  %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 isn't installed. $2"
}

version_ge() {
  python3 - "$1" "$2" <<'PY'
import re
import sys

def parts(value):
    return tuple(int(part) for part in re.findall(r"\d+", value))

raise SystemExit(0 if parts(sys.argv[1]) >= parts(sys.argv[2]) else 1)
PY
}

cluster_exists() {
  az aks show \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" \
    >/dev/null 2>&1
}

resource_group_is_owned() {
  [[ "$(az group show --name "$LAB_RESOURCE_GROUP" \
    --query "tags.\"$LAB_OWNER_TAG\"" -o tsv 2>/dev/null || true)" == "$LAB_OWNER_VALUE" ]]
}

lab_context_name() {
  local subscription_id
  subscription_id=$(az account show --query id -o tsv 2>/dev/null) ||
    fail "Azure CLI couldn't read the active subscription."
  [[ -n "$subscription_id" ]] ||
    fail "Select an Azure subscription before accessing the cluster."
  printf '%s-%s-%s\n' "$LAB_CLUSTER" "$LAB_RESOURCE_GROUP" "$subscription_id"
}

require_lab_context() {
  local context expected
  expected=$(lab_context_name)
  context=$(kubectl config current-context 2>/dev/null || true)
  [[ "$context" == "$expected" ]] ||
    fail "kubectl context is '$context', expected '$expected'. Run 10-create-cluster.sh."
}

ready_node_count() {
  local selector=$1
  kubectl get nodes -l "$selector" -o json |
    python3 -c '
import json
import sys

nodes = json.load(sys.stdin).get("items", [])
print(
    sum(
        any(
            condition.get("type") == "Ready"
            and condition.get("status") == "True"
            for condition in node.get("status", {}).get("conditions", [])
        )
        for node in nodes
    )
)
'
}

object_is_owned() {
  local kind=$1
  local name=$2
  local namespace=${3:-}
  local args=(get "$kind" "$name")
  [[ -z "$namespace" ]] || args+=(--namespace "$namespace")
  [[ "$(kubectl "${args[@]}" -o json 2>/dev/null |
    python3 -c "import json,sys; print((json.load(sys.stdin).get('metadata', {}).get('labels', {}) or {}).get('$LAB_OWNER_LABEL', ''))" 2>/dev/null || true)" == "$LAB_OWNER_VALUE" ]]
}

require_owned_object_or_absent() {
  local kind=$1
  local name=$2
  local namespace=${3:-}
  local args=(get "$kind" "$name")
  [[ -z "$namespace" ]] || args+=(--namespace "$namespace")
  if kubectl "${args[@]}" >/dev/null 2>&1; then
    object_is_owned "$kind" "$name" "$namespace" ||
      fail "$kind/$name already exists without the $LAB_OWNER_LABEL=$LAB_OWNER_VALUE label."
  fi
}
