# ---------------------------------------------------------------------------
# Cluster outputs — consumed by later Terraform work items (W1.2, W1.3)
# and by the Page 1 README verification steps.
# ---------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group containing all Module 1 resources."
  value       = azurerm_resource_group.demo.name
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.demo.name
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster. Pipe to a file or use get_credentials_command instead."
  value       = azurerm_kubernetes_cluster.demo.kube_config_raw
  sensitive   = true
}

output "get_credentials_command" {
  description = "Run this after terraform apply to point kubectl at the cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.demo.name} --name ${azurerm_kubernetes_cluster.demo.name} --overwrite-existing"
}

output "workload_node_pool_name" {
  description = "Name of the workload node pool (GPU or CPU depending on gpu_enabled)."
  value       = azurerm_kubernetes_cluster_node_pool.workload.name
}

output "workload_vm_size" {
  description = "VM size used by the workload node pool."
  value       = azurerm_kubernetes_cluster_node_pool.workload.vm_size
}

output "gpu_enabled" {
  description = "Whether the cluster was provisioned with a GPU node pool."
  value       = var.gpu_enabled
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster. Used by W1.3 to create the federated identity credential."
  value       = azurerm_kubernetes_cluster.demo.oidc_issuer_url
}

output "ray_image" {
  description = "Default Ray image for Module 3 workload manifests."
  value       = var.ray_image
}

# ---------------------------------------------------------------------------
# Helm release outputs — useful for verify steps in the Page 1 README
# ---------------------------------------------------------------------------

output "kuberay_namespace" {
  description = "Namespace where the KubeRay operator is installed."
  value       = helm_release.kuberay_operator.namespace
}

output "kuberay_chart_version" {
  description = "KubeRay operator chart version that was installed."
  value       = helm_release.kuberay_operator.version
}

output "kueue_namespace" {
  description = "Namespace where Kueue is installed."
  value       = helm_release.kueue.namespace
}

output "kueue_chart_version" {
  description = "Kueue chart version that was installed."
  value       = helm_release.kueue.version
}

output "gpu_monitoring_namespace" {
  description = "Namespace where gpu-monitoring is installed. Empty string when gpu_enabled = false."
  value       = var.gpu_enabled ? helm_release.gpu_monitoring[0].namespace : ""
}

output "gpu_monitoring_chart_version" {
  description = "gpu-monitoring chart version that was installed. Empty string when gpu_enabled = false."
  value       = var.gpu_enabled ? helm_release.gpu_monitoring[0].version : ""
}

# ===========================================================================
# W1.3 — Storage + workload identity outputs
# ===========================================================================

output "storage_account_name" {
  description = "Name of the shared storage account."
  value       = azurerm_storage_account.demo.name
}

output "aurora_container_name" {
  description = "Blob container for Aurora data and checkpoints."
  value       = azurerm_storage_container.aurora.name
}

output "llm_pipeline_container_name" {
  description = "Blob container for LLM dataset and LoRA artifacts."
  value       = azurerm_storage_container.llm_pipeline.name
}

output "aurora_input_base_url" {
  description = "HTTPS URL prefix for Aurora init/truth .npz inputs (aurora/data/)."
  value       = local.aurora_input_base_url
}

output "aurora_output_base_url" {
  description = "HTTPS URL prefix for Aurora fine-tune checkpoint outputs (aurora/checkpoints/)."
  value       = local.aurora_output_base_url
}

output "llm_pipeline_lora_base_uri" {
  description = "Azure Blob URI prefix for LLM pipeline LoRA adapter uploads. Format matches _upload_lora_to_azure() in llm_training.py."
  value       = local.llm_pipeline_lora_base_uri
}

output "workload_identity_client_id" {
  description = "Client ID of the ray-workload managed identity. Used as the azure.workload.identity/client-id annotation on the ServiceAccount."
  value       = azurerm_user_assigned_identity.ray_workload.client_id
}

output "tenant_id" {
  description = "Azure tenant ID. Used as the azure.workload.identity/tenant-id annotation on the ServiceAccount."
  value       = azurerm_kubernetes_cluster.demo.identity[0].tenant_id
}

output "ray_workload_sa_yaml" {
  description = "Fully rendered ServiceAccount YAML. Apply with: terraform output -raw ray_workload_sa_yaml | kubectl apply -f -"
  value       = <<-YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ${var.workload_service_account_name}
      namespace: ${var.workload_namespace}
      annotations:
        azure.workload.identity/client-id: ${azurerm_user_assigned_identity.ray_workload.client_id}
        azure.workload.identity/tenant-id: ${azurerm_kubernetes_cluster.demo.identity[0].tenant_id}
    YAML
}

# ===========================================================================
# W1.4 — Aurora data upload outputs
# ===========================================================================

output "aurora_data_uploaded" {
  description = "Whether Aurora WeatherBench2 input data was uploaded to the aurora container."
  value       = var.upload_aurora_inputs
}

# ===========================================================================
# W1.5 — Viggo dataset outputs
# ===========================================================================

output "viggo_dataset_uploaded" {
  description = "Whether the viggo dataset was uploaded to the llm-pipeline container."
  value       = var.upload_viggo_dataset
}

output "viggo_data_prefix" {
  description = "Blob prefix where viggo dataset files are stored. Use with az storage blob list -c llm-pipeline --prefix <this>."
  value       = "data/"
}
