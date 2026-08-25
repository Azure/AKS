# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# AKS cluster
#
# OIDC issuer and workload identity are enabled here so Module 1's
# storage + workload identity resources (W1.3) can add a federated
# credential without re-creating the cluster.
# ---------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "demo" {
  name                = var.cluster_name
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Workload identity requires the OIDC issuer.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "system"
    node_count = var.system_node_count
    vm_size    = var.system_vm_size

    # System pool does not run workloads.
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Workload node pool
#
# One resource covers both modes:
#   gpu_enabled = true  → GPU pool (Standard_ND96amsr_A100_v4 by default)
#   gpu_enabled = false → CPU pool (Standard_D8ds_v6 by default)
#
# GPU-specific additions:
#   - node label  accelerator: nvidia                        (auto-set by AKS on GPU SKUs)
#   - node label  aks.azure.com/gpu-sku: a100                (used by gpu-monitoring selector)
#   - no taint    (RayJob tolerations are omitted for simplicity; add var.gpu_node_taints
#                  and matching tolerations in Module 3 if you want taint-based isolation)
# ---------------------------------------------------------------------------

locals {
  # Cross-platform Python executable. On Windows the binary is typically
  # "python" while Linux/macOS use "python3".
  python_executable = var.python_command

  workload_node_pool_name = var.gpu_enabled ? var.gpu_node_pool_name : var.cpu_node_pool_name
  workload_vm_size        = var.gpu_enabled ? var.gpu_vm_size : var.cpu_vm_size
  workload_node_count     = var.gpu_enabled ? var.gpu_node_count : var.cpu_node_count

  # AKS automatically labels GPU nodes with 'accelerator=nvidia' (a reserved
  # label key that cannot be set via node pool config).  The gpu ResourceFlavor
  # in Module 2 matches on that label.  Here we only add supplementary labels
  # needed by gpu-monitoring's DaemonSet nodeSelector.
  workload_node_labels = var.gpu_enabled ? {
    "aks.azure.com/gpu-sku" = var.gpu_monitoring_sku_name
  } : {}
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = local.workload_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = local.workload_vm_size
  node_count            = local.workload_node_count
  mode                  = "User"
  os_sku                = var.gpu_enabled ? var.gpu_os_sku : "Ubuntu"
  zones                 = var.gpu_enabled ? var.gpu_zones : null

  # AKS automatically sets gpu_driver="Install" for GPU node pools.
  # Must be explicit so terraform doesn't see a diff after import/re-apply.
  gpu_driver = var.gpu_enabled ? "Install" : null

  node_labels = local.workload_node_labels

  # No taint by default — simplifies workload submission for new users.
  node_taints = []

  tags = var.tags
}

# ---------------------------------------------------------------------------
# KubeRay operator
# ---------------------------------------------------------------------------

resource "helm_release" "kuberay_operator" {
  name             = "kuberay-operator"
  repository       = "oci://mcr.microsoft.com/aks/ai-runtime/helm"
  chart            = "kuberay-operator"
  version          = var.kuberay_chart_version
  namespace        = "kuberay-system"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "image.repository"
    value = var.kuberay_operator_image_repository
  }

  set {
    name  = "image.tag"
    value = var.kuberay_operator_image_tag
  }

  # ENABLE_INIT_CONTAINER_INJECTION injects a wait-for-ray-gcs init container
  # into every Ray pod. GCS = Ray Global Control Store (not Google Cloud Storage).
  # Required when using the MCR Ray images (they rely on it for graceful startup
  # ordering).
  set {
    name  = "env[0].name"
    value = "ENABLE_INIT_CONTAINER_INJECTION"
  }

  set {
    name  = "env[0].value"
    value = tostring(var.kuberay_enable_init_container_injection)
    type  = "string"
  }

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [azurerm_kubernetes_cluster_node_pool.workload]
}

# ---------------------------------------------------------------------------
# Kueue
# ---------------------------------------------------------------------------

resource "helm_release" "kueue" {
  name             = "kueue"
  repository       = "oci://mcr.microsoft.com/aks/ai-runtime/helm"
  chart            = "kueue"
  version          = var.kueue_chart_version
  namespace        = "kueue-system"
  create_namespace = true
  wait             = true
  timeout          = 600

  # kueue-values.yaml enables the RayJob + RayCluster integrations alongside
  # batch/job and pod so Kueue can admit all four workload examples.
  values = [file("${path.module}/kueue-values.yaml")]

  set {
    name  = "controllerManager.manager.image.repository"
    value = var.kueue_controller_image_repository
  }

  set {
    name  = "controllerManager.manager.image.tag"
    value = var.kueue_controller_image_tag
  }

  set {
    name  = "controllerManager.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "controllerManager.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "controllerManager.tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [azurerm_kubernetes_cluster_node_pool.workload]
}

# ---------------------------------------------------------------------------
# GPU monitoring  (DCGM exporter + metrics collection)
#
# Only provisioned when gpu_enabled = true.  The chart reads gpuSkus to
# select which node pool to run the DaemonSet on; we pass the same labels
# that W1.1 stamped on the GPU node pool so the selector matches.
# ---------------------------------------------------------------------------

resource "helm_release" "gpu_monitoring" {
  count = var.gpu_enabled ? 1 : 0

  name             = "gpu-monitoring"
  repository       = "oci://mcr.microsoft.com/aks/ai-runtime/helm"
  chart            = "gpu-monitoring"
  version          = var.gpu_monitoring_chart_version
  namespace        = "gpu-monitoring"
  create_namespace = true
  wait             = true
  timeout          = 600

  # gpuSkus drives both the DaemonSet nodeSelector and DCGM field selection.
  # sku_name matches the aks.azure.com/gpu-sku label set on the node pool.
  values = [
    yamlencode({
      gpuSkus = {
        (var.gpu_monitoring_sku_name) = {
          instanceTypes = [var.gpu_vm_size]
          num_gpus      = var.gpu_count_per_node
        }
      }
    })
  ]

  depends_on = [azurerm_kubernetes_cluster_node_pool.workload]
}

# ---------------------------------------------------------------------------
# NVIDIA device plugin
#
# AKS "Driver only" mode (the default) installs the GPU kernel driver but
# does NOT deploy the Kubernetes device plugin.  Without it, nodes never
# advertise nvidia.com/gpu resources and GPU pods stay Pending.
#
# We deploy the upstream NVIDIA device plugin DaemonSet via its official Helm
# chart so GPU capacity is visible immediately after the node pool is ready.
# Only provisioned when gpu_enabled = true.
# ---------------------------------------------------------------------------

resource "helm_release" "nvidia_device_plugin" {
  count = var.gpu_enabled ? 1 : 0

  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.17.0"
  namespace  = "kube-system"
  wait       = true
  timeout    = 300

  # Override the default NFD-based affinity to target AKS GPU nodes using
  # the 'accelerator' label that AKS automatically stamps on GPU node pools.
  values = [
    yamlencode({
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [{
              matchExpressions = [{
                key      = "accelerator"
                operator = "In"
                values   = ["nvidia"]
              }]
            }]
          }
        }
      }
    })
  ]

  depends_on = [azurerm_kubernetes_cluster_node_pool.workload]
}

# ===========================================================================
# W1.3 — Storage + workload identity
# ===========================================================================

# ---------------------------------------------------------------------------
# Storage account
# ---------------------------------------------------------------------------

resource "random_string" "storage_suffix" {
  count   = var.storage_account_name == "" ? 1 : 0
  length  = 8
  lower   = true
  numeric = true
  special = false
  upper   = false
}

locals {
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : "${var.storage_account_name_prefix}${random_string.storage_suffix[0].result}"

  # Base URL helpers used by outputs and the ray_workload ServiceAccount template.
  aurora_container_url       = "https://${local.storage_account_name}.blob.core.windows.net/${var.aurora_container_name}"
  aurora_input_base_url      = "${local.aurora_container_url}/data"
  aurora_output_base_url     = "${local.aurora_container_url}/checkpoints"
  llm_pipeline_lora_base_uri = "azure://${var.llm_pipeline_container_name}@${local.storage_account_name}.blob.core.windows.net/lora"
}

resource "azurerm_storage_account" "demo" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  # Required by the subscription's no-anonymous-blob-access policy.
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Blob containers
# ---------------------------------------------------------------------------

resource "azurerm_storage_container" "aurora" {
  name                  = var.aurora_container_name
  storage_account_id    = azurerm_storage_account.demo.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "llm_pipeline" {
  # Name must stay "llm-pipeline" — hardcoded in llm_training.py.
  name                  = var.llm_pipeline_container_name
  storage_account_id    = azurerm_storage_account.demo.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# User-assigned managed identity
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "ray_workload" {
  name                = var.workload_identity_name
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Role assignment — Storage Blob Data Contributor at account scope so one
# assignment covers both aurora and llm-pipeline containers.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.demo.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.ray_workload.principal_id
  principal_type       = "ServicePrincipal"
}

# Grant the Terraform runner (az login identity) data-plane access so the
# upload provisioners can use --auth-mode login without falling back to
# account keys.  Subscriptions that disable shared-key access would fail
# without this.

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "uploader_blob_contributor" {
  scope                = azurerm_storage_account.demo.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_rbac" {
  depends_on      = [azurerm_role_assignment.uploader_blob_contributor]
  create_duration = "60s"
}

# ---------------------------------------------------------------------------
# Federated identity credential — binds the managed identity to the
# ray-workload ServiceAccount in the ray namespace.
# ---------------------------------------------------------------------------

resource "azurerm_federated_identity_credential" "ray_workload" {
  name                      = "ray-workload-federated"
  user_assigned_identity_id = azurerm_user_assigned_identity.ray_workload.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.demo.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.workload_namespace}:${var.workload_service_account_name}"
}

# ===========================================================================
# W1.4 — Aurora WeatherBench2 data upload
#
# Generates a single Hurricane-Ida (Gulf, 2021-08-29) init/truth pair from
# the public WeatherBench2 ERA5 Zarr store on GCS and uploads the two .npz
# files to the aurora blob container at data/.
#
# The generator produces real-timestamp filenames (init-2021-08-29-00z.npz)
# which are then copied to DEFAULT-name slots (init-2021-01-01-00z.npz,
# truth-2021-01-01-06z.npz) matching the submit.sh convention and the
# aurora_finetune.py default AURORA_INIT_FILE env var.
#
# Prerequisites (on the machine running terraform apply):
#   - Python 3.10+ with: xarray zarr gcsfs dask numpy
#   - az cli, logged in with write access to the storage account
#   - ~2 GiB network on first run (WeatherBench2 GCS download, cached after)
#
# Set upload_aurora_inputs = false to skip this step entirely.
# ===========================================================================

resource "null_resource" "aurora_data_upload" {
  count = var.upload_aurora_inputs ? 1 : 0

  triggers = {
    aurora_init_date = var.aurora_init_date
    aurora_region    = var.aurora_region
    storage_account  = azurerm_storage_account.demo.name
    container_name   = azurerm_storage_container.aurora.name
    generator_hash   = filesha256("${path.module}/scripts/populate_weatherbench2_regional_data.py")
  }

  provisioner "local-exec" {
    command = "${local.python_executable} ${path.module}/scripts/upload_aurora_data.py"

    environment = {
      GENERATOR_PATH   = "${path.module}/scripts/populate_weatherbench2_regional_data.py"
      AURORA_REGION    = var.aurora_region
      AURORA_INIT_DATE = var.aurora_init_date
      STORAGE_ACCOUNT  = azurerm_storage_account.demo.name
      CONTAINER_NAME   = azurerm_storage_container.aurora.name
      RESOURCE_GROUP   = azurerm_resource_group.demo.name
    }
  }

  depends_on = [
    azurerm_storage_container.aurora,
    azurerm_role_assignment.storage_blob_data_contributor,
    time_sleep.wait_for_rbac,
  ]
}

# ===========================================================================

# W1.5 — Viggo dataset download + upload
#
# Downloads the viggo NLG dataset (train/val/test JSONL + dataset_info.json)
# from the public S3 mirror and uploads it to llm-pipeline/data/ in the
# shared storage account.  The dataset_info.json file_name fields are
# rewritten to point at basenames in the same directory — matching the fixup
# logic in llm_training.py — so the in-blob copy is byte-compatible
# with the existing payload.
# ===========================================================================

resource "terraform_data" "viggo_dataset" {
  count = var.upload_viggo_dataset ? 1 : 0

  # Re-run only if the container or account changes.
  triggers_replace = [
    azurerm_storage_container.llm_pipeline.name,
    azurerm_storage_account.demo.name,
  ]

  provisioner "local-exec" {
    command = "${local.python_executable} ${path.module}/scripts/upload_viggo_dataset.py"

    environment = {
      STORAGE_ACCOUNT = azurerm_storage_account.demo.name
      CONTAINER_NAME  = azurerm_storage_container.llm_pipeline.name
      RESOURCE_GROUP  = azurerm_resource_group.demo.name
    }
  }

  depends_on = [
    azurerm_storage_container.llm_pipeline,
    azurerm_role_assignment.storage_blob_data_contributor,
    time_sleep.wait_for_rbac,
  ]
}
