#!/bin/bash
set -euo pipefail

echo "=== AKS Cost Analysis Export Setup ==="

# Check prerequisites
for cmd in kubectl az docker; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
done

# Get Docker image name
if [ -z "${DOCKER_IMAGE:-}" ]; then
    echo -n "Enter your Docker image (e.g., your-registry/aks-cost-analysis:latest): "
    read -r DOCKER_IMAGE
fi

echo "Using Docker image: $DOCKER_IMAGE"

# Get cluster info
if [ -z "${SUBSCRIPTION_ID:-}" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

if [ -z "${RESOURCE_GROUP:-}" ]; then
    echo -n "Enter resource group name: "
    read -r RESOURCE_GROUP
fi

echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"

# Get storage account info
if [ -z "${STORAGE_ACCOUNT:-}" ]; then
    echo -n "Enter storage account name: "
    read -r STORAGE_ACCOUNT
fi

if [ -z "${CONTAINER_NAME:-}" ]; then
    CONTAINER_NAME="cost-exports"
fi

echo "Using storage account: $STORAGE_ACCOUNT"
echo "Using container: $CONTAINER_NAME"

# Create managed identity for workload identity
IDENTITY_NAME="cost-analysis-identity"
echo "Creating managed identity: $IDENTITY_NAME"
az identity create \
    --name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP

# Get identity details
CLIENT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query clientId -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "Client ID: $CLIENT_ID"
echo "Tenant ID: $TENANT_ID"

# Create Cost Management export at subscription level (can be reused for multiple AKS clusters)
EXPORT_NAME="aks-cost-export-subscription"
STORAGE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"

cat > export.json << EOF
{
  "properties": {
    "displayName": "$EXPORT_NAME",
    "definition": {
      "type": "Usage",
      "timeframe": "MonthToDate",
      "dataSet": {
        "granularity": "Daily"
      }
    },
    "deliveryInfo": {
      "destination": {
        "resourceId": "$STORAGE_ID",
        "container": "$CONTAINER_NAME",
        "rootFolderPath": "cost-management"
      }
    },
    "schedule": {
      "status": "Active",
      "recurrence": "Daily",
      "recurrencePeriod": {
        "from": "$(date -u +%Y-%m-%d)T00:00:00.000Z",
        "to": "2030-12-31T00:00:00.000Z"
      }
    },
    "format": "Csv",
    "compressionMode": "gzip",
    "dataOverwriteBehavior": "OverwritePreviousReport"
  }
}
EOF

az rest --method PUT \
    --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.CostManagement/exports/$EXPORT_NAME?api-version=2023-07-01-preview" \
    --body @export.json

rm export.json

# Assign Storage Blob Data Contributor role to managed identity
STORAGE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
az role assignment create \
    --assignee $CLIENT_ID \
    --role "Storage Blob Data Contributor" \
    --scope $STORAGE_ID

# Get OIDC issuer URL from AKS cluster
if [ -z "${CLUSTER_NAME:-}" ]; then
    echo -n "Enter AKS cluster name: "
    read -r CLUSTER_NAME
fi
OIDC_ISSUER=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "oidcIssuerProfile.issuerUrl" -o tsv)

echo "OIDC Issuer: $OIDC_ISSUER"

# Create federated identity credential
az identity federated-credential create \
    --name "cost-analysis-federated-credential" \
    --identity-name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --issuer $OIDC_ISSUER \
    --subject "system:serviceaccount:cost-analysis:cost-analysis-sa" \
    --audience "api://AzureADTokenExchange"

# Create namespace
kubectl create namespace cost-analysis --dry-run=client -o yaml | kubectl apply -f -

# Update kube.yaml with the Docker image, identity details, and cluster-specific storage path
CLUSTER_STORAGE_PREFIX="cost-analysis/$CLUSTER_NAME/"
sed "s|image: .*|image: $DOCKER_IMAGE|; s|PLACEHOLDER_CLIENT_ID|$CLIENT_ID|g; s|PLACEHOLDER_STORAGE_ACCOUNT|$STORAGE_ACCOUNT|g; s|PLACEHOLDER_TENANT_ID|$TENANT_ID|g; s|cost-analysis/|$CLUSTER_STORAGE_PREFIX|g" kube.yaml > kube-deploy.yaml

# Deploy the cronjob
kubectl apply -f kube-deploy.yaml

# Cleanup
rm kube-deploy.yaml

echo "✅ Setup complete!"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Docker Image: $DOCKER_IMAGE"
echo "Managed Identity: $IDENTITY_NAME"
echo "Client ID: $CLIENT_ID"
echo "Cost Management Export: $EXPORT_NAME (subscription-level)"
echo "Cost exports will run daily and be processed by the cronjob"