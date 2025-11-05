---
title: "Azure Container Registry Repository Permissions with Attribute-based Access Control (ABAC)"
date: "2025-11-24"
description: Azure Container Registry now supports Entra ABAC conditions in RBAC role assignments. This enables identities from CI/CD pipelines and AKS clusters to have granular image push, pull, or delete permissions for specific repositories and namespaces.
authors:
    - johnson-shi
tags:
    - azure-container-registry
    - entra
    - best-practices
    - general
    - operations
    - security
    - workload-identity
image: ./hero.png
hide_table_of_contents: false
draft: false
---

Learn how to secure and configure Azure Container Registry (ACR) repository permissions with Microsoft Entra attribute-based access control (ABAC) — now generally available (GA) for all new and existing ACR registries, across all SKUs, and in all Azure regions.

In ACR, ABAC augments the familiar Azure RBAC model with namespace and repository-level conditions. This enables platform teams to grant least-privilege access at the granularity of specific repositories or entire logical namespaces. This capability is designed for modern multi-tenant platform engineering patterns, where a central container registry serves many business domains. With ABAC, Entra identities belonging to CI/CD systems and Azure Kubernetes Service (AKS) clusters can have least-privilege access to ACR registries.

![AKS cluster pulling from ACR with ABAC](./aks-cluster-pulling-from-acr-with-abac.png)

<!-- truncate -->

## Why this matters for granular permissions

Enterprises are converging on a central container registry pattern that hosts artifacts and container images for multiple business units and application domains. In this model:

* CI/CD pipelines from different parts of the business push container images and artifacts only to approved namespaces and repositories within a central registry.
* AKS clusters, Azure Container Apps (ACA), Azure Container Instances (ACI), and consumers pull only from authorized repositories within a central registry.

With ABAC, these repository and namespace permission boundaries become explicit and enforceable using standard Microsoft Entra identities and role assignments. This aligns with cloud-native zero trust, supply chain hardening, and least-privilege permissions.

## What ABAC in ACR means

ACR registries now support a registry permissions mode called "**RBAC Registry + ABAC Repository Permissions.**" Configuring a registry to this mode makes it ABAC-enabled.

* When a registry is configured to be ABAC-enabled, registry administrators can optionally add ABAC conditions during standard Azure RBAC role assignments.
* This optional ABAC conditions scope the role assignment’s effect to specific repositories or namespace prefixes.

## Enabling ABAC on ACR

ABAC can be enabled on all new and existing ACR registries across all SKUs, either during registry creation or configured on existing registries.

Here is the Azure Portal experience for enabling ABAC on a new ACR during creation:

![Enabling ABAC on a new ACR during Creation](./acr-enabling-abac-during-acr-create.png)

Here is the Azure Portal experience for enabling ABAC on an existing ACR:

![Enabling ABAC on an existing ACR](./acr-enabling-abac-during-acr-update.png)

ABAC can also be enabled on ACR registries through Azure Resource Manager (ARM), Bicep files, Terraform templates, and Azure CLI.

## Identities you can assign

ACR ABAC uses standard Microsoft Entra role assignments. Assign RBAC roles with optional ABAC conditions to users, groups, service principals, and managed identities, including AKS kubelet and workload identities, ACA and ACI identities, and more.

## ABAC-enabled built-in roles

Once a registry is ABAC-enabled (configured to "**RBAC Registry + ABAC Repository Permissions**"), registry admins can use these ABAC-enabled built-in roles to grant repository-scoped permissions:

* **Container Registry Repository Reader**: grants image pull and metadata read permissions, including permissions for `HEAD` requests, `GET` manifest requests, `GET` layer blob requests, tag resolution, and discovering OCI referrers.
* **Container Registry Repository Writer**: grants Repository Reader permissions, as well as image and tag push permissions.
* **Container Registry Repository Contributor**: grants Repository Reader and Repository Writer permissions, as well as image and tag delete permissions.

Note that these roles do not grant repository list permissions.

* The separate **Container Registry Repository Catalog Lister** must be assigned to grant repository list permissions.
* The **Container Registry Repository Catalog Lister** role does not support ABAC conditions in role assignments; assigning this role grants permissions to list all repositories in a registry.

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
