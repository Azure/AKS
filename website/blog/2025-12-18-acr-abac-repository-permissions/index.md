---
title: "Azure Container Registry Repository Permissions with Attribute-based Access Control (ABAC)"
date: "2025-12-18"
description: "Azure Container Registry now supports Microsoft Entra ABAC for granular repository permissions in CI/CD pipelines and AKS clusters for least-privilege access."
authors:
    - johnson-shi
tags:
    - azure-container-registry
    - entra
    - best-practices
    - general
    - operations
    - security
image: ./hero.png
hide_table_of_contents: false
draft: false
---

Enterprises are converging on centralized container registries that serve multiple business units and application domains. Azure role-based access control (RBAC) uses role assignments to control access to Azure resources. Each Azure RBAC role assignment specifies an identity (who will gain permissions), an Azure role with Entra actions and data actions (what permissions are granted), and an assignment scope (which resources). For ACR, traditional Azure RBAC scopes are limited to the subscription, resource group, or registry level—meaning permissions apply to all repositories within a registry.

In this shared registry model, traditional Azure role-based access control (RBAC) forces an all-or-nothing choice: either grant broad registry-wide permissions or manage separate registries per team. Neither approach aligns with least-privilege principles or modern zero trust architectures.

Microsoft Entra attribute-based access control (ABAC) for Azure Container Registry solves this challenge. ABAC augments Azure RBAC with fine-grained conditions, enabling platform teams to scope permissions precisely to specific repositories or namespaces within a shared registry. CI/CD pipelines and AKS clusters can now access only their authorized repositories, eliminating overprivileged access while maintaining operational simplicity.

![AKS cluster pulling from ACR with ABAC](./aks-cluster-pulling-from-acr-with-abac.png)

<!-- truncate -->

## How ABAC works in ACR

Attribute-based access control (ABAC) extends the traditional RBAC model by adding conditions to role assignments. While RBAC defines **who** (identity) can perform **what permissions** (Entra actions and data actions in a role definition) on **which resource scope** (subscription, resource group, or registry), ABAC adds a fourth dimension: **under what conditions will the permission be granted** (attributes). Conditions use attributes—such as repository name patterns—to further restrict when a role assignment grants access.

For ACR, this means that while the *scope* of a role assignment can be at the subscription, resource group, or registry level, ABAC *conditions* evaluate repository-level attributes like `repositories:name` to determine whether a specific permission (such as `repositories/content/read`) is permitted. This allows administrators to scope permissions to specific repositories or namespace prefixes within a single registry, without needing separate registries or overprivileged access.

ACR registries support a permissions mode called "**RBAC Registry + ABAC Repository Permissions**" that makes them ABAC-enabled. Once configured, registry administrators add ABAC conditions to standard Azure RBAC role assignments, scoping permissions to specific repositories or namespace prefixes. This enables:

* **CI/CD pipelines** to push images only to their approved namespaces and repositories
* **AKS clusters, Azure Container Apps, and Azure Container Instances** to pull only from authorized repositories
* **Microsoft Entra identities** to enforce permission boundaries through standard role assignments

## Enabling ABAC on ACR

By default, ACR registries use the "**RBAC Registry Permissions**" authorization mode, which provides traditional registry-scoped access control. ABAC can be enabled on all new and existing ACR registries across all SKUs by changing the authorization mode to "**RBAC Registry + ABAC Repository Permissions**", either during registry creation or configured on existing registries. You can assign RBAC roles with optional ABAC conditions to users, groups, service principals, and managed identities used by resources such as Azure Kubernetes Service (AKS), Azure Container Apps (ACA), and Azure Container Instances (ACI) when pulling images from ACR.

Here is the Azure Portal experience for enabling ABAC on a new ACR during creation:

![Enabling ABAC on a new ACR during creation](./acr-enabling-abac-during-acr-create.png)

Here is the Azure Portal experience for enabling ABAC on an existing ACR:

![Enabling ABAC on an existing ACR](./acr-enabling-abac-during-acr-update.png)

ABAC can also be enabled on ACR registries through Azure Resource Manager (ARM), Bicep files, Terraform templates, and Azure CLI.

## ABAC-enabled built-in roles

Once a registry is ABAC-enabled (configured to "**RBAC Registry + ABAC Repository Permissions**"), registry admins can use these ABAC-enabled built-in roles to grant repository-scoped permissions:

* **[Container Registry Repository Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#container-registry-repository-reader)**: grants image pull and metadata read permissions, including permissions for `HEAD` requests, `GET` manifest requests, `GET` layer blob requests, tag resolution, and discovering OCI referrers.
* **[Container Registry Repository Writer](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#container-registry-repository-writer)**: grants Repository Reader permissions, as well as image and tag push permissions.
* **[Container Registry Repository Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#container-registry-repository-contributor)**: grants Repository Reader and Repository Writer permissions, as well as image and tag delete permissions.

Note that these roles do not grant repository list permissions.

* The separate **[Container Registry Repository Catalog Lister](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#container-registry-repository-catalog-lister)** must be assigned to grant repository list permissions.
* The **[Container Registry Repository Catalog Lister](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/containers#container-registry-repository-catalog-lister)** role does not support ABAC conditions in role assignments; assigning this role grants permissions to list all repositories in a registry.

## Important role behavior changes in ABAC mode

:::caution
When a registry is ABAC-enabled by configuring its permissions mode to "**RBAC Registry + ABAC Repository Permissions**", existing built-in roles and role assignments will have different behaviors and will no longer grant the same set of permissions to ACR registries.
:::

* Legacy data-plane roles such as **AcrPull**, **AcrPush**, and **AcrDelete** are ***not honored in ABAC-enabled registries and should not be used***. For ABAC-enabled registries, use the ABAC-enabled built-in roles listed above.
* Broad roles like **Owner**, **Contributor**, and **Reader** previously granted full control plane and data plane permissions. This is typically an overprivileged role assignment. In ABAC-enabled registries, these broad roles will only grant control plane permissions to the registry. **Owner**, **Contributor**, and **Reader** will ***no longer grant data plane permissions***, such as image push, pull, delete or repository list permissions.
* In ABAC-enabled registries, ACR Tasks, Quick Tasks, Quick Builds, and Quick Runs no longer have default data plane access to source registries. This prevents inadvertent security leaks and broad permissions grants to ACR Tasks. To grant an ACR Task permissions to a source ACR registry, assign the ABAC-enabled roles above to the calling identity of the Task or Task Run as needed.

## Next steps

Start using ABAC repository permissions in ACR to enforce least-privilege artifact push, pull, and delete boundaries across your CI/CD systems and container image workloads. This model is now the *recommended approach* for multi-tenant platform engineering patterns to secure container registry deployments.

To get started, follow the step-by-step guides in the [official ACR ABAC documentation](https://aka.ms/acr/auth/abac).
