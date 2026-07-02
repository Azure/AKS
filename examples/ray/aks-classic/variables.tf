variable "subscription_id" {
  description = "The Azure subscription ID."
  type        = string
}

variable "resource_group_owner" {
  description = "The owner of the resource group."
  type        = string
}

variable "resource_group_location" {
  type        = string
  default     = "centralus"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "system_node_pool_vm_size" {
  type        = string
  description = "The size of the Virtual Machine for the system node pool."
  default     = "Standard_D4ds_v4"
}

variable "system_node_pool_node_count" {
  type        = number
  description = "The initial quantity of nodes for the system node pool."
  default     = 3
}

variable "ray_node_pool_vm_size" {
  type        = string
  description = "The size of the Virtual Machine for the Ray worker node pool."
  default     = "Standard_D16ds_v7"
}

variable "ray_node_pool_node_count" {
  type        = number
  description = "The initial quantity of nodes for the Ray worker node pool."
  default     = 2
}

variable "kubernetes_version" {
  type        = string
  description = "The Kubernetes version for the AKS cluster."
  default     = "1.35"
}

variable "helm_registry" {
  type        = string
  description = "OCI registry for AKS AI Runtime Helm charts."
  default     = "oci://mcr.microsoft.com/aks/ai-runtime/helm"
}

variable "kueue_version" {
  type        = string
  description = "Version of the Kueue Helm chart."
  default     = "0.17.1"
}

variable "kuberay_operator_version" {
  type        = string
  description = "Version of the KubeRay Operator Helm chart."
  default     = "1.6.1"
}

variable "msi_id" {
  type        = string
  description = "The Managed Service Identity ID. Set this value if you're running this example using Managed Identity as the authentication method."
  default     = null
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}