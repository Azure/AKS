#!/usr/bin/env bash
# Shared configuration and helpers for the RDMA distributed-training codelab.
# shellcheck disable=SC2034 # Constants are consumed by scripts that source this file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly ROOT

: "${LAB_SUBSCRIPTION:=}"
: "${LAB_LOCATION:=southcentralus}"
: "${LAB_RESOURCE_GROUP:=aks-rdma-training-lab}"
: "${LAB_CLUSTER:=aks-rdma-training}"
: "${LAB_KUBERNETES_VERSION:=1.35}"
: "${LAB_SYSTEM_SKU:=Standard_D4s_v5}"
: "${LAB_GPU_SKU:=Standard_ND96amsr_A100_v4}"
: "${LAB_GPU_POOL:=rdmagpu}"
: "${LAB_NODE_SELECTOR_KEY:=aks-codelab.azure.com/rdma-training}"
: "${LAB_NODE_SELECTOR_VALUE:=true}"
: "${LAB_SYSTEM_NODE_COUNT:=1}"
readonly LAB_GPU_NODE_COUNT=2
readonly LAB_GPU_PER_WORKER=1
readonly LAB_GPU_TAINT="nvidia.com/gpu=present:NoSchedule"
: "${LAB_NAMESPACE:=rdma-training}"
: "${LAB_RDMA_RESOURCE:=rdma/shared_ib}"
: "${LAB_GRADIENT_MIB:=256}"
: "${LAB_WARMUP_STEPS:=3}"
: "${LAB_MEASURE_STEPS:=10}"
: "${LAB_MIN_IB_GBPS:=150}"
: "${LAB_MAX_IB_LATENCY_US:=10}"
: "${LAB_MIN_SPEEDUP:=2.0}"
: "${LAB_REUSE_CLUSTER:=false}"
: "${LAB_REUSE_RDMA_STACK:=false}"
: "${LAB_RESULTS_DIR:=$ROOT/.results}"

readonly LAB_OWNER_TAG="aks-codelab"
readonly LAB_OWNER_VALUE="distributed-training-rdma"
readonly LAB_REUSE_PROTECTION_TAG="aks-codelab-reuse-protected"
readonly NETWORK_OPERATOR_VERSION="26.4.0"
readonly NVIDIA_DEVICE_PLUGIN_VERSION="0.17.4"
readonly NVIDIA_PYTORCH_IMAGE="ghcr.io/azure/aks-rdma-infiniband/ibtools@sha256:dcc502375af37e42dcdd75f758d406282007ff01590551822dafc03d740e02ce"
readonly PEERMEM_IMAGE="mcr.microsoft.com/mirror/docker/library/ubuntu@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54"

if [[ -t 1 ]]; then
  readonly GREEN=$'\033[32m' YELLOW=$'\033[33m' RED=$'\033[31m' RESET=$'\033[0m'
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

subscription_id() {
  if [[ -n "$LAB_SUBSCRIPTION" ]]; then
    printf '%s\n' "$LAB_SUBSCRIPTION"
  else
    az account show --query id -o tsv 2>/dev/null
  fi
}

resolve_kubernetes_version() {
  local subscription=$1 output
  output=$(az aks get-versions --subscription "$subscription" --location "$LAB_LOCATION" -o json)
  python3 -c '
import json, sys
requested = sys.argv[1]
data = json.load(sys.stdin)
patches = {
    patch
    for minor in data.get("values", [])
    for patch in (minor.get("patchVersions") or {}).keys()
}
def key(version):
    return tuple(int(part) for part in version.split("."))
if requested.count(".") == 1:
    matches = [version for version in patches if version.startswith(requested + ".")]
    if matches:
        print(max(matches, key=key))
        raise SystemExit(0)
if requested in patches:
    print(requested)
    raise SystemExit(0)
raise SystemExit(f"AKS Kubernetes {requested} is not offered in the region")
' "$LAB_KUBERNETES_VERSION" <<<"$output"
}

cluster_exists() {
  local subscription
  subscription=$(subscription_id)
  [[ -n "$subscription" ]] && az aks show --subscription "$subscription" \
    --resource-group "$LAB_RESOURCE_GROUP" --name "$LAB_CLUSTER" >/dev/null 2>&1
}

resource_group_is_owned() {
  local subscription
  subscription=$(subscription_id)
  [[ "$(az group show --subscription "$subscription" --name "$LAB_RESOURCE_GROUP" \
    --query "tags.\"$LAB_OWNER_TAG\"" -o tsv 2>/dev/null || true)" == "$LAB_OWNER_VALUE" ]]
}

require_lab_context() {
  local context server server_host subscription cluster_json fqdn private_fqdn
  require_command az "Install the Azure CLI."
  context=$(kubectl config current-context 2>/dev/null || true)
  [[ "$context" == "$LAB_CLUSTER" ]] || fail \
    "kubectl context is '$context', expected '$LAB_CLUSTER'. Run scripts/10-create-cluster.sh."

  subscription=$(subscription_id)
  cluster_json=$(az aks show --subscription "$subscription" \
    --resource-group "$LAB_RESOURCE_GROUP" --name "$LAB_CLUSTER" -o json 2>/dev/null) || \
    fail "could not read AKS cluster $LAB_RESOURCE_GROUP/$LAB_CLUSTER"
  fqdn=$(jq -r '.fqdn // ""' <<<"$cluster_json" | tr '[:upper:]' '[:lower:]')
  private_fqdn=$(jq -r '.privateFqdn // ""' <<<"$cluster_json" | tr '[:upper:]' '[:lower:]')
  server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  server_host=${server#https://}
  server_host=${server_host%%:*}
  server_host=$(printf '%s' "$server_host" | tr '[:upper:]' '[:lower:]')
  [[ -n "$server_host" && ( "$server_host" == "$fqdn" || "$server_host" == "$private_fqdn" ) ]] || \
    fail "context '$context' points to '$server_host', not the configured AKS cluster endpoint"
}

ensure_lab_namespace() {
  if kubectl get namespace "$LAB_NAMESPACE" >/dev/null 2>&1; then
    [[ "$(kubectl get namespace "$LAB_NAMESPACE" -o json | \
      jq -r --arg key "$LAB_OWNER_TAG" '.metadata.labels[$key] // ""')" == "$LAB_OWNER_VALUE" ]] || \
      fail "namespace $LAB_NAMESPACE exists but isn't owned by this codelab"
  else
    kubectl create namespace "$LAB_NAMESPACE" >/dev/null
  fi
  kubectl label namespace "$LAB_NAMESPACE" \
    "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" --overwrite >/dev/null
}

wait_for_job() {
  local job=$1 timeout=${2:-1800} elapsed=0
  while (( elapsed < timeout )); do
    local complete failed
    complete=$(kubectl -n "$LAB_NAMESPACE" get job "$job" \
      -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)
    failed=$(kubectl -n "$LAB_NAMESPACE" get job "$job" \
      -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)
    [[ "$complete" == "True" ]] && return 0
    if [[ "$failed" == "True" ]]; then
      kubectl -n "$LAB_NAMESPACE" logs "job/$job" --all-containers=true 2>/dev/null || true
      fail "job/$job failed"
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  kubectl -n "$LAB_NAMESPACE" describe job "$job" 2>/dev/null || true
  kubectl -n "$LAB_NAMESPACE" get pods -l "job-name=$job" -o wide 2>/dev/null || true
  fail "timed out after ${timeout}s waiting for job/$job"
}

render_template() {
  local input=$1 output=$2
  shift 2
  python3 - "$input" "$output" "$@" <<'PY'
from pathlib import Path
import sys
source, destination, *pairs = sys.argv[1:]
text = Path(source).read_text()
for pair in pairs:
    key, value = pair.split("=", 1)
    token = f"__{key}__"
    if token not in text:
        raise SystemExit(f"template token {token} is missing from {source}")
    text = text.replace(token, value)
leftovers = sorted(set(part.split("__", 1)[0] for part in text.split("__")[1::2]))
if "__" in text:
    raise SystemExit(f"unresolved template token(s) in {source}: {leftovers}")
Path(destination).write_text(text)
PY
}

matching_gpu_nodes_json() {
  local sku
  sku=$(printf '%s' "$LAB_GPU_SKU" | tr '[:upper:]' '[:lower:]')
  kubectl get nodes -l "$LAB_NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_VALUE" -o json | \
    jq --arg sku "$sku" \
      '{items: [.items[] | select(((.metadata.labels["node.kubernetes.io/instance-type"] // "") | ascii_downcase) == $sku)]}'
}
