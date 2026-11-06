#!/usr/bin/env bash
# Create an AKS cluster and a two-node RDMA GPU pool in one VMSS placement group.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_command az "Install the Azure CLI."
require_command kubectl "Run: az aks install-cli"
require_command jq "Install jq."
require_command python3 "Install Python 3."
SUBSCRIPTION_ID=$(subscription_id)
[[ -n "$SUBSCRIPTION_ID" ]] || fail "Select an Azure subscription first."

if [[ "$LAB_REUSE_CLUSTER" == "true" ]]; then
  step "Selecting existing cluster $LAB_CLUSTER"
  cluster_exists || fail "$LAB_CLUSTER wasn't found in $LAB_RESOURCE_GROUP"
  RG_ID=$(az group show --subscription "$SUBSCRIPTION_ID" --name "$LAB_RESOURCE_GROUP" \
    --query id -o tsv)
  az tag update --subscription "$SUBSCRIPTION_ID" --resource-id "$RG_ID" \
    --operation Merge --tags "$LAB_REUSE_PROTECTION_TAG=true" >/dev/null
  az aks get-credentials --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" --overwrite-existing >/dev/null
  require_lab_context
  nodes=$(matching_gpu_nodes_json)
  count=$(jq '.items | length' <<<"$nodes")
  ready=$(jq '[.items[] | select(any(.status.conditions[]; .type=="Ready" and .status=="True"))] | length' <<<"$nodes")
  pools=$(jq -r '[.items[].metadata.labels.agentpool // ""] | unique | join(",")' <<<"$nodes")
  [[ "$count" == "$LAB_GPU_NODE_COUNT" && "$ready" == "$LAB_GPU_NODE_COUNT" ]] || fail \
    "$LAB_CLUSTER must have exactly $LAB_GPU_NODE_COUNT Ready, labeled $LAB_GPU_SKU nodes"
  [[ "$pools" == "$LAB_GPU_POOL" ]] || fail \
    "reuse nodes belong to agent pool(s) '$pools', expected only '$LAB_GPU_POOL'"
  NODE_RG=$(az aks show --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" --query nodeResourceGroup -o tsv)
  VMSS_ID=$(az vmss list --subscription "$SUBSCRIPTION_ID" --resource-group "$NODE_RG" \
    --query "[?tags.\"aks-managed-poolName\"=='$LAB_GPU_POOL'].id | [0]" -o tsv)
  [[ -n "$VMSS_ID" ]] || fail "could not find the VMSS for reuse pool $LAB_GPU_POOL"
  VMSS_NAME=${VMSS_ID##*/}
  SINGLE_PLACEMENT=$(az vmss show --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$NODE_RG" --name "$VMSS_NAME" --query singlePlacementGroup -o tsv)
  [[ "$SINGLE_PLACEMENT" == "true" ]] || fail \
    "reuse pool $LAB_GPU_POOL must use singlePlacementGroup=true"
  pass "Reusing $LAB_CLUSTER with two Ready nodes in one single-placement-group pool"
  exit 0
fi

step "Registering AKS InfiniBand placement support"
state=$(az feature show --subscription "$SUBSCRIPTION_ID" --namespace Microsoft.ContainerService \
  --name AKSInfinibandSupport --query properties.state -o tsv 2>/dev/null || true)
if [[ "$state" != "Registered" ]]; then
  az feature register --subscription "$SUBSCRIPTION_ID" \
    --namespace Microsoft.ContainerService --name AKSInfinibandSupport >/dev/null
  for _ in $(seq 1 120); do
    state=$(az feature show --subscription "$SUBSCRIPTION_ID" \
      --namespace Microsoft.ContainerService --name AKSInfinibandSupport \
      --query properties.state -o tsv 2>/dev/null || true)
    printf 'AKSInfinibandSupport: %s\n' "$state"
    [[ "$state" == "Registered" ]] && break
    sleep 15
  done
  [[ "$state" == "Registered" ]] || fail "AKSInfinibandSupport did not register within 30 minutes"
  az provider register --subscription "$SUBSCRIPTION_ID" \
    --namespace Microsoft.ContainerService --wait >/dev/null
fi
pass "AKSInfinibandSupport is registered"

step "Creating resource group"
if ! RG_EXISTS=$(az group exists --subscription "$SUBSCRIPTION_ID" \
  --name "$LAB_RESOURCE_GROUP" -o tsv); then
  fail "could not check whether $LAB_RESOURCE_GROUP exists"
fi
case "$RG_EXISTS" in
  true)
    resource_group_is_owned || fail \
      "$LAB_RESOURCE_GROUP already exists without $LAB_OWNER_TAG=$LAB_OWNER_VALUE"
    pass "Reusing owned resource group $LAB_RESOURCE_GROUP"
    ;;
  false)
    az group create --subscription "$SUBSCRIPTION_ID" --name "$LAB_RESOURCE_GROUP" \
      --location "$LAB_LOCATION" --tags "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" >/dev/null
    pass "Created $LAB_RESOURCE_GROUP"
    ;;
  *) fail "unexpected response from 'az group exists': $RG_EXISTS" ;;
esac

KUBERNETES_VERSION=$(resolve_kubernetes_version "$SUBSCRIPTION_ID") || fail \
  "AKS Kubernetes $LAB_KUBERNETES_VERSION is not offered in $LAB_LOCATION"

step "Creating AKS control plane and system pool"
if cluster_exists; then
  cluster=$(az aks show --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$LAB_RESOURCE_GROUP" --name "$LAB_CLUSTER" -o json)
  actual_location=$(jq -r '.location | ascii_downcase' <<<"$cluster")
  expected_location=$(printf '%s' "$LAB_LOCATION" | tr '[:upper:]' '[:lower:]')
  actual_version=$(jq -r '.kubernetesVersion' <<<"$cluster")
  [[ "$actual_location" == "$expected_location" ]] || fail \
    "$LAB_CLUSTER is in $actual_location, expected $expected_location"
  [[ "$actual_version" == "$LAB_KUBERNETES_VERSION" || \
     "$actual_version" == "$LAB_KUBERNETES_VERSION".* ]] || fail \
    "$LAB_CLUSTER runs Kubernetes $actual_version, expected $LAB_KUBERNETES_VERSION.x"
  [[ "$(jq -r '.networkProfile.networkPlugin' <<<"$cluster")" == "azure" && \
     "$(jq -r '.networkProfile.networkPluginMode' <<<"$cluster")" == "overlay" && \
     "$(jq -r '.networkProfile.podCidr' <<<"$cluster")" == "10.244.0.0/16" && \
     "$(jq -r '.networkProfile.serviceCidr' <<<"$cluster")" == "10.0.0.0/16" ]] || fail \
    "$LAB_CLUSTER does not have the codelab's non-overlapping Azure CNI Overlay network profile"
  pass "Reusing compatible cluster $LAB_CLUSTER"
else
  az aks create --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" \
    --location "$LAB_LOCATION" \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --node-count "$LAB_SYSTEM_NODE_COUNT" \
    --node-vm-size "$LAB_SYSTEM_SKU" \
    --os-sku Ubuntu \
    --enable-managed-identity \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 10.244.0.0/16 \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --generate-ssh-keys \
    --tags "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" >/dev/null
  pass "Created $LAB_CLUSTER"
fi

az aks get-credentials --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
  --name "$LAB_CLUSTER" --overwrite-existing >/dev/null
require_lab_context

step "Creating two-node RDMA GPU pool"
if az aks nodepool show --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" --name "$LAB_GPU_POOL" >/dev/null 2>&1; then
  pool=$(az aks nodepool show --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
    --cluster-name "$LAB_CLUSTER" --name "$LAB_GPU_POOL" -o json)
  actual_sku=$(jq -r '.vmSize' <<<"$pool")
  actual_count=$(jq -r '.count' <<<"$pool")
  actual_state=$(jq -r '.provisioningState' <<<"$pool")
  actual_mode=$(jq -r '.mode' <<<"$pool")
  actual_driver=$(jq -r '.gpuProfile.driver // ""' <<<"$pool")
  actual_taint=$(jq -r --arg taint "$LAB_GPU_TAINT" \
    '(.nodeTaints // []) | index($taint) != null' <<<"$pool")
  [[ "$actual_sku" == "$LAB_GPU_SKU" ]] || fail \
    "$LAB_GPU_POOL uses $actual_sku, expected $LAB_GPU_SKU"
  [[ "$actual_count" == "$LAB_GPU_NODE_COUNT" ]] || fail \
    "$LAB_GPU_POOL has $actual_count nodes, expected $LAB_GPU_NODE_COUNT"
  [[ "$actual_state" == "Succeeded" ]] || fail \
    "$LAB_GPU_POOL provisioning state is $actual_state"
  [[ "$actual_mode" == "User" && "$actual_taint" == "true" && \
     "$actual_driver" == "Install" ]] || fail \
    "$LAB_GPU_POOL must be a User pool with the AKS GPU driver and taint $LAB_GPU_TAINT"
  pass "Reusing compatible pool $LAB_GPU_POOL"
else
  az aks nodepool add --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --cluster-name "$LAB_CLUSTER" \
    --name "$LAB_GPU_POOL" \
    --node-count "$LAB_GPU_NODE_COUNT" \
    --node-vm-size "$LAB_GPU_SKU" \
    --os-sku Ubuntu \
    --mode User \
    --gpu-driver install \
    --node-taints "$LAB_GPU_TAINT" \
    --labels "$LAB_NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_VALUE" \
    --max-pods 110 \
    --no-wait

  for _ in $(seq 1 180); do
    pool=$(az aks nodepool show --subscription "$SUBSCRIPTION_ID" \
      --resource-group "$LAB_RESOURCE_GROUP" --cluster-name "$LAB_CLUSTER" \
      --name "$LAB_GPU_POOL" -o json 2>/dev/null || echo '{}')
    state=$(jq -r '.provisioningState // "Submitting"' <<<"$pool")
    ready=$(kubectl get nodes -l "agentpool=$LAB_GPU_POOL" --no-headers 2>/dev/null | \
      awk '$2 == "Ready" {count++} END {print count+0}')
    printf 'Pool state=%s, Ready nodes=%s/%s\n' "$state" "$ready" "$LAB_GPU_NODE_COUNT"
    if [[ "$state" == "Succeeded" && "$ready" == "$LAB_GPU_NODE_COUNT" ]]; then
      break
    fi
    if [[ "$state" == "Failed" ]]; then
      message=$(jq -r '.status.errordetail.message // "unknown provisioning error"' <<<"$pool")
      fail "$message"
    fi
    sleep 15
  done
  [[ "$state" == "Succeeded" && "$ready" == "$LAB_GPU_NODE_COUNT" ]] || \
    fail "RDMA pool did not become Ready within 45 minutes"
fi

ready=$(kubectl get nodes -l "agentpool=$LAB_GPU_POOL" --no-headers 2>/dev/null | \
  awk '$2 == "Ready" {count++} END {print count+0}')
[[ "$ready" == "$LAB_GPU_NODE_COUNT" ]] || fail \
  "$LAB_GPU_POOL has $ready Ready nodes, expected $LAB_GPU_NODE_COUNT"
labeled_ready=$(kubectl get nodes \
  -l "agentpool=$LAB_GPU_POOL,$LAB_NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_VALUE" \
  --no-headers 2>/dev/null | awk '$2 == "Ready" {count++} END {print count+0}')
[[ "$labeled_ready" == "$LAB_GPU_NODE_COUNT" ]] || fail \
  "$LAB_GPU_POOL does not carry $LAB_NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_VALUE on every Ready node"

step "Verifying the InfiniBand placement boundary"
NODE_RG=$(az aks show --subscription "$SUBSCRIPTION_ID" --resource-group "$LAB_RESOURCE_GROUP" \
  --name "$LAB_CLUSTER" --query nodeResourceGroup -o tsv)
VMSS_ID=$(az vmss list --subscription "$SUBSCRIPTION_ID" --resource-group "$NODE_RG" \
  --query "[?tags.\"aks-managed-poolName\"=='$LAB_GPU_POOL'].id | [0]" -o tsv)
[[ -n "$VMSS_ID" ]] || fail "could not find the VMSS for pool $LAB_GPU_POOL"
VMSS_NAME=${VMSS_ID##*/}
SINGLE_PLACEMENT=$(az vmss show --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$NODE_RG" --name "$VMSS_NAME" --query singlePlacementGroup -o tsv)
[[ "$SINGLE_PLACEMENT" == "true" ]] || fail \
  "the RDMA pool VMSS must use singlePlacementGroup=true; got $SINGLE_PLACEMENT"
pass "Both RDMA nodes are in one single-placement-group VMSS"

step "Checkpoint"
kubectl get nodes -l "agentpool=$LAB_GPU_POOL" \
  -o custom-columns='NAME:.metadata.name,SKU:.metadata.labels.node\.kubernetes\.io/instance-type,READY:.status.conditions[?(@.type=="Ready")].status'
pass "Cluster provisioning is complete. Continue with modules/03-enable-rdma.md."
