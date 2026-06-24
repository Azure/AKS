terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {}

  # When running from an Azure VM with managed identity, set:
  #   export ARM_USE_MSI=true
  #   export ARM_SUBSCRIPTION_ID=<your-subscription-id>
  #
  # When running from a local workstation with az CLI auth:
  #   export ARM_SUBSCRIPTION_ID=<your-subscription-id>
  #
  # Passing subscription_id here ensures the provider does not need
  # MS Graph access to resolve tenant/subscription metadata.
  subscription_id = var.subscription_id
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.demo.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.demo.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.demo.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.demo.kube_config[0].cluster_ca_certificate)
  }
}
