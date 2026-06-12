---
title: "Deploy Anyscale on Azure with Terraform: a step-by-step guide"
description: "Deploy Anyscale on Azure end-to-end with Terraform, AKS managed Gateway API, Istio-based app routing, and the AzAPI provider for newly released services."
authors: [paul-yu]
tags: [anyscale, ray, app-routing, terraform]
---

A few weeks ago at Microsoft Build, the [public preview of Anyscale on Azure](https://www.anyscale.com/blog/anyscale-on-azure-public-preview-build-and-deploy-ai-scale) was announced. If you're not familiar, [Anyscale on Azure](https://learn.microsoft.com/azure/anyscale-on-azure/overview) is a managed platform for running distributed AI/ML workloads with [Ray](https://www.ray.io/) on AKS. It's an Azure Native integration, a co-engineered effort between Anyscale and Microsoft, that deploys an operator onto your AKS cluster and integrates with Microsoft Entra ID for SSO.

The official [quickstart](https://learn.microsoft.com/azure/anyscale-on-azure/quickstart-azure-cli-gateway-envoy) walks you through deploying Anyscale on Azure using the Azure CLI and Azure Portal with Envoy Gateway for ingress. That's a solid starting point, but if you're like me, you want everything in Terraform so your infrastructure is repeatable, version-controlled, and easy to tear down.

In this post, we'll walk through a Terraform configuration that deploys the full Anyscale on Azure stack, swapping out Envoy Gateway for [AKS managed Gateway API with Istio-based app routing](https://learn.microsoft.com/azure/aks/app-routing-gateway-api). With this approach, AKS handles the gateway lifecycle and you skip the step of installing and configuring Envoy Gateway entirely.

<!-- truncate -->

## What we're building

Before we dive into the code, here's a quick overview of what the Terraform configuration creates:

- A resource group to hold everything
- An AKS cluster (Standard tier) with Gateway API and Istio-based app routing enabled
- The Anyscale operator installed as an AKS cluster extension
- A user-assigned managed identity with a federated credential for the Anyscale operator
- An Azure Container Registry (Standard SKU) for container images
- A storage account with hierarchical namespace (HNS) enabled and a private blob container
- The Anyscale Cloud and Cloud Resource registered via the AzAPI provider (`Anyscale.Platform/clouds`)
- Role assignments for storage, container registry, and AKS access

The full Terraform code is available as a [GitHub Gist](https://gist.github.com/pauldotyu/4226b4d735f1903c7cb6a0f3d35bc655). In this post, I'll walk through each piece so you understand what's happening and why.

:::warning

This walkthrough is designed to get you up and running quickly. It's a great way to understand the components that go into an Anyscale on Azure deployment and how they fit together, but it's not intended for production use as-is. For production environments, follow [Azure landing zone architectures](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/) and apply your organization's security and governance best practices around networking, identity, logging, and policy.

:::

## Prerequisites

Before you get started, make sure you have the following:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) authenticated to a subscription
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Anyscale CLI](https://docs.anyscale.com/reference/quickstart-cli) (installed via [pipx](https://pipx.pypa.io/stable/))
- [jq](https://jqlang.github.io/jq/download/) for parsing Terraform outputs
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for interacting with the AKS cluster

Your subscription also needs the following resource providers registered:

- `Anyscale.Platform`
- `Microsoft.ContainerService`
- `Microsoft.ContainerRegistry`
- `Microsoft.Storage`
- `Microsoft.ManagedIdentity`

:::tip

The AzureRM Terraform provider will automatically register most required resource providers during deployment. If your account lacks permission to register providers, register them manually with `az provider register --namespace <provider-name>` before running `terraform apply`.

:::

:::caution

Anyscale on Azure is currently in preview and available in select regions. See [supported regions](https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions) for the latest list.

:::

## Step 1: Set up the Terraform providers

Create a new directory for your Terraform configuration and create a file named `main.tf`. For simplicity, we'll put everything in a single file so it's easy to follow along. In a real project, you'd probably want to split things up into separate files. See the [Terraform style guide on file names](https://developer.hashicorp.com/terraform/language/style#file-names) for best practices.

We'll need a few providers: `azurerm` for Azure resources, `azapi` for the Anyscale Platform resources, `azuread` for the service principal lookup, and a couple of utility providers. Add the following to your `main.tf`:

```hcl
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.76.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
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
```

We're using `azapi` here because the `Anyscale.Platform` resource type is brand new and not yet in the `azurerm` provider. The `azapi` provider lets us work with any ARM resource type directly, including preview ones. At the time of this writing, the `Anyscale.Platform` resource provider is not yet fully documented. I'll go into how I figured out the API schema for undocumented resources like this when we get to Step 5.

We also set `prevent_deletion_if_contains_resources = false` on the `azurerm` provider so that `terraform destroy` can cleanly remove the resource group without getting blocked by the resources inside it.

## Step 2: Create the foundational resources

Let's start with the basics: a resource group, some random naming helpers, and the storage and container registry resources that Anyscale needs. Add the following to your `main.tf`:

```hcl
variable "location" {
  description = "Azure region. Must support Anyscale on Azure."
  type        = string
  default     = "westus3"
  validation {
    condition     = contains(["westcentralus", "eastus", "eastus2", "westus2", "westus3", "southcentralus"], var.location)
    error_message = "Must be a region that supports Anyscale on Azure."
  }
}

data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "random_string" "example" {
  length  = 4
  special = false
  upper   = false
  lower   = true
  numeric = false
}

locals {
  random_name = "anyscale${random_integer.example.result}"
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}
```

The `location` variable has a validation block that restricts you to regions where Anyscale on Azure is currently supported. This saves you from potential deployment failures later.

Next, add the container registry and storage account:

```hcl
resource "azurerm_container_registry" "example" {
  name                = "${local.random_name}${random_string.example.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = {
    "anyscale-cloud" = local.random_name
  }
}

resource "azurerm_storage_account" "example" {
  name                            = "${local.random_name}${random_string.example.result}"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  is_hns_enabled                  = true
  default_to_oauth_authentication = true
  shared_access_key_enabled       = true

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["DELETE", "GET", "HEAD", "POST", "PUT"]
      allowed_origins    = ["https://*.anyscale.com"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = {
    "anyscale-cloud" = local.random_name
  }
}

resource "azurerm_storage_container" "example" {
  name                  = "anyscale-data"
  storage_account_id    = azurerm_storage_account.example.id
  container_access_type = "private"
}
```

A few things to note here. The storage account has `is_hns_enabled = true` because Anyscale uses Azure Data Lake Storage Gen2 (ADLS Gen2) for its cloud storage. HNS gives you hierarchical file system semantics on top of blob storage, which is what the `abfss://` URI scheme expects. The CORS rule allows the Anyscale web console to interact with the storage account directly from the browser.

## Step 3: Create the AKS cluster with Gateway API

This is where things get interesting. Instead of using the `azurerm_kubernetes_cluster` resource, we're using `azapi_resource` to create the AKS cluster. The managed Gateway API and Istio-based app routing features also [went GA recently](https://learn.microsoft.com/azure/aks/app-routing-gateway-api), but the ability to configure these features hasn't landed in the `azurerm` provider yet. So we use `azapi` to hit the AKS API directly. Add the following to your `main.tf`:

```hcl
resource "azapi_resource" "aks" {
  type      = "Microsoft.ContainerService/managedClusters@2026-03-02-preview"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  name      = "aks-${local.random_name}"

  schema_validation_enabled = false

  body = {
    identity = {
      type = "SystemAssigned"
    },
    properties = {
      dnsPrefix = "aks-${local.random_name}"
      agentPoolProfiles = [
        {
          name              = "systempool"
          mode              = "System"
          enableAutoScaling = true
          minCount          = 3
          maxCount          = 6
        }
      ]
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }
        webAppRouting = {
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
      oidcIssuerProfile = {
        enabled = true
      }
      securityProfile = {
        workloadIdentity = {
          enabled = true
        }
      }
    }
    sku = {
      name = "Base"
      tier = "Standard"
    }
  }

  response_export_values = [
    "properties.oidcIssuerProfile.issuerURL",
    "properties.identityProfile.kubeletidentity.objectId"
  ]
}
```

Let's break down the key parts of the `ingressProfile`:

- **`gatewayAPI.installation = "Standard"`** installs the Gateway API CRDs and controller on the cluster
- **`webAppRouting.gatewayAPIImplementations.appRoutingIstio.mode = "Enabled"`** enables the Istio-based implementation, which gives you the `approuting-istio` gateway class

We also enable OIDC issuer and workload identity on the cluster. These are required for the Anyscale operator to authenticate with Azure services using federated credentials instead of storing secrets.

The `response_export_values` block tells `azapi` to capture the OIDC issuer URL and the kubelet identity object ID from the cluster response, which we'll need for the federated credential and role assignments later.

## Step 4: Set up identity and role assignments

The Anyscale operator needs a managed identity with specific permissions to access resources on your behalf. We'll create a user-assigned managed identity, set up a federated credential so it can authenticate from within the cluster, and assign the necessary roles. Add the following to your `main.tf`:

```hcl
resource "azuread_service_principal" "example" {
  client_id    = "086bc555-6989-4362-ba30-fded273e432b" # Anyscale Kubernetes Operator Auth
  use_existing = true
}

resource "azurerm_user_assigned_identity" "example" {
  location            = azurerm_resource_group.example.location
  name                = "${local.random_name}-operator-identity"
  resource_group_name = azurerm_resource_group.example.name

  tags = {
    "anyscale-cloud" = local.random_name
  }
}

resource "azurerm_federated_identity_credential" "example" {
  name                      = azurerm_user_assigned_identity.example.name
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  user_assigned_identity_id = azurerm_user_assigned_identity.example.id
  subject                   = "system:serviceaccount:anyscale-operator:anyscale-operator"
}
```

The `azuread_service_principal` resource references the well-known Anyscale Kubernetes Operator Auth application in your tenant. The `use_existing = true` flag tells Terraform to look up the existing service principal rather than trying to create one. This is needed so the Anyscale operator can authenticate against your cluster.

The federated identity credential is the glue between the Kubernetes service account (`anyscale-operator` in the `anyscale-operator` namespace) and the Azure managed identity. When the operator pod starts, it can exchange its Kubernetes service account token for an Azure access token without needing any stored secrets.

Now add the role assignments:

```hcl
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "blob_data_owner" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr_push" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  role_definition_name             = "AcrPush"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr_task_contributor" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  role_definition_name             = "Container Registry Tasks Contributor"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}
```

Here's what each role does:

- **AcrPull** for the kubelet identity so the cluster can pull container images
- **Storage Blob Data Owner** for the operator identity to read/write data in the storage account
- **AcrPush** and **Container Registry Tasks Contributor** for the operator identity to push images and run ACR tasks

## Step 5: Register the Anyscale Cloud resources

Now we register the Anyscale Cloud and Cloud Resource using the `Anyscale.Platform` resource provider through `azapi`. These resources tell the Anyscale control plane about your Azure environment.

:::tip

You might be wondering how I figured out the resource type, API version, and payload structure for `Anyscale.Platform`. At the time of writing, this resource provider isn't documented in the [Azure resource reference](https://learn.microsoft.com/azure/templates/). That's pretty common with newly released services. The trick is to go through the quickstart workflow in the Azure portal, complete the setup wizard, and then export the ARM template from the resource group. The exported template shows you exactly what resource provider, API version, and properties ARM uses under the hood. From there, you can translate it into `azapi_resource` blocks in Terraform.

This is a useful technique to keep in your back pocket. Anytime a new Azure service launches and you want to automate it with Terraform before the `azurerm` provider catches up, the portal's template export gives you the schema you need.

:::

:::danger

Since Anyscale on Azure is in public preview, the `Anyscale.Platform` API is using a preview version (`2026-02-01-preview`). There's a good chance the API shape will change as the service moves toward general availability. If you're building on top of this, be prepared to update your Terraform configuration when new API versions are released.

:::

Add the following to your `main.tf`:

```hcl
resource "azapi_resource" "anyscale_cloud" {
  type      = "Anyscale.Platform/clouds@2026-02-01-preview"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  name      = local.random_name

  schema_validation_enabled = false

  body = {
    properties = {
      acrResourceId = azurerm_container_registry.example.id
    }
  }

  tags = {
    "anyscale-cloud" = local.random_name
  }

  response_export_values = [
    "properties.ssoUrl",
    "properties.cloudResourceId"
  ]

  depends_on = [
    azapi_resource.aks
  ]
}

resource "azapi_resource" "anyscale_cloud_resource" {
  type      = "Anyscale.Platform/clouds/cloudResources@2026-02-01-preview"
  parent_id = azapi_resource.anyscale_cloud.id
  location  = azurerm_resource_group.example.location
  name      = "default"

  schema_validation_enabled = false

  body = {
    properties = {
      provider                    = "Azure"
      computeStack                = "K8S"
      cloudStorageBucketEndpoint  = azurerm_storage_account.example.primary_blob_endpoint
      cloudStorageBucketName      = "abfss://${azurerm_storage_container.example.name}@${azurerm_storage_account.example.primary_dfs_host}"
      anyscaleOperatorIamIdentity = azurerm_user_assigned_identity.example.principal_id
    }
  }

  tags = {
    "anyscale-cloud" = local.random_name
  }

  response_export_values = [
    "properties.cloudResourceId"
  ]

  depends_on = [
    azapi_resource.aks
  ]
}
```

The `Anyscale.Platform/clouds` resource registers a new Anyscale "cloud" (their term for a connected infrastructure environment) and associates it with your container registry. The child `cloudResources` resource provides the details about compute (Kubernetes), storage (the ADLS Gen2 bucket), and the operator identity.

Notice the `cloudStorageBucketName` uses the `abfss://` URI format. This is the Azure Blob File System (ABFS) scheme that ADLS Gen2 uses, and it's how Anyscale accesses your storage.

## Step 6: Install the Anyscale operator extension

The Anyscale operator is deployed as an AKS cluster extension. This is where we wire up the gateway configuration. Add the following to your `main.tf`:

```hcl
resource "azurerm_kubernetes_cluster_extension" "anyscale_operator" {
  name           = "anyscaleoperator"
  cluster_id     = azapi_resource.aks.id
  extension_type = "Anyscale.AKS.Operator"
  release_train  = "stable"

  plan {
    name      = "anyscale-operator"
    product   = "anyscale-operator-aks"
    publisher = "anyscale1750870039553"
  }

  configuration_settings = {
    "global.auth.audience"          = "api://086bc555-6989-4362-ba30-fded273e432b/.default"
    "global.auth.iamIdentity"       = azurerm_user_assigned_identity.example.client_id
    "global.cloudDeploymentId"      = azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId
    "global.controlPlaneURL"        = "https://console.azure.anyscale.com"
    "workloads.serviceAccount.name" = "anyscale-operator"
    "networking.gateway.enabled"    = "true"
    "networking.gateway.name"       = "gateway"
    "networking.gateway.className"  = "approuting-istio"
    "networking.gateway.namespace"  = "anyscale-operator"
    "networking.gateway.apiVersion" = "gateway.networking.k8s.io/v1"
    "networking.gateway.hostname"   = "${replace(azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId, "_", "-")}.${azapi_resource.aks.location}.cloudapp.azure.com"
  }

  depends_on = [
    azurerm_federated_identity_credential.example
  ]
}
```

The key configuration settings to pay attention to:

- **`networking.gateway.className = "approuting-istio"`** tells the operator to use the AKS managed Istio gateway class
- **`networking.gateway.apiVersion = "gateway.networking.k8s.io/v1"`** ensures we're using the GA Gateway API spec
- **`networking.gateway.hostname`** constructs a DNS label that Azure will use to assign a public FQDN to the gateway's load balancer

The `plan` block references the Azure Marketplace listing for the Anyscale operator. This is how Azure knows what extension to install and which publisher it comes from.

We also need a role assignment so you can manage the Anyscale platform resources. Add this to your `main.tf`:

```hcl
resource "azurerm_role_assignment" "anyscale_platform_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Anyscale Platform Contributor Role"
  scope                = azapi_resource.anyscale_cloud.id
}
```

## Step 7: Outputs and the Gateway template

Before we deploy, we need two more things: Terraform output values so we can grab resource names after the deployment, and a template file for the Gateway manifest.

First, add the `local_file` resource to your `main.tf`. It takes a template (which we'll create next) and renders it into `anyscale-gateway.yaml` with the actual cloud resource ID:

```hcl
resource "local_file" "anyscale_gateway" {
  filename = "anyscale-gateway.yaml"
  content = templatefile("anyscale-gateway.tmpl",
    {
      ANYSCALE_CLOUD_RESOURCE_ID = replace(azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId, "_", "-")
    }
  )
}
```

Next, add the following outputs to your `main.tf`:

```hcl
output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azapi_resource.aks.name
}

output "anyscale_cloud_id" {
  value = split("/", azapi_resource.anyscale_cloud.output.properties.ssoUrl)[4]
}

output "anyscale_cloud_resource_id" {
  value = azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId
}
```

Finally, create a file named `anyscale-gateway.tmpl` in the same directory. Terraform uses this template to generate the Gateway manifest with your cloud resource ID injected:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway
  namespace: anyscale-operator
spec:
  gatewayClassName: approuting-istio
  infrastructure:
    annotations:
      service.beta.kubernetes.io/azure-dns-label-name: ${ANYSCALE_CLOUD_RESOURCE_ID}
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      port: 443
      protocol: HTTPS
      hostname: "*.i.azure.anyscaleuserdata.com"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: anyscale-${ANYSCALE_CLOUD_RESOURCE_ID}-certificate
      allowedRoutes:
        namespaces:
          from: Same
    - name: https-session
      port: 443
      protocol: HTTPS
      hostname: "*.s.azure.anyscaleuserdata.com"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: anyscale-${ANYSCALE_CLOUD_RESOURCE_ID}-certificate
      allowedRoutes:
        namespaces:
          from: Same
```

The Gateway defines three listeners: one for HTTP traffic and two for HTTPS. The HTTPS listeners handle Anyscale's interactive (`*.i.`) and session (`*.s.`) subdomains with TLS termination. The `azure-dns-label-name` annotation tells Azure to assign a public DNS label to the gateway's load balancer IP.

## Deploy it

With all the Terraform code in place, it's time to deploy. Sign in to Azure and set your subscription:

```bash
az login
az account set -s <subscription-id>
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

Initialize Terraform to download the providers:

```bash
terraform init
```

Then format and validate to make sure everything is clean:

```bash
terraform fmt
terraform validate
```

If validation passes, go ahead and apply:

```bash
terraform apply
```

Review the plan and type `yes` to proceed. The deployment takes about 7 minutes since it's creating an AKS cluster, installing the Anyscale operator extension, and registering the cloud resources.

Once it's done, grab the outputs and connect to the cluster:

```bash
read -r \
  RG_NAME \
  AKS_NAME \
  ANYSCALE_CLOUD_ID \
  ANYSCALE_CLOUD_RESOURCE_ID <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .anyscale_cloud_id.value,
      .anyscale_cloud_resource_id.value] | @tsv')"

az aks get-credentials -g $RG_NAME -n $AKS_NAME
```

Then deploy the gateway:

```bash
kubectl apply -f anyscale-gateway.yaml
```

## Verify the deployment

Check that the Anyscale operator and gateway-related pods are running:

```bash
kubectl get po -A
```

You should see pods in the `anyscale-operator` namespace for the operator itself, and Istio-related pods in the gateway infrastructure namespaces.

Now sign in to the Anyscale console. I installed the Anyscale CLI using [pipx](https://pipx.pypa.io/stable/), which I like because it installs Python CLI tools in isolated environments, similar to how `npx` works in the Node.js world. You get the tool without polluting your global Python packages.

```bash
pipx install anyscale
export ANYSCALE_HOST=https://console.azure.anyscale.com
anyscale login
```

Verify the cloud is registered and healthy:

```bash
anyscale cloud list
anyscale cloud verify --id $ANYSCALE_CLOUD_ID
```

The `cloud list` command should show your cloud with the `AZURE` provider and your region. The `cloud verify` command runs a series of checks against your cluster, including operator health, identity, and networking. You want to see all checks come back as `PASSED`.

From here, you can follow the [quickstart guide to run your first workload](https://learn.microsoft.com/azure/anyscale-on-azure/quickstart-azure-cli-gateway-envoy#run-your-first-workload). You can also open the Anyscale console directly from the Azure portal by navigating to your Anyscale resource and selecting the console link. That's where you can explore workspaces, submit jobs, and manage your Ray clusters.

## Cleanup

When you're done experimenting, tear everything down:

:::danger

If you have any running workspaces, make sure to terminate them first. You can do this from the Anyscale console UI or via the CLI:

```bash
anyscale workspace_v2 terminate --project default -n <workspace-name>
```

During the preview, if the Azure infrastructure is removed while workspaces are still running, those workspaces can end up in a state where they can't fully terminate, which prevents the Anyscale cloud from being deleted. This is expected to improve as the service works towards general availability.

:::

```bash
terraform destroy
```

Review the plan and type `yes` to confirm. This will remove all the resources, including the AKS cluster, Anyscale cloud registration, storage, and container registry.

## Summary

In this post, we walked through deploying Anyscale on Azure using Terraform with AKS managed Gateway API and Istio-based app routing. Along the way, we picked up a useful technique for figuring out API schemas when the docs haven't caught up yet, and saw how the `azapi` provider lets you automate new Azure services before the `azurerm` provider adds support.

The full Terraform code is available as a [GitHub Gist](https://gist.github.com/pauldotyu/4226b4d735f1903c7cb6a0f3d35bc655). Clone it, tweak the variables, and you should be up and running in under 10 minutes.

### What's next?

- Explore the [Anyscale on Azure documentation](https://learn.microsoft.com/azure/anyscale-on-azure/) for more configuration options
- Check out the [Ray documentation](https://docs.ray.io/) for building distributed applications
- Try scaling your Ray cluster with different node pool configurations and GPU-enabled VMs
- Look into [Anyscale workspaces](https://docs.anyscale.com/workspaces/get-started/) for interactive development on your cluster

Have questions or run into issues? Drop us a note in [GitHub Discussions](https://github.com/Azure/AKS/discussions) or open an [issue](https://github.com/Azure/AKS/issues/new).

Happy deploying!

## Resources

- [Full Terraform code for this walkthrough](https://gist.github.com/pauldotyu/4226b4d735f1903c7cb6a0f3d35bc655)
- [Anyscale on Azure public preview announcement](https://www.anyscale.com/blog/anyscale-on-azure-public-preview-build-and-deploy-ai-scale)
- [What is Anyscale on Azure?](https://learn.microsoft.com/azure/anyscale-on-azure/overview)
- [Quickstart: Deploy Anyscale on Azure](https://learn.microsoft.com/azure/anyscale-on-azure/quickstart-azure-cli-gateway-envoy)
- [AKS managed Gateway API](https://learn.microsoft.com/azure/aks/gateway-api)
- [Istio-based app routing with Gateway API on AKS](https://learn.microsoft.com/azure/aks/app-routing-gateway-api)
- [AzAPI Terraform provider](https://registry.terraform.io/providers/Azure/azapi/latest)
- [Ray documentation](https://docs.ray.io/)
