---
title: "Deploy Apps to AKS Automatic with Terraform and the Helm Provider"
date: 2025-12-16
description: "Learn how to deploy AKS Automatic with the AzApi provider for Terraform and configure the Helm provider for Azure RBAC token-based authentication."
authors: [paul-yu]
tags: [aks-automatic, developer, best-practices]
---

Deploying applications to AKS Automatic with Terraform requires a different authentication approach than traditional AKS clusters. AKS Automatic uses Azure RBAC exclusively, which means you can't download a kubeconfig file with static credentials. This post explores options for configuring the Helm provider to work with AKS Automatic—or any AKS cluster using Azure RBAC—using Azure CLI, service principals, or managed identities.

<!-- truncate -->

## The challenge

When you create an AKS Automatic cluster, Azure enables several production-ready defaults, including:

- Azure RBAC for Kubernetes authorization
- Disabled local accounts (no static kubeconfig credentials)
- Workload Identity authentication

These defaults strengthen security, but they also mean the typical Helm provider configuration that relies on a kubeconfig file won't work. Instead, you need to configure the Helm provider to use token-based authentication.

:::tip

The authentication approach demonstrated here also applies to the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/), which shares the same authentication mechanisms.

:::

## Prerequisites

Before you begin, ensure you have:

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.14 or later
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.81 or later, installed and authenticated
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) v1.34 or later
- [kubelogin](https://azure.github.io/kubelogin/install.html) v0.2.13 or later
- [Helm](https://helm.sh/docs/intro/install/) v3 or later
- An Azure subscription with permissions to create AKS clusters

## Deploy AKS Automatic with AzApi provider

The [AzApi provider](https://registry.terraform.io/providers/Azure/azapi/latest/docs) is a lightweight Terraform provider that allows you to deploy Azure resources using the Azure Resource Manager (ARM) API. In most cases, it's simpler to use the [AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) but when you're looking to deploy new Azure services that aren't yet supported by the AzureRM provider, AzApi is a great alternative.

Create a new directory and add a Terraform configuration file (for example, `main.tf`) with the following code to deploy an AKS Automatic cluster:

```hcl
terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.8.0, < 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

resource "random_pet" "this" {
  separator = ""
}

resource "azurerm_resource_group" "this" {
  location = "swedencentral"
  name     = "rg-${random_pet.this.id}"
}

resource "azapi_resource" "this" {
  type                      = "Microsoft.ContainerService/managedClusters@2025-10-02-preview"
  parent_id                 = azurerm_resource_group.this.id
  location                  = azurerm_resource_group.this.location
  name                      = "aks-${random_pet.this.id}"
  schema_validation_enabled = false # use when azapi local schema check isn't aware of the latest api version

  body = {
    identity = {
      type = "SystemAssigned"
    },
    properties = {
      agentPoolProfiles = [
        {
          name  = "systempool"
          mode  = "System"
          count = 3
        }
      ]
    }
    sku = {
      name = "Automatic"
      tier = "Standard"
    }
  }
}

resource "azurerm_role_assignment" "this" {
  scope                = azapi_resource.this.id
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
}
```

This minimal configuration creates an AKS Automatic cluster and assigns the current user the **Azure Kubernetes Service RBAC Cluster Admin** role.

Run the following commands to deploy the cluster:

```bash
terraform init
terraform apply
```

After 7 to 10 minutes, your AKS cluster is ready.

## Helm provider authentication options

The [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs) allows you to authenticate to a Kubernetes cluster in several ways:

1. **Using a kubeconfig file**: This option doesn't work because local accounts are disabled in AKS Automatic clusters.
2. **Supplying credentials directly**: This option is possible, but with a twist—you need to obtain a bearer token first and then supply it to the provider.
3. **Using the exec plugin**: This option calls an external program to obtain short-lived credentials. It uses the [client-go credential plugin](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#client-go-credential-plugins) mechanism built into `kubectl` and the Kubernetes client libraries.

With that context, let's explore the two viable options for configuring the Helm provider.

:::tip

Both options require retrieving the connection details—the host URL and cluster CA certificate—from the AKS cluster. The AzApi provider doesn't expose these values directly; however, you can use the `azurerm_kubernetes_cluster` data source as a workaround.

Add the following to the bottom of your `main.tf` file:

```hcl
data "azurerm_kubernetes_cluster" "this" {
  name                = azapi_resource.this.name
  resource_group_name = azurerm_resource_group.this.name
}
```

:::

### Option 1: Configure the Helm provider with Azure bearer token authentication

The Helm provider's [`kubernetes` block](https://registry.terraform.io/providers/hashicorp/helm/latest/docs#kubernetes-1) supports a [`token` argument](https://registry.terraform.io/providers/hashicorp/helm/latest/docs#token-1) that lets you supply a bearer token directly for authentication.

You can obtain access tokens using the Azure CLI. If you're authenticated with `az login`, you can get a token for the AKS resource like this:

```bash
az account get-access-token --resource 6dae42f8-4368-4678-94ff-3960e28e3630
```

:::info

The resource ID `6dae42f8-4368-4678-94ff-3960e28e3630` is the well-known application ID for **Azure Kubernetes Service AAD Server**. This ID is the same for all AKS clusters using Microsoft Entra authentication.

:::

You can use the [`external` provider](https://registry.terraform.io/providers/hashicorp/external/latest/docs) in Terraform to run this command and capture the token as an external data source.

Add the following to your `main.tf` file:

```hcl
data "external" "this" {
  program = ["bash", "-c", "az account get-access-token --resource 6dae42f8-4368-4678-94ff-3960e28e3630 --query '{token: accessToken}' -o json"]
}
```

This command runs the Azure CLI and extracts the access token in JSON format, which you can then use in the Helm provider configuration.

Now you have everything needed to configure the Helm provider:

```hcl
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
    token                  = data.external.this.result.token
  }
}
```

This configuration uses the host and cluster CA certificate from the AKS cluster data source and gains access to the cluster using the bearer token from the external data source.

If you are solely using Azure CLI authentication (e.g., `az login`), this approach works well. However, if you're deploying from a CI/CD pipeline or using service principals or managed identities, the next option is more flexible.

### Option 2: Configure the Helm provider to use the exec plugin with kubelogin

The Helm provider also supports using the `exec` plugin mechanism to obtain credentials dynamically. This approach is more flexible and works well with various authentication methods supported by [kubelogin](https://azure.github.io/kubelogin/index.html) which is a [Kubernetes client-go credential plugin](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#client-go-credential-plugins) for Azure.

To use this approach, add the following to your `main.tf`:

```hcl
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630"  # Azure Kubernetes Service AAD Server
      ]
    }
  }
}
```

This configuration uses the kubelogin tool to obtain an access token based on your existing Azure CLI authentication context. Therefore, you must ensure it is installed and accessible in your system's PATH.

:::info

The kubelogin tool is an open-source project maintained by Microsoft that implements the Kubernetes client-go credential plugin interface for Azure authentication. It supports multiple login methods, including Azure CLI, managed identity, and service principal.

If you're deploying applications from a CI/CD pipeline or HCP Terraform or Terraform Enterprise that uses a service principal or managed identity instead of Azure CLI, you can adjust the command arguments accordingly.

For example, to use a service principal with a client secret, the Helm provider configuration would look like this:

```hcl
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"             # Make sure kubelogin is installed and accessible in PATH
      args = [
        "get-token",
        "--login",
        "spn",
        "--environment",
        "AzurePublicCloud",                 # Adjust if using a different cloud
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630",
        "--client-id",
        var.service_principal_client_id,    # Replace with your SPN client ID
        "--tenant-id",
        var.service_principal_tenant_id     # Replace with your SPN tenant ID
      ]
      env = {
        AAD_SERVICE_PRINCIPAL_CLIENT_SECRET = var.service_principal_client_secret
      }
    }
  }
}
```

Note the client secret is passed via the `AAD_SERVICE_PRINCIPAL_CLIENT_SECRET` environment variable instead of the `--client-secret` command-line argument. This approach avoids exposing the secret in process listings or logs where it could be captured by other users or system tooling.

There are additional options for using managed identities as well. See the [kubelogin documentation](https://azure.github.io/kubelogin/index.html) for more details.

:::

## Deploy an application with Helm

Now you can use the Helm provider to deploy applications. Add the following to your `main.tf` file to deploy the [AKS Store Demo application](https://github.com/Azure-Samples/aks-store-demo) Helm chart:

```hcl
resource "helm_release" "example" {
  name       = "aks-store-demo"
  repository = "https://azure-samples.github.io/aks-store-demo"
  chart      = "aks-store-demo-chart"
  version    = "1.5.0"
}
```

Run the following commands and you'll see the Helm provider uses the configured authentication method to connect to the AKS Automatic cluster and deploy the AKS Store Demo application.

```sh
terraform init -upgrade
terraform apply
```

If all goes well, you should see output indicating the release was deployed successfully 🚀

## Conclusion

AKS Automatic provides production-ready defaults that improve security but require a different authentication approach for automation tools like Helm or Kubernetes providers for Terraform. By using the `exec` plugin with kubelogin or bearer token-based approaches, you can seamlessly integrate Helm deployments into your Terraform workflow while maintaining the security benefits of Azure RBAC.

## Resources

- [AKS Automatic documentation](https://learn.microsoft.com/azure/aks/intro-aks-automatic)
- [AzApi provider documentation](https://registry.terraform.io/providers/Azure/azapi/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [kubelogin documentation](https://azure.github.io/kubelogin/index.html)
- [Azure Kubernetes Service RBAC roles](https://learn.microsoft.com/azure/aks/manage-azure-rbac)
