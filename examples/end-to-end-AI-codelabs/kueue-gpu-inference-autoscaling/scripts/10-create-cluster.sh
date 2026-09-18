#!/usr/bin/env bash
# Create the AKS cluster with a CPU-only system node pool.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Creating resource group"
if az group show --name "$LAB_RESOURCE_GROUP" >/dev/null 2>&1; then
  resource_group_is_owned || fail "$LAB_RESOURCE_GROUP already exists without the $LAB_OWNER_TAG=$LAB_OWNER_VALUE ownership tag. Choose another LAB_RESOURCE_GROUP."
  pass "$LAB_RESOURCE_GROUP already exists and is owned by this codelab"
else
  az group create --name "$LAB_RESOURCE_GROUP" --location "$LAB_LOCATION" \
    --tags "$LAB_OWNER_TAG=$LAB_OWNER_VALUE" -o none
  pass "Created and tagged $LAB_RESOURCE_GROUP"
fi

step "Creating AKS cluster"
if cluster_exists; then
  CURRENT_LOCATION=$(az aks show --resource-group "$LAB_RESOURCE_GROUP" --name "$LAB_CLUSTER" --query location -o tsv)
  [[ "$CURRENT_LOCATION" == "$LAB_LOCATION" ]] || fail "$LAB_CLUSTER is in $CURRENT_LOCATION, expected $LAB_LOCATION."
  pass "$LAB_CLUSTER already exists in the codelab-owned resource group"
else
  az aks create \
    --resource-group "$LAB_RESOURCE_GROUP" \
    --name "$LAB_CLUSTER" \
    --location "$LAB_LOCATION" \
    --kubernetes-version "$LAB_KUBERNETES_VERSION" \
    --nodepool-name system \
    --node-count 2 \
    --node-vm-size "$LAB_SYSTEM_SKU" \
    --enable-managed-identity \
    --generate-ssh-keys \
    -o none
  pass "Created $LAB_CLUSTER"
fi

az aks get-credentials \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --name "$LAB_CLUSTER" \
  --overwrite-existing \
  -o none

SERVER_VERSION=$(kubectl version -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["serverVersion"]["gitVersion"])')
pass "Connected to $LAB_CLUSTER ($SERVER_VERSION)"
