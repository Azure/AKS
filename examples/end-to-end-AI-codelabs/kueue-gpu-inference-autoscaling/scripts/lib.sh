#!/usr/bin/env bash
# Shared configuration and output helpers.
# shellcheck disable=SC2034

set -euo pipefail

: "${LAB_LOCATION:=eastasia}"
: "${LAB_RESOURCE_GROUP:=aks-kueue-inference-lab}"
: "${LAB_CLUSTER:=aks-kueue-inference}"
: "${LAB_KUBERNETES_VERSION:=1.35}"
: "${LAB_SYSTEM_SKU:=Standard_D4s_v5}"
: "${LAB_GPU_SKU:=Standard_NV6ads_A10_v5}"
: "${LAB_GPU_POOL:=gpupool}"
: "${LAB_GPU_MAX_COUNT:=3}"
: "${LAB_GPU_TAINT:=sku=gpu:NoSchedule}"
: "${KUEUE_VERSION:=0.17.1}"
: "${NVIDIA_DEVICE_PLUGIN_VERSION:=0.17.0}"
: "${LAB_NAMESPACE:=gpu-inference}"
: "${LAB_JOB:=vllm-inference-check}"

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

cluster_exists() {
  az aks show --resource-group "$LAB_RESOURCE_GROUP" --name "$LAB_CLUSTER" \
    >/dev/null 2>&1
}
