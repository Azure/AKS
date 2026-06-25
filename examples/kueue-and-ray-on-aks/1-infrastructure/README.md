# Module 1 — Infrastructure

Terraform module that provisions everything you need before configuring Kueue
queues (Module 2) or submitting workloads (Module 3):

- AKS cluster with OIDC issuer and workload identity enabled
- KubeRay operator and Kueue controller (Helm releases from MCR)
- GPU monitoring (optional, when `gpu_enabled = true`)
- Azure Blob storage account with two containers (`aurora`, `llm-pipeline`)
- User-assigned managed identity with Storage Blob Data Contributor
- Federated identity credential bound to the `ray-workload` ServiceAccount
- Pre-staged datasets (Aurora WeatherBench2 init/truth pair + viggo NLG dataset)

One `terraform apply`, then `az aks get-credentials` — and you're ready for
Module 2.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | ≥ 2.70 | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.6 | [Install guide](https://developer.hashicorp.com/terraform/install) |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ≥ 1.28 | `az aks install-cli` |
| Python | ≥ 3.10 | Required for Aurora and viggo data generation/upload |

> **Windows users:** This module works natively on Windows — no WSL or Git Bash
> required. If your Python binary is `python` rather than `python3`, override with:
>
> ```
> terraform apply -var="subscription_id=<id>" -var="python_command=python"
> ```

### Python dependencies (Aurora data only)

The Aurora data upload step runs `populate_weatherbench2_regional_data.py`,
which needs several Python packages. Install them before `terraform apply` if
you're keeping `upload_aurora_inputs = true` (the default):

```bash
pip install -r terraform/requirements-generator.txt
```

### GPU quota

The default configuration provisions a `Standard_ND96amsr_A100_v4` node
(8×A100 80 GB GPUs). Verify you have quota before deploying:

**Linux / macOS:**

```bash
LOCATION=eastus2   # replace with your target region (must match the location variable in terraform apply)
az vm list-usage --location "$LOCATION" --output table \
  | grep -i "NDAMSv4_A100"
```

**Windows (PowerShell):**

```powershell
$LOCATION = "eastus2"   # replace with your target region
az vm list-usage --location $LOCATION --output table | Select-String "NDAMSv4_A100"
```

You need at least **96 vCPUs** in the `Standard NDAMSv4_A100Family` quota.
If you don't have GPU quota, set `gpu_enabled = false` to provision a
CPU-only cluster — you can still test queue configurations in Module 2.

### Azure login

```bash
az login
az account set --subscription <your-subscription-id>
```

If running from an Azure VM with managed identity:

```bash
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID=<your-subscription-id>
```

## Deploy

```bash
cd kueue-and-ray-on-aks/1-infrastructure/terraform

terraform init
terraform apply -var="subscription_id=<your-subscription-id>"
```

**Windows (PowerShell):**

```powershell
cd kueue-and-ray-on-aks\1-infrastructure\terraform

terraform init
terraform apply -var="subscription_id=<your-subscription-id>"
```

The default deployment takes approximately **10–15 minutes** (cluster creation
\+ node pool + Helm releases + data uploads).

### Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `subscription_id` | *(required)* | Azure subscription ID |
| `resource_group_name` | `rg-kueue-and-ray-on-aks` | Resource group name |
| `cluster_name` | `kueue-and-ray-on-aks` | AKS cluster name |
| `location` | `eastus2` | Azure region |
| `kubernetes_version` | `1.35` | Kubernetes version |
| `gpu_enabled` | `true` | Set `false` for CPU-only cluster (no GPU quota needed) |
| `gpu_vm_size` | `Standard_ND96amsr_A100_v4` | GPU VM SKU (8×A100 80 GB) |
| `upload_aurora_inputs` | `true` | Generate + upload WeatherBench2 data for Example 1 |
| `upload_viggo_dataset` | `true` | Download + upload viggo NLG dataset for Examples 2–3 |
| `python_command` | `python3` | Python interpreter (set `python` on Windows if needed) |

<details>
<summary>All variables</summary>

| Variable | Default | Description |
|----------|---------|-------------|
| `subscription_id` | *(required)* | Azure subscription ID |
| `resource_group_name` | `rg-kueue-and-ray-on-aks` | Resource group name |
| `cluster_name` | `kueue-and-ray-on-aks` | AKS cluster name |
| `location` | `eastus2` | Azure region |
| `kubernetes_version` | `1.35` | Kubernetes version |
| `sku_tier` | `Standard` | AKS SKU tier |
| `system_node_count` | `2` | System pool node count |
| `system_vm_size` | `Standard_D4ds_v6` | System pool VM size |
| `gpu_enabled` | `true` | GPU mode toggle |
| `gpu_node_pool_name` | `gpupool` | GPU pool name |
| `gpu_vm_size` | `Standard_ND96amsr_A100_v4` | GPU VM SKU |
| `gpu_node_count` | `1` | GPU node count |
| `gpu_count_per_node` | `8` | GPUs per node (must match SKU) |
| `gpu_os_sku` | `Ubuntu` | GPU node OS |
| `gpu_zones` | `null` | GPU pool availability zones |
| `cpu_node_pool_name` | `cpupool` | CPU pool name (when `gpu_enabled=false`) |
| `cpu_node_count` | `3` | CPU pool node count |
| `cpu_vm_size` | `Standard_D8ds_v6` | CPU pool VM size |
| `kuberay_chart_version` | `1.6.1` | KubeRay Helm chart version |
| `kuberay_operator_image_repository` | `mcr.microsoft.com/oss/v2/kuberay/operator` | KubeRay operator image repository |
| `kuberay_operator_image_tag` | `v1.6.1` | KubeRay operator image tag |
| `kuberay_enable_init_container_injection` | `true` | Inject wait-for-gcs init containers into Ray pods |
| `kueue_chart_version` | `0.17.1` | Kueue Helm chart version |
| `kueue_controller_image_repository` | `mcr.microsoft.com/oss/v2/kueue/kueue` | Kueue controller image repository |
| `kueue_controller_image_tag` | `v0.17.1` | Kueue controller image tag |
| `gpu_monitoring_chart_version` | `0.1.1` | GPU monitoring chart version |
| `gpu_monitoring_sku_name` | `a100` | gpuSkus key for gpu-monitoring Helm values |
| `ray_image` | `mcr.microsoft.com/aks/ai-runtime/ray:py3.12-ray2.55.1-cuda13.0` | Ray image for Module 3 workloads |
| `storage_account_name` | *(auto-generated)* | Globally unique storage account name |
| `storage_account_name_prefix` | `rayaks` | Prefix for auto-generated name |
| `aurora_container_name` | `aurora` | Blob container for Aurora data |
| `llm_pipeline_container_name` | `llm-pipeline` | Blob container for LLM data |
| `workload_identity_name` | `ray-workload-identity` | Managed identity name |
| `workload_namespace` | `ray` | Kubernetes namespace for workloads |
| `workload_service_account_name` | `ray-workload` | ServiceAccount name |
| `upload_aurora_inputs` | `true` | Upload WeatherBench2 data |
| `aurora_init_date` | `2021-08-29T00:00` | Init timestamp for aurora data |
| `aurora_region` | `gulf` | Region for WeatherBench2 generator |
| `upload_viggo_dataset` | `true` | Upload viggo NLG dataset |
| `python_command` | `python3` | Python interpreter (set `python` on Windows if needed) |
| `tags` | `{ scenario = "kueue-and-ray-on-aks" }` | Tags applied to all Azure resources |

</details>

### CPU-only mode

If you don't have GPU quota or want to test queue configs without GPUs:

```bash
terraform apply \
  -var="subscription_id=<your-subscription-id>" \
  -var="gpu_enabled=false"
```

This provisions a 3-node CPU pool (`Standard_D8ds_v6`) instead of a GPU node.
GPU monitoring is skipped automatically.

## Connect to the cluster

After `terraform apply` completes:

**Linux / macOS:**

```bash
# Option A: use the terraform output
eval "$(terraform output -raw get_credentials_command)"

# Option B: manual
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name) \
  --overwrite-existing
```

**Windows (PowerShell):**

```powershell
# Option A: use the terraform output
Invoke-Expression (terraform output -raw get_credentials_command)

# Option B: manual
az aks get-credentials `
  --resource-group (terraform output -raw resource_group_name) `
  --name (terraform output -raw cluster_name) `
  --overwrite-existing
```

## Verify

Run these checks to confirm everything is healthy:

### 1. Nodes

```bash
kubectl get nodes -o wide
```

Expected: 2 system nodes + your workload nodes (1 GPU node or 3 CPU nodes).

### 2. KubeRay operator

```bash
kubectl -n kuberay-system get pods
```

Expected: `kuberay-operator-*` pod in `Running` state.

Verify init container injection is enabled (required for MCR Ray images):

```bash
kubectl -n kuberay-system get deploy kuberay-operator \
  -o jsonpath='{.spec.template.spec.containers[0].env}' | python3 -m json.tool
```

Look for `ENABLE_INIT_CONTAINER_INJECTION = true`.

### 3. Kueue controller

```bash
kubectl -n kueue-system get pods
```

Expected: `kueue-controller-manager-*` pod in `Running` state.

Verify the Kueue integrations are enabled:

```bash
kubectl -n kueue-system get cm kueue-manager-config \
  -o jsonpath='{.data.controller_manager_config\.yaml}' | grep -A5 'frameworks:'
```

Expected: `batch/job`, `pod`, `ray.io/rayjob`.

### 4. GPU monitoring (GPU mode only)

```bash
kubectl -n gpu-monitoring get daemonsets
```

Expected: DCGM exporter DaemonSet running on GPU nodes. If `gpu_enabled=false`,
the `gpu-monitoring` namespace will not exist — this is expected.

### 5. Storage and datasets

```bash
# Aurora data (init/truth pair for Example 1)
az storage blob list \
  -c $(terraform output -raw aurora_container_name) \
  --account-name $(terraform output -raw storage_account_name) \
  --prefix data/ \
  --auth-mode login \
  --query "[].{name:name, size:properties.contentLength}" \
  -o table

# Viggo dataset (train/val/test for Examples 2–3)
az storage blob list \
  -c $(terraform output -raw llm_pipeline_container_name) \
  --account-name $(terraform output -raw storage_account_name) \
  --prefix data/ \
  --auth-mode login \
  --query "[].{name:name, size:properties.contentLength}" \
  -o table
```

Expected:
- Aurora container: `data/init-2021-01-01-00z.npz` (~2 MB) and `data/truth-2021-01-01-06z.npz` (~62 KB)
- LLM pipeline container: `data/train.jsonl`, `data/val.jsonl`, `data/test.jsonl`, `data/dataset_info.json`

### 6. Workload identity

```bash
terraform output -raw ray_workload_sa_yaml
```

This renders the ServiceAccount YAML you'll apply in Module 2. Verify it
includes the `azure.workload.identity/client-id` and
`azure.workload.identity/tenant-id` annotations.

## Troubleshooting

### GPU quota errors

```
Error: creating Node Pool: InsufficientQuota
```

Request quota for **Standard NDAMSv4_A100Family** in your region via the
[Azure portal quota page](https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas).
You need at least 96 vCPUs. Alternatively, set `gpu_enabled = false` to
use CPU-only mode.

### MS Graph access errors

```
Error: checking for presence of existing Resource Group
```

Some environments restrict MS Graph API access. Pass the subscription ID
explicitly so the azurerm provider doesn't need to resolve metadata:

```bash
terraform apply -var="subscription_id=<your-subscription-id>"
```

Or when using managed identity:

```bash
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID=<your-subscription-id>
terraform apply -var="subscription_id=$ARM_SUBSCRIPTION_ID"
```

### Helm release timeout

If a Helm release times out (default: 10 minutes), it usually means the
cluster API server or node pool wasn't ready in time. Run `terraform apply`
again — Terraform will pick up where it left off.

### WeatherBench2 download is slow (~2 GiB)

The Aurora data generation step downloads ~2 GiB of ERA5 data from Google
Cloud Storage on the first run. This is cached locally after the first
download. If the step times out, run `terraform apply` again — the generator
is idempotent.

To skip the Aurora data upload entirely:

```bash
terraform apply -var="upload_aurora_inputs=false" -var="subscription_id=..."
```

## Clean up

To destroy all resources created by this module:

```bash
terraform destroy -var="subscription_id=<your-subscription-id>"
```

> **Note:** If you applied Kueue queue manifests (Module 2), delete them first
> with `kubectl delete -f` to avoid finalizer delays during `terraform destroy`.

## Next steps

Continue to [Module 2 — Kueue Queues](../2-kueue-queues/) to configure quota
management before submitting workloads.
