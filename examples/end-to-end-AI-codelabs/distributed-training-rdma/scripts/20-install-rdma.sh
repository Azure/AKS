#!/usr/bin/env bash
# Install GPU/RDMA resource plugins and load nvidia-peermem for GPUDirect RDMA.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_command helm "Install Helm."
require_command kubectl "Run: az aks install-cli"
require_command jq "Install jq."
require_command python3 "Install Python 3."
require_lab_context

get_optional_resource_json() {
  local kind=$1 name=$2 result
  if ! result=$(kubectl get "$kind" "$name" --ignore-not-found -o json); then
    fail "could not inspect $kind/$name"
  fi
  printf '%s' "$result"
}

if [[ "$LAB_REUSE_RDMA_STACK" == "true" ]]; then
  step "Checking the existing RDMA stack"
  result=$(matching_gpu_nodes_json | jq -r --arg rdma "$LAB_RDMA_RESOURCE" '
    [.items[] | {
      name: .metadata.name,
      gpu: (.status.allocatable["nvidia.com/gpu"] // "0"),
      rdma: (.status.allocatable[$rdma] // "0")
    }]')
  printf '%s\n' "$result"
  good=$(jq '[.[] | select(.gpu != "0" and .gpu != "0m" and .rdma != "0" and .rdma != "0m")] | length' <<<"$result")
  (( good >= 2 )) || fail "two matching nodes must advertise nvidia.com/gpu and $LAB_RDMA_RESOURCE"
  pass "Reusing the existing device plugins on $good nodes"
  exit 0
fi

[[ "$LAB_RDMA_RESOURCE" == "rdma/shared_ib" ]] || fail \
  "a fresh install exposes rdma/shared_ib; LAB_RDMA_RESOURCE is $LAB_RDMA_RESOURCE"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

nic_crd=$(get_optional_resource_json crd nicclusterpolicies.mellanox.com)
if [[ -n "$nic_crd" ]]; then
  policy=$(get_optional_resource_json nicclusterpolicy nic-cluster-policy)
  if [[ -n "$policy" ]]; then
    owner=$(jq -r --arg key "$LAB_OWNER_TAG" '.metadata.labels[$key] // ""' <<<"$policy")
    [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail \
      "nic-cluster-policy already exists and isn't owned by this codelab"
  fi
fi

step "Installing NVIDIA Network Operator"
network_namespace=$(get_optional_resource_json namespace network-operator)
if [[ -n "$network_namespace" ]]; then
  owner=$(jq -r --arg key "$LAB_OWNER_TAG" \
    '.metadata.labels[$key] // ""' <<<"$network_namespace")
  [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail \
    "network-operator already exists and isn't owned by this codelab"
else
  kubectl create namespace network-operator >/dev/null
fi
kubectl label namespace network-operator "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" \
  pod-security.kubernetes.io/enforce=privileged --overwrite >/dev/null

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia --force-update >/dev/null
helm repo update nvidia >/dev/null
helm upgrade --install network-operator nvidia/network-operator \
  --namespace network-operator \
  --version "$NETWORK_OPERATOR_VERSION" \
  --values "$ROOT/manifests/network-operator-values.yaml" \
  --wait --timeout 10m

nic_crd=""
nfd_crd=""
for _ in $(seq 1 60); do
  nic_crd=$(get_optional_resource_json crd nicclusterpolicies.mellanox.com)
  nfd_crd=$(get_optional_resource_json crd nodefeaturerules.nfd.k8s-sigs.io)
  [[ -n "$nic_crd" && -n "$nfd_crd" ]] && break
  sleep 5
done
[[ -n "$nic_crd" && -n "$nfd_crd" ]] || fail \
  "Network Operator CRDs did not become available"

step "Installing Mellanox OFED and the RDMA shared device plugin"
feature_rule=$(get_optional_resource_json nodefeaturerule rdma-training-mellanox)
if [[ -n "$feature_rule" ]]; then
  owner=$(jq -r --arg key "$LAB_OWNER_TAG" \
    '.metadata.labels[$key] // ""' <<<"$feature_rule")
  [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail \
    "rdma-training-mellanox already exists and isn't owned by this codelab"
fi
kubectl apply -f "$ROOT/manifests/node-feature-rule.yaml"
render_template "$ROOT/manifests/nic-cluster-policy.yaml.tpl" "$TMP_DIR/nic-cluster-policy.yaml" \
  "NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_KEY" \
  "NODE_SELECTOR_VALUE=$LAB_NODE_SELECTOR_VALUE"
kubectl apply -f "$TMP_DIR/nic-cluster-policy.yaml"

policy_state=""
for _ in $(seq 1 180); do
  policy_state=$(kubectl get nicclusterpolicy nic-cluster-policy \
    -o jsonpath='{.status.state}' 2>/dev/null || true)
  printf 'NicClusterPolicy state: %s\n' "${policy_state:-Reconciling}"
  [[ "$policy_state" == "ready" ]] && break
  [[ "$policy_state" == "error" ]] && {
    kubectl get nicclusterpolicy nic-cluster-policy -o yaml
    fail "NicClusterPolicy reconciliation failed"
  }
  sleep 10
done
[[ "$policy_state" == "ready" ]] || fail "RDMA stack did not become ready within 30 minutes"

step "Installing the NVIDIA device plugin"
HELM_RELEASES=$(helm list --namespace kube-system -o json) || fail \
  "could not inspect existing Helm releases in kube-system"
if jq -e '.[] | select(.name=="rdma-lab-nvidia-device-plugin")' \
  >/dev/null <<<"$HELM_RELEASES"; then
  release_owner=$(helm get values rdma-lab-nvidia-device-plugin --namespace kube-system \
    -o json | jq -r '.podAnnotations["aks-codelab"] // ""')
  [[ "$release_owner" == "$LAB_OWNER_VALUE" ]] || fail \
    "Helm release kube-system/rdma-lab-nvidia-device-plugin isn't owned by this codelab"
fi
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin --force-update >/dev/null
helm repo update nvdp >/dev/null
render_template "$ROOT/manifests/nvidia-device-plugin-values.yaml.tpl" \
  "$TMP_DIR/nvidia-device-plugin-values.yaml" \
  "NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_KEY" \
  "NODE_SELECTOR_VALUE=$LAB_NODE_SELECTOR_VALUE"
helm upgrade --install rdma-lab-nvidia-device-plugin nvdp/nvidia-device-plugin \
  --namespace kube-system \
  --version "$NVIDIA_DEVICE_PLUGIN_VERSION" \
  --values "$TMP_DIR/nvidia-device-plugin-values.yaml" \
  --wait --timeout 10m

step "Preparing the GPUDirect peer-memory path"
gpu_namespace=$(get_optional_resource_json namespace gpu-resources)
if [[ -n "$gpu_namespace" ]]; then
  owner=$(jq -r --arg key "$LAB_OWNER_TAG" \
    '.metadata.labels[$key] // ""' <<<"$gpu_namespace")
  [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail \
    "gpu-resources already exists and isn't owned by this codelab"
else
  kubectl create namespace gpu-resources >/dev/null
fi
kubectl label namespace gpu-resources "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" \
  pod-security.kubernetes.io/enforce=privileged --overwrite >/dev/null
render_template "$ROOT/manifests/nvidia-peermem.yaml.tpl" "$TMP_DIR/nvidia-peermem.yaml" \
  "GPU_SKU=$LAB_GPU_SKU" \
  "NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_KEY" \
  "NODE_SELECTOR_VALUE=$LAB_NODE_SELECTOR_VALUE" \
  "PEERMEM_IMAGE=$PEERMEM_IMAGE"
kubectl apply -f "$TMP_DIR/nvidia-peermem.yaml"
kubectl -n gpu-resources rollout status daemonset/nvidia-peermem-loader --timeout=15m
loader_logs=$(kubectl -n gpu-resources logs -l app=nvidia-peermem-loader --tail=-1)
if grep -q GPUDIRECT_DMABUF_FALLBACK <<<"$loader_logs"; then
  warn "nvidia-peermem could not load; continuing with the DMA-BUF path. Module 5 must prove NET/IB/.../GDRDMA."
else
  pass "nvidia-peermem is loaded on the selected nodes"
fi

step "Verifying allocatable devices"
for _ in $(seq 1 90); do
  nodes=$(matching_gpu_nodes_json)
  good=$(jq --arg rdma "$LAB_RDMA_RESOURCE" '[.items[] | select(
    any(.status.conditions[]; .type=="Ready" and .status=="True") and
    ((.status.allocatable["nvidia.com/gpu"] // "0") as $gpu | $gpu != "0" and $gpu != "0m") and
    ((.status.allocatable[$rdma] // "0") as $rdmaQty | $rdmaQty != "0" and $rdmaQty != "0m"))] | length' <<<"$nodes")
  printf 'Nodes with GPU + RDMA resources: %s/%s\n' "$good" "$LAB_GPU_NODE_COUNT"
  (( good >= LAB_GPU_NODE_COUNT )) && break
  sleep 10
done
(( good >= LAB_GPU_NODE_COUNT )) || fail \
  "fewer than $LAB_GPU_NODE_COUNT nodes advertise nvidia.com/gpu and $LAB_RDMA_RESOURCE"
matching_gpu_nodes_json | jq -r --arg rdma "$LAB_RDMA_RESOURCE" \
  '.items[] | [.metadata.name, .status.allocatable["nvidia.com/gpu"], .status.allocatable[$rdma]] | @tsv'
pass "GPUs and InfiniBand devices are ready; Module 5 will prove the peer-memory or DMA-BUF GPUDirect path."
