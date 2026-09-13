#!/usr/bin/env bash
# Create the AKS cluster with a CPU-only system node pool.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Creating resource group"
if az group show --name "$LAB_RESOURCE_GROUP" >/dev/null 2>&1; then
  pass "$LAB_RESOURCE_GROUP already exists"
else
  az group create --name "$LAB_RESOURCE_GROUP" --location "$LAB_LOCATION" -o none
  pass "Created $LAB_RESOURCE_GROUP"
fi

step "Creating AKS cluster"
if cluster_exists; then
  pass "$LAB_CLUSTER already exists"
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
