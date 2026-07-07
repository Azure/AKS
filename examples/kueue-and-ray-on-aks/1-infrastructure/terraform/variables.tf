# ---------------------------------------------------------------------------
# Cross-platform Python executable
# ---------------------------------------------------------------------------

variable "python_command" {
  description = "Python interpreter command. Used by local-exec provisioners for data upload scripts. Override to 'python' on Windows if 'python3' is not available."
  type        = string
  default     = "python3"
}

# ---------------------------------------------------------------------------
# Core cluster identity
# ---------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Azure resource group to create. All Module 1 resources land here."
  type        = string
  default     = "rg-kueue-and-ray-on-aks"
}

variable "cluster_name" {
  description = "AKS cluster name. Also used as the DNS prefix, so it must start with a letter, contain only letters, digits, and hyphens, and be at most 54 characters."
  type        = string
  default     = "kueue-and-ray-on-aks"

  validation {
    condition     = can(regex("^[a-zA-Z][-a-zA-Z0-9]{0,53}$", var.cluster_name))
    error_message = "cluster_name must start with a letter, contain only letters/digits/hyphens, and be 1-54 characters (AKS dns_prefix constraint)."
  }
}

variable "location" {
  description = "Azure region for the resource group and cluster."
  type        = string
  default     = "eastus2"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version."
  type        = string
  default     = "1.35"
}

variable "sku_tier" {
  description = "AKS SKU tier. Standard is recommended for production; Free is acceptable for quick demos."
  type        = string
  default     = "Standard"
}

# ---------------------------------------------------------------------------
# System node pool
# ---------------------------------------------------------------------------

variable "system_node_count" {
  description = "Number of nodes in the system (control-plane-adjacent) node pool."
  type        = number
  default     = 2
}

variable "system_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D4ds_v6"
}

# ---------------------------------------------------------------------------
# GPU / CPU mode toggle
# ---------------------------------------------------------------------------

variable "gpu_enabled" {
  description = "When true (default) a GPU workload node pool is provisioned. Set to false to provision a CPU-only pool instead — useful for testing the queue configuration without GPU quota."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# GPU workload node pool  (used only when gpu_enabled = true)
# ---------------------------------------------------------------------------

variable "gpu_node_pool_name" {
  description = "Name for the GPU user node pool. AKS pool names must be lowercase alphanumeric, max 12 characters."
  type        = string
  default     = "gpupool"

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.gpu_node_pool_name))
    error_message = "gpu_node_pool_name must be lowercase alphanumeric and at most 12 characters."
  }
}

variable "gpu_vm_size" {
  description = "GPU VM SKU. The default is Standard_ND96amsr_A100_v4 (8×A100 80 GB). A-series quota is generally easier to request than H-series for public-subscription readers."
  type        = string
  default     = "Standard_ND96amsr_A100_v4"
}

variable "gpu_node_count" {
  description = "Number of GPU nodes to provision. One 8-GPU node is sufficient for all four workload examples."
  type        = number
  default     = 1
}

variable "gpu_count_per_node" {
  description = "Number of GPUs exposed per GPU node. Used only by the GPU monitoring Helm values; must match gpu_vm_size."
  type        = number
  default     = 8
}

variable "gpu_os_sku" {
  description = "OS SKU for GPU nodes."
  type        = string
  default     = "Ubuntu"
}

variable "gpu_zones" {
  description = "Availability zones for the GPU node pool. Leave null to let AKS choose."
  type        = list(string)
  default     = null
}

# ---------------------------------------------------------------------------
# CPU workload node pool  (used only when gpu_enabled = false)
# ---------------------------------------------------------------------------

variable "cpu_node_pool_name" {
  description = "Name for the CPU user node pool. Used only when gpu_enabled = false."
  type        = string
  default     = "cpupool"

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.cpu_node_pool_name))
    error_message = "cpu_node_pool_name must be lowercase alphanumeric and at most 12 characters."
  }
}

variable "cpu_node_count" {
  description = "Number of CPU nodes when gpu_enabled = false."
  type        = number
  default     = 3
}

variable "cpu_vm_size" {
  description = "CPU VM size for the workload pool when gpu_enabled = false."
  type        = string
  default     = "Standard_D8ds_v6"
}

# ---------------------------------------------------------------------------
# Helm chart versions
# ---------------------------------------------------------------------------

variable "kuberay_chart_version" {
  description = "KubeRay operator Helm chart version."
  type        = string
  default     = "1.6.1"
}

variable "kuberay_operator_image_repository" {
  description = "KubeRay operator image repository."
  type        = string
  default     = "mcr.microsoft.com/oss/v2/kuberay/operator"
}

variable "kuberay_operator_image_tag" {
  description = "KubeRay operator image tag."
  type        = string
  default     = "v1.6.1"
}

variable "kuberay_enable_init_container_injection" {
  description = "Inject wait-for-gcs init containers into Ray pods. Keep true when using the pre-built MCR Ray images."
  type        = bool
  default     = true
}

variable "kueue_chart_version" {
  description = "Kueue Helm chart version."
  type        = string
  default     = "0.17.1"
}

variable "kueue_controller_image_repository" {
  description = "Kueue controller image repository."
  type        = string
  default     = "mcr.microsoft.com/oss/v2/kueue/kueue"
}

variable "kueue_controller_image_tag" {
  description = "Kueue controller image tag."
  type        = string
  default     = "v0.17.1"
}

variable "gpu_monitoring_chart_version" {
  description = "AKS AI Runtime gpu-monitoring Helm chart version. Only used when gpu_enabled = true."
  type        = string
  default     = "0.1.1"
}

variable "gpu_monitoring_sku_name" {
  description = "gpuSkus key in the gpu-monitoring Helm values. Use 'a100' for Standard_ND*_A100_* SKUs."
  type        = string
  default     = "a100"
}

# ---------------------------------------------------------------------------
# Ray workload image
# ---------------------------------------------------------------------------

variable "ray_image" {
  description = "Default Ray image used by all Module 3 workload examples. Exported as an output so manifest templates can reference it via envsubst."
  type        = string
  default     = "mcr.microsoft.com/aks/ai-runtime/ray:py3.12-ray2.55.1-cuda13.0"
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all Azure resources managed by this Terraform stack."
  type        = map(string)
  default = {
    scenario = "kueue-and-ray-on-aks"
  }
}

# ---------------------------------------------------------------------------
# Azure subscription
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID. Passed to the azurerm provider so it does not need MS Graph access to resolve metadata. Override via -var or ARM_SUBSCRIPTION_ID."
  type        = string
}

# ===========================================================================
# W1.3 — Storage + workload identity variables
# ===========================================================================

# ---------------------------------------------------------------------------
# Storage account
# ---------------------------------------------------------------------------

variable "storage_account_name" {
  description = "Globally unique storage account name. Leave empty to auto-generate from storage_account_name_prefix."
  type        = string
  default     = ""

  validation {
    condition     = var.storage_account_name == "" || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters or digits."
  }
}

variable "storage_account_name_prefix" {
  description = "Prefix for the auto-generated storage account name. An 8-character random suffix is appended."
  type        = string
  default     = "rayaks"

  validation {
    condition     = can(regex("^[a-z0-9]{3,16}$", var.storage_account_name_prefix))
    error_message = "storage_account_name_prefix must be 3-16 lowercase letters or digits."
  }
}

# ---------------------------------------------------------------------------
# Blob containers
# ---------------------------------------------------------------------------

variable "aurora_container_name" {
  description = "Blob container for Aurora weather data and fine-tune checkpoints."
  type        = string
  default     = "aurora"
}

variable "llm_pipeline_container_name" {
  description = "Blob container for LLM pipeline viggo dataset and LoRA artifacts. Must stay 'llm-pipeline' — hardcoded in llm_training.py."
  type        = string
  default     = "llm-pipeline"
}

# ---------------------------------------------------------------------------
# Workload identity
# ---------------------------------------------------------------------------

variable "workload_identity_name" {
  description = "Name for the user-assigned managed identity bound to Ray workload pods."
  type        = string
  default     = "ray-workload-identity"
}

variable "workload_namespace" {
  description = "Kubernetes namespace for Ray workloads. Used in the federated credential subject."
  type        = string
  default     = "ray"
}

variable "workload_service_account_name" {
  description = "Kubernetes ServiceAccount name for Ray workload pods."
  type        = string
  default     = "ray-workload"
}

# ===========================================================================
# W1.4 — Aurora WeatherBench2 data upload variables
# ===========================================================================

variable "upload_aurora_inputs" {
  description = "Generate and upload WeatherBench2 Hurricane-Ida init/truth pair to the aurora blob container. Requires Python 3.10+ with xarray, zarr, gcsfs, dask, numpy. Set to false if you've already populated the container or want to bring your own ERA5 case."
  type        = bool
  default     = true
}

variable "aurora_init_date" {
  description = "Init timestamp for the WeatherBench2 download (format: YYYY-MM-DDTHH:MM). Must align to a 6-hourly ERA5 analysis time (00:00, 06:00, 12:00, or 18:00). Default targets Hurricane Ida's Gulf landfall window so Example 1 produces a meaningful loss curve."
  type        = string
  default     = "2021-08-29T00:00"

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}T(00|06|12|18):00$", var.aurora_init_date))
    error_message = "aurora_init_date must be in YYYY-MM-DDTHH:MM format and aligned to a 6-hourly ERA5 analysis time (00:00, 06:00, 12:00, or 18:00)."
  }
}

variable "aurora_region" {
  description = "Region key for the WeatherBench2 generator. Supported: gulf, hawaii, california."
  type        = string
  default     = "gulf"

  validation {
    condition     = contains(["gulf", "hawaii", "california"], var.aurora_region)
    error_message = "aurora_region must be one of: gulf, hawaii, california."
  }
}

# W1.5 — Viggo dataset upload
# ===========================================================================

variable "upload_viggo_dataset" {
  description = "Download the viggo NLG dataset from S3 and upload to the llm-pipeline blob container. Set to false to skip."
  type        = bool
  default     = true
}
