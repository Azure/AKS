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
  default     = "westus3"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "system_node_pool_vm_size" {
  type        = string
  description = "The size of the Virtual Machine."
  default     = "Standard_D2_v2"
}

variable "system_node_pool_node_count" {
  type        = number
  description = "The initial quantity of nodes for the system node pool."
  default     = 1
}

variable "ray_node_pool_vm_size" {
  type        = string
  description = "The size of the Virtual Machine."
  default     = "Standard_D4s_v4"
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