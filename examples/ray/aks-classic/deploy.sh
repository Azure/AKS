#!/bin/bash
set -euo pipefail

# Check if the user is logged into Azure CLI
if ! az account show > /dev/null 2>&1; then
    echo "Please sign in to Azure CLI using 'az login' before running this script."
    exit 1
fi

# Initialize Terraform
terraform init

# Create a Terraform plan
terraform plan -out main.tfplan

# Apply the Terraform plan
terraform apply main.tfplan

# Retrieve the Terraform outputs
resource_group_name=$(terraform output -raw resource_group_name)
aks_cluster_name=$(terraform output -raw kubernetes_cluster_name)

# Get AKS credentials for the cluster
az aks get-credentials \
    --resource-group "$resource_group_name" \
    --name "$aks_cluster_name" \
    --overwrite-existing

echo "=== Cluster nodes ==="
kubectl get nodes

echo "=== Verifying installations ==="
kubectl get pods -n kueue-system
kubectl get pods -n kuberay-system

echo "=== Setup complete ==="