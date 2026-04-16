---
title: "Securing Argo CD with Microsoft Entra ID: A Step-by-Step Guide"
date: 2026-04-17
description: "Learn how to secure the Argo CD extension for AKS with Microsoft Entra ID using Terraform, workload identity, OIDC, RBAC, and policy-based access control."
authors: [paul-yu]
tags: [argo-cd, entra, extensions, security, best-practices]
---

A few weeks ago at KubeCon Europe 2026, the [public preview of Argo CD extension for AKS was announced](https://techcommunity.microsoft.com/blog/azurearcblog/announcing-public-preview-of-argo-cd-extension-on-aks-and-azure-arc-enabled-kube/4504497). In this post, we will walk through how to deploy Argo CD via AKS extension and configure it to use Microsoft Entra ID using Terraform.

<!-- truncate -->

## Overview

By now, [Argo CD](https://argo-cd.readthedocs.io/en/stable/) probably needs no introduction. But if you are new to Argo CD, it is a declarative, GitOps continuous delivery tool for Kubernetes. It allows you to manage your Kubernetes applications using Git repositories as the source of truth.

Argo CD is heavily used in production environments and many have already adopted the open-source version of Argo CD. With the new Argo CD extension for AKS, you can now easily deploy the software on your cluster as an Azure-native resource. But what does that mean? Well, for one, it means you can now leverage Azure CLI, Azure Resource Manager (ARM) templates, Bicep, or Terraform to manage your Argo CD deployments as you bootstrap clusters. It also means that Azure can be in charge of the lifecycle of your Argo CD deployment, including upgrades and security patches. This is a huge win for users who want to focus on their applications and not worry about managing the underlying infrastructure.

By default, the Argo CD installation comes with a built-in admin user. However, for production environments, it is recommended to use an external identity provider for authentication and authorization. Microsoft Entra ID is a great choice for this as it provides robust security features and seamless integration with Azure services. My motto has always been "ditch the passwords" and using Microsoft Entra ID for authentication allows you to do just that. You can leverage features like multi-factor authentication (MFA), conditional access policies, and role-based access control (RBAC) to secure your Argo CD deployment.

At a high level, the process of securing Argo CD with Microsoft Entra ID involves the following steps:

1. Create a Microsoft Entra ID application for Argo CD
2. Create OIDC configuration settings to connect Microsoft Entra ID and enable workload identity for Argo CD
3. Create policy mappings to grant Microsoft Entra ID users/groups access to Argo CD
4. Create an AKS cluster with OIDC issuer and workload identity enabled
5. Deploy the Argo CD extension for AKS
6. Verify the integration

There's a lot of "setup goo" to go through, especially when it comes to configuring Microsoft Entra ID applications and OIDC settings, but don't worry, we'll automate all of that using Terraform and I'll go through each step in detail. The end result will be a secure Argo CD deployment that is integrated with Microsoft Entra ID for authentication and authorization.

## Step 0: Prerequisites

Before you get started, make sure you have the following prerequisites in place:

- [Azure subscription](https://aka.ms/azure-free-account)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Argo CD CLI (optional)](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

Within your Azure tenant/subscription, you will also need to have the necessary permissions to create Microsoft Entra ID applications and manage Azure resources.

Unless you are the Global Administrator in your tenant, you will need to have one of the following roles to be able to create Microsoft Entra ID applications:

- [Application Administrator](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#application-administrator)
- [Application Developer](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#application-developer)
- [Cloud Application Administrator](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#cloud-application-administrator)

## Step 1: Terraform provider setup

Create a new directory for your Terraform configuration and navigate to it and create a new file named `main.tf`.

In this file, we will define the Terraform providers for [Azure Resource Manager (azurerm)](https://registry.terraform.io/providers/hashicorp/azurerm/latest) and [Microsoft Entra ID (azuread)](https://registry.terraform.io/providers/hashicorp/azuread/latest). The `azurerm` provider will allow us to manage Azure resources, while the `azuread` provider will allow us to manage Microsoft Entra ID applications and related resources.

```hcl
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.69.0"
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

## Step 2: Create Microsoft Entra ID application for Argo CD

Next, let's create some data sources to query Microsoft Entra ID for the necessary information to set up our application and OIDC configuration. Add the following code to your `main.tf` file to get a list of well-known application IDs, the current client's configuration, and the service principal for Microsoft Graph.

```hcl
data "azuread_application_published_app_ids" "well_known" {}
data "azuread_client_config" "current" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}
```

Since the OIDC configuration for Argo CD requires the IDs of specific Microsoft Graph scopes, we will also create a local variable named `msgraph_scopes` that includes all the scopes from the Microsoft Graph service principal. This will allow us to easily reference the scope IDs when we create our Microsoft Entra ID application for Argo CD.

Add the following code to your `main.tf` file to create the `msgraph_scopes` local variable:

```hcl
locals {
  msgraph_scopes = { for s in data.azuread_service_principal.msgraph.oauth2_permission_scopes : s.value => s }
}
```

Now we are ready to create our Microsoft Entra ID application for Argo CD. This application will represent your Argo CD in Microsoft Entra ID and will be used for authentication and authorization.

Add the following code to your `main.tf` file to create the application:

```hcl
resource "azuread_application" "example" {
  display_name            = "myargocdapp"
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["ApplicationGroup"]

  web {
    redirect_uris = [
      "https://localhost:9000/auth/callback"
    ]
  }

  public_client {
    redirect_uris = [
      "http://localhost:8085/auth/callback"
    ]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = local.msgraph_scopes["openid"].id
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_scopes["profile"].id
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_scopes["email"].id
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_scopes["User.Read"].id
      type = "Scope"
    }
  }

  optional_claims {
    id_token {
      name      = "groups"
      essential = true
    }
  }
}
```

Here's what each part of the application configuration does:

- **`sign_in_audience = "AzureADMyOrg"`** — restricts sign-in to users in your Microsoft Entra ID tenant only
- **`group_membership_claims = ["ApplicationGroup"]`** — includes group membership in the token, which we'll use later for RBAC role mapping
- **`web` and `public_client` redirect URIs** — required for the OIDC authentication flow with Argo CD (the `web` URI is for the browser-based flow, and the `public_client` URI is for the CLI). Since we're testing locally, we use localhost URIs here, but for production you'll want to update these to match your deployment
- **`required_resource_access`** — requests Microsoft Graph API permissions (`openid`, `profile`, `email`, and `User.Read`) needed for the OIDC flow and to retrieve user information
- **`optional_claims`** — includes the user's group memberships in the ID token, enabling group-based access control in Argo CD

The workload identity integration requires Argo CD to exchange its Kubernetes service account token for a Microsoft Entra ID token, so we will need to create a federated identity credential for the application to establish trust between Microsoft Entra ID and the cluster's OIDC issuer.

Add the following code to your `main.tf` file to create the federated identity credential for the application:

```hcl
resource "azuread_application_federated_identity_credential" "example" {
  application_id = azuread_application.example.id
  display_name   = azuread_application.example.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject        = "system:serviceaccount:argocd:argocd-server"
}
```

Next, we need to create a service principal for the application. The service principal is what will be used to grant permissions and access to resources in Azure.

```hcl
resource "azuread_service_principal" "example" {
  client_id = azuread_application.example.client_id
}
```

Now we need to grant the service principal the necessary permissions to access Microsoft Graph on behalf of the user. Add the following code to your `main.tf` file to create the delegated permission grant:

```hcl
resource "azuread_service_principal_delegated_permission_grant" "example" {
  service_principal_object_id          = azuread_service_principal.example.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "User.Read"]
}
```

:::info

The permission grant is optional. Without it, users will be asked to consent to the permissions. By creating this permission grant, we are pre-consenting on behalf of the users in our tenant so that they won't see the consent prompt when they sign in to Argo CD.

:::

With the service principal and permissions in place, we can now grant Microsoft Entra ID users and groups access to Argo CD by creating app role assignments. Add the following code to your `main.tf` file to retrieve a Microsoft Entra ID group object ID.

```hcl
data "azuread_group" "example" {
  display_name = "Argo CD Admins" # Update this to match your group name
}
```

:::info

You might already have an existing group in Microsoft Entra ID that you want to use for Argo CD access. If so, update the `display_name` in the `azuread_group` data source above to match the name of your group. If not, create a new group in Microsoft Entra ID and add your user accounts to that group and then update the `display_name` accordingly.

:::

Finally, add the following code to your `main.tf` file to allow members of the Microsoft Entra ID group to have access to the Argo CD application.

```hcl
resource "azuread_app_role_assignment" "example" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = data.azuread_group.example.object_id
  resource_object_id  = azuread_service_principal.example.object_id
}
```

## Step 3: Create AKS cluster

Now comes the easy part, creating the AKS cluster 😎

Add the following code to your `main.tf` file to create a resource group:

```hcl
resource "azurerm_resource_group" "example" {
  name     = "myresourcegroup"
  location = "westus3" # Update to your preferred region
}
```

Add the following code to your `main.tf` file to create an AKS cluster with OIDC issuer and workload identity enabled:

```hcl
resource "azurerm_kubernetes_cluster" "example" {
  name                      = "myakscluster"
  location                  = azurerm_resource_group.example.location
  resource_group_name       = azurerm_resource_group.example.name
  dns_prefix                = "myakscluster"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 1
  }

  identity {
    type = "SystemAssigned"
  }
}
```

:::warning

Enabling the OIDC issuer and workload identity on the AKS cluster is crucial for the integration with Microsoft Entra ID as it allows the cluster to issue OIDC tokens that Argo CD pods can use to exchange with Microsoft Entra ID for authentication and authorization.

:::

## Step 4: Deploy Argo CD extension for AKS

Okay, the moment we've all been waiting for, deploying the Argo CD extension for AKS!

Before we can deploy the extension, we need to create the necessary configuration settings for the OIDC integration with Microsoft Entra ID. This includes the OIDC configuration and the RBAC policy mappings.

Add the following code to your `main.tf` file to create more local variables for the OIDC configuration and RBAC policy mappings:

```hcl
locals {
  oidc_config = <<EOT
name: Microsoft Entra ID
issuer: https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0
clientID: ${azuread_application.example.client_id}
azure:
  useWorkloadIdentity: true
requestedIDTokenClaims:
  groups:
    essential: true
requestedScopes:
  - openid
  - profile
  - email
EOT

  policy_csv = <<EOT
g, "${data.azuread_group.example.object_id}", role:admin
EOT
}
```

This OIDC configuration specifies the issuer URL for Microsoft Entra ID, the client ID of our application, and the requested scopes and claims. The RBAC policy mapping specifies that members of the Microsoft Entra ID group we referenced earlier will be assigned the "admin" role in Argo CD.

With the configuration settings in place, we can now deploy the Argo CD extension for AKS. The nice thing here is that even though the Argo CD extension is in public preview, we can deploy it using the `azurerm_kubernetes_cluster_extension` resource in Terraform since the underlying call to Azure Resource Manager does not require any special handling for preview extensions.

Add the following code to your `main.tf` file to deploy the Argo CD extension for AKS:

```hcl
resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name           = "argocd"
  cluster_id     = azurerm_kubernetes_cluster.example.id
  extension_type = "Microsoft.ArgoCD"
  release_train  = "Preview"

  configuration_settings = {
    "azure.workloadIdentity.enabled"          = "true"
    "azure.workloadIdentity.clientId"         = azuread_application.example.client_id
    "azure.workloadIdentity.entraSSOClientId" = azuread_application.example.client_id
    "redis-ha.enabled"                        = "false"
    "global.domain"                           = "localhost:9000"
    "configs.cm.admin\\.enabled"              = "false"
    "configs.cm.oidc\\.config"                = local.oidc_config
    "configs.rbac.policy\\.csv"               = local.policy_csv
  }
}
```

:::info

This extension is primarily based on the [open-source Argo CD Helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd), so the configuration settings follow a similar pattern to Helm values with some Azure-specific additions. Here's a quick breakdown:

- **`azure.workloadIdentity.*`** — convenience settings that wire up the workload identity integration for you
- **`configs.cm.admin.enabled = "false"`** — disables the built-in admin user since we're using Microsoft Entra ID
- **`global.domain = "localhost:9000"`** — sets the domain Argo CD uses for redirect URLs (update this for production)
- **`configs.cm.oidc.config`** and **`configs.rbac.policy.csv`** — the OIDC and RBAC settings we defined earlier

:::

You might be asking, what about the version of the Argo CD extension? Since this extension is managed by Azure, we can omit the version and let Azure deploy the latest version and automatically upgrade it when new versions are available. This is one of the benefits of using an Azure-managed extension as it reduces the operational overhead of managing the extension and ensures that you are always running a secure and up-to-date version.

## Step 5: Run Terraform and verify

We're nearly there! The last step is to add some output values to our `main.tf` file so that we can easily retrieve the resource group name and AKS cluster name after the deployment. Then we'll run `terraform init` and `terraform apply` to create all the resources. Once the deployment is complete, we can retrieve the credentials for our AKS cluster and verify that we can sign in to Argo CD using Microsoft Entra ID.

Add the following code to your `main.tf` file to create the output values:

```hcl
output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.example.name
}
```

Open a terminal, navigate to the directory containing your `main.tf` file, and run the following commands:

```bash
terraform init
terraform apply
```

The `terraform init` command will initialize the Terraform working directory and download the necessary providers, while the `terraform apply` command will create all the resources defined in your `main.tf` file. Review the plan output and type `yes` to proceed with the deployment.

Once the deployment is complete, run the following command to retrieve the credentials for your AKS cluster:

```bash
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
```

Now that we have the credentials for our AKS cluster, we can verify that we can sign in to Argo CD using Microsoft Entra ID. Since we set the `global.domain` to `localhost:9000`, we will need to port-forward the Argo CD server to access it locally. Run the following command to port-forward the Argo CD server:

```bash
kubectl port-forward svc/argocd-server -n argocd 9000:443
```

Open a web browser and navigate to [https://localhost:9000](https://localhost:9000). You should be presented with a warning about an untrusted certificate. This is expected since we're using a self-signed certificate for local testing. Proceed past the warning to see the Argo CD sign-in page. Select the **Log in via Microsoft Entra ID** button and single sign-on (SSO) should kick in.

Navigate to the "User Info" page and you should see your Microsoft Entra ID user information along with the group claims.

If you have the Argo CD CLI installed, you can also verify the sign-in and view user information from the command line as well.

Keep the port-forwarding session running and open a new terminal window, then run the following command to sign in to Argo CD using SSO:

```bash
argocd login localhost:9000 --sso --insecure
```

You should see a browser window open to complete the authentication flow. After you sign in, you can run the following command to view your user information:

```bash
argocd account get-user-info
```

You will see the same user information and group claims as you saw in the web UI, confirming that the OIDC integration with Microsoft Entra ID is working correctly.

Congratulations! You have successfully secured Argo CD with Microsoft Entra ID for authentication and authorization. You can now manage your Kubernetes applications using Argo CD with the confidence that your deployment is secure and integrated with Azure services.

:::tip Going to production?

This walkthrough uses localhost URLs for local testing. Before deploying to production, make sure to:

- Update the `web` redirect URI in the Entra ID app registration and `global.domain` in the extension config to your real domain
- Set up an Ingress controller with a valid TLS certificate
- Consider adding granular RBAC roles beyond `role:admin` (for example, `role:readonly` for dev teams)
- Review the [Argo CD RBAC documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/) for fine-grained policy options

:::

## Cleanup

When you're done experimenting, you can tear down all the resources created in this walkthrough by running:

```bash
terraform destroy
```

Review the plan output and type `yes` to confirm. This will remove the AKS cluster, Argo CD extension, Microsoft Entra ID application, and all related resources.

## Summary

In this post, we walked through how to secure Argo CD with Microsoft Entra ID for authentication and authorization. We covered the steps to create a Microsoft Entra ID application for Argo CD, configure OIDC settings, create RBAC policy mappings, deploy the Argo CD extension for AKS, and verify the integration. By leveraging Microsoft Entra ID, you can enhance the security of your Argo CD deployment and take advantage of Azure's identity and access management features.

### What's next?

- Expose Argo CD with an Ingress controller and a real TLS certificate
- Deploy a sample GitOps application through Argo CD to see it in action
- Add granular RBAC roles for different teams in your organization
- Explore the [Argo CD extension docs](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd) for more tutorials

Tried this out? We'd love to hear how it went — drop us feedback in [GitHub Discussions](https://github.com/Azure/AKS/discussions) or open an [issue](https://github.com/Azure/AKS/issues/new) if you run into anything.

Happy deploying!

## Resources

- [Full Terraform code for this walkthrough](https://gist.github.com/pauldotyu/8d54d73300669efa1296e56f13e9e27d)
- [Announcing public preview of Argo CD extension on AKS and Azure Arc-enabled Kubernetes - Microsoft Tech Community](https://techcommunity.microsoft.com/blog/azurearcblog/announcing-public-preview-of-argo-cd-extension-on-aks-and-azure-arc-enabled-kube/4504497)
- [Argo CD documentation](https://argo-cd.readthedocs.io/en/stable/)
- [Argo CD Microsoft Entra ID integration](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/)
- [Argo CD RBAC documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [Workload identity for AKS](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Terraform on Azure](https://learn.microsoft.com/azure/developer/terraform/overview)
