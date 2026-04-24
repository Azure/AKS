# Self-managed AKS Cost Export 


This guide walks through how to configure a CSV cost export for your AKS cluster. The example implementation is completely *self-managed and self-supported*. It is for those that want to work with AKS Cost Analysis data beyond the Azure Portal Cost Management UI. 

Once configured, a daily-updated `results.csv` file will be generated and stored in Azure Blob storage. The CSV file shows your cluster costs broken down by:
- Traditional Azure Cost Management constructs (resource group, region, meter details, tags, etc.)
- Kubernetes constructs (namespace, deployment, labels (app and team), service etc.)

You can configure a single CSV file per cluster or have multiple clusters conslidated into a single file.

## Quickstart

### Prerequisites

- Azure CLI (`az`)
- kubectl configured for your AKS cluster
- Docker
- Access to a container registry
- AKS cluster with OIDC issuer and workload identity enabled
- Satisfy prerequisites for [AKS Cost Analysis add-on](https://learn.microsoft.com/azure/aks/cost-analysis#prerequisites)

### 1. Build and Push Docker Image

```bash
DOCKER_IMAGE=your-registry/aks-cost-export:latest ./build.sh
```

For Azure Container Registry, authenticate first:
```bash
az acr login --name your-registry-name
```

This will:
- Build the Docker image
- Push it to your container registry
- Provide the deployment command

### 2. Enable Workload Identity on AKS (if not already enabled)

```bash
az aks update --name your-cluster-name --resource-group your-resource-group --enable-oidc-issuer --enable-workload-identity
```

### 3. Deploy to AKS

Set required environment variables and deploy:

```bash
RESOURCE_GROUP=your-resource-group \
STORAGE_ACCOUNT=your-storage-account \
CLUSTER_NAME=your-cluster-name \
DOCKER_IMAGE=your-registry/aks-cost-export:latest \
./deploy.sh
```

This will:
- Create managed identity with Storage Blob Data Contributor role
- Configure Cost Management export at subscription level (can be reused for multiple AKS clusters)
- Set up federated identity credential for workload identity
- Create Kubernetes namespace and service account
- Deploy daily cronjob (runs at 00:10 UTC)

## How it Works

The tool operates in two phases:

1. **Export**: Fetches daily usage data from AKS Cost Analysis agent and uploads to blob storage as CSV
2. **Merge**: Downloads AKS data and Cost Management data, joins them in SQLite, and uploads merged result to a result.csv file

### Data Flow

- **AKS Data**: Daily exports from cost analysis agent → `cost-analysis/` prefix
- **Cost Management Data**: Azure subscription-level exports → `cost-management/` prefix
- **Result**: Merged data → `cost-analysis/result.csv`

### Scalability

- **Single Cost Management Export**: One subscription-level export serves multiple AKS clusters
- **Filtered by Resource ID**: The merge process automatically matches costs to specific AKS resources
- **Shared Storage**: Multiple clusters can use the same storage account and container

## Configuration

Environment variables (configured via deployment):

- `AZURE_STORAGE_ACCOUNT_NAME`: Storage account name
- `AZURE_STORAGE_CONTAINER_NAME`: Container name (default: `cost-exports`)
- `COST_ANALYSIS_URL`: Agent endpoint (default: `http://cost-analysis-agent-svc.kube-system:9094`)
- `AZURE_STORAGE_AKS_DATA_PREFIX`: Storage path for AKS exports (default: `cost-analysis/`)
- `AZURE_STORAGE_COST_EXPORT_PREFIX`: Storage path for Cost Management exports (default: `cost-management/`)
- `AZURE_STORAGE_RESULT_FILE`: Path for merged result file (default: `cost-analysis/result.csv`)

**Multi-Cluster Configuration**: To avoid data overwrites between clusters, configure cluster-specific AKS data paths while keeping the result file shared:

```yaml
env:
- name: AZURE_STORAGE_AKS_DATA_PREFIX
  value: "cost-analysis/cluster-prod/"
# AZURE_STORAGE_RESULT_FILE remains "cost-analysis/result.csv" (shared)
```

**Security**: Uses Microsoft Entra Workload Identity instead of connection strings for secure authentication to Azure Storage.

## Monitoring

Check deployment status:

```bash
kubectl get cronjobs -n cost-analysis
kubectl get jobs -n cost-analysis
kubectl logs -n cost-analysis -l job-name=aks-cost-analysis-export
```

## Manual Operations

### Local Development

```bash
go build -o aks-ca-export .
AZURE_STORAGE_ACCOUNT_NAME="your-storage-account" ./aks-ca-export
```

Note: For local development, you'll need to authenticate to Azure using `az login` since the application uses DefaultAzureCredential.

### Testing

```bash
go test ./...
```

## Operation Modes

The application supports three operation modes via command line arguments:

### Combined Mode (Default)
```bash
./aks-ca-export both
```
Runs both export and merge phases in sequence.

### Export-Only Mode
```bash
./aks-ca-export export
```
Only exports cost data from AKS Cost Analysis agent to storage.

### Merge-Only Mode
```bash
./aks-ca-export merge
```
Only processes existing data files (imports, merges, and uploads results).

## Deployment Patterns

### Single CronJob (Default)
Uses `both` operation mode - suitable for single cluster or when clusters don't need to share data.

### Separated Export/Merge Jobs
- **Export jobs**: Run on each cluster with `export` operation and cluster-specific `AZURE_STORAGE_AKS_DATA_PREFIX`
- **Merge job**: Run on one cluster or external system with `merge` operation to process all clusters' data
- **Benefits**: Better resource utilization, centralized processing, shared result file with multi-cluster data

Example separated deployment:
```yaml
# Export CronJob (runs on each cluster with cluster-specific paths)
# Cluster A:
env:
- name: AZURE_STORAGE_AKS_DATA_PREFIX
  value: "cost-analysis/cluster-a/"
args: ["export"]
schedule: "10 0 * * *"

# Cluster B:  
env:
- name: AZURE_STORAGE_AKS_DATA_PREFIX
  value: "cost-analysis/cluster-b/"
args: ["export"]
schedule: "10 0 * * *"

# Merge CronJob (runs on one cluster only, reads all cluster data)
args: ["merge"]  
schedule: "30 0 * * *"
# Uses default paths to read from all cost-analysis/* and cost-management/*
```

## Support
The example implementation is completely *self-managed and self-hosted*. This export solution is not a managed AKS feature and no Azure support will be provided.