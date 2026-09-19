#!/usr/bin/env bash
# Install GPU/RDMA resource plugins and load nvidia-peermem for GPUDirect RDMA.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_command helm "Install Helm."
require_command kubectl "Run: az aks install-cli"
require_command jq "Install jq."
require_command python3 "Install Python 3."
require_lab_context

if [[ "$LAB_REUSE_RDMA_STACK" == "true" ]]; then
  step "Checking the existing RDMA stack"
  result=$(matching_gpu_nodes_json | jq -r --arg rdma "$LAB_RDMA_RESOURCE" '
    [.items[] | {
      name: .metadata.name,
      gpu: (.status.allocatable["nvidia.com/gpu"] // "0" | tonumber),
      rdma: (.status.allocatable[$rdma] // "0" | tonumber)
    }]')
  printf '%s\n' "$result"
  good=$(jq '[.[] | select(.gpu > 0 and .rdma > 0)] | length' <<<"$result")
  (( good >= 2 )) || fail "two matching nodes must advertise nvidia.com/gpu and $LAB_RDMA_RESOURCE"
  pass "Reusing the existing device plugins on $good nodes"
  exit 0
fi

[[ "$LAB_RDMA_RESOURCE" == "rdma/shared_ib" ]] || fail \
  "a fresh install exposes rdma/shared_ib; LAB_RDMA_RESOURCE is $LAB_RDMA_RESOURCE"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if kubectl get nicclusterpolicy nic-cluster-policy >/dev/null 2>&1; then
  owner=$(kubectl get nicclusterpolicy nic-cluster-policy -o json | \
    jq -r --arg key "$LAB_OWNER_TAG" '.metadata.labels[$key] // ""')
  [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail \
    "nic-cluster-policy already exists and isn't owned by this codelab"
fi

step "Installing NVIDIA Network Operator"
if kubectl get namespace network-operator >/dev/null 2>&1; then
  owner=$(kubectl get namespace network-operator -o json | \
    jq -r --arg key "$LAB_OWNER_TAG" '.metadata.labels[$key] // ""')
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

for _ in $(seq 1 60); do
  if kubectl get crd nicclusterpolicies.mellanox.com >/dev/null 2>&1 && \
     kubectl get crd nodefeaturerules.nfd.k8s-sigs.io >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
kubectl get crd nicclusterpolicies.mellanox.com >/dev/null 2>&1 || fail \
  "Network Operator CRDs did not become available"

step "Installing Mellanox OFED and the RDMA shared device plugin"
if kubectl get nodefeaturerule rdma-training-mellanox >/dev/null 2>&1; then
  owner=$(kubectl get nodefeaturerule rdma-training-mellanox -o json | \
    jq -r --arg key "$LAB_OWNER_TAG" '.metadata.labels[$key] // ""')
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

step "Loading nvidia-peermem"
if kubectl get namespace gpu-resources >/dev/null 2>&1; then
  owner=$(kubectl get namespace gpu-resources -o json | \
    jq -r --arg key "$LAB_OWNER_TAG" '.metadata.labels[$key] // ""')
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

step "Verifying allocatable devices"
for _ in $(seq 1 90); do
  nodes=$(matching_gpu_nodes_json)
  good=$(jq --arg rdma "$LAB_RDMA_RESOURCE" '[.items[] | select(
    any(.status.conditions[]; .type=="Ready" and .status=="True") and
    ((.status.allocatable["nvidia.com/gpu"] // "0" | tonumber) > 0) and
    ((.status.allocatable[$rdma] // "0" | tonumber) > 0))] | length' <<<"$nodes")
  printf 'Nodes with GPU + RDMA resources: %s/%s\n' "$good" "$LAB_GPU_NODE_COUNT"
  (( good >= LAB_GPU_NODE_COUNT )) && break
  sleep 10
done
(( good >= LAB_GPU_NODE_COUNT )) || fail \
  "fewer than $LAB_GPU_NODE_COUNT nodes advertise nvidia.com/gpu and $LAB_RDMA_RESOURCE"
matching_gpu_nodes_json | jq -r --arg rdma "$LAB_RDMA_RESOURCE" \
  '.items[] | [.metadata.name, .status.allocatable["nvidia.com/gpu"], .status.allocatable[$rdma]] | @tsv'
pass "GPUs, InfiniBand devices, and nvidia-peermem are ready. Continue with modules/04-validate-infiniband.md."
