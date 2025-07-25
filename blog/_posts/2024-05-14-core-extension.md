---
title: "Introducing Core Kubernetes Extensions for AKS"
description: "Learn what core Kubernetes extensions are, and how they can extend the functionality of your AKS clusters"
date: 2025-05-14 # date is important. future dates will not be published
author: Jane Guo # must match the authors.yml in the _data folder
categories: 
- add-ons-and-extensions
# - general
# - operations
# - networking
# - security
# - developer
# - add-ons-and-extensions
---

## Introducing Core Kubernetes Extensions

### What are Kubernetes Extensions?

[Kubernetes extensions](https://learn.microsoft.com/azure/aks/cluster-extensions?tabs=azure-cli) (or cluster extensions) are pre-packaged applications that simplify the installation and lifecycle management of Azure capabilities on Kubernetes clusters. Examples include [Azure Backup](https://learn.microsoft.com/azure/backup/azure-kubernetes-service-backup-overview), [GitOps (Flux)](https://learn.microsoft.com/azure/azure-arc/kubernetes/conceptual-gitops-flux2), and [Azure Machine Learning](https://learn.microsoft.com/azure/machine-learning/how-to-attach-kubernetes-anywhere?view=azureml-api-2). Third-party extensions (or Kubernetes apps), such as [Datadog AKS Cluster Extension](https://azuremarketplace.microsoft.com/marketplace/apps/datadog1591740804488.dd_aks_extension?tab=Overview) and [Isovalent Cilium Enterprise](https://azuremarketplace.microsoft.com/marketplace/apps/isovalentinc1662143158090.isovalent-cilium-enterprise?tab=Overview), are also available in the [Azure Marketplace](https://azuremarketplace.microsoft.com).

### Extensions vs. Add-ons

Extensions and add-ons both enhance AKS functionality but differ in scope and management:

- **Add-ons**: Part of the AKS [resource provider](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types) (`Microsoft.ContainerService/managedClusters`), limited to AKS, and generally reserved for cluster critical functionality. These are configured directly via the Managed Cluster API.
- **Extensions**: Managed via the [Extension API](https://learn.microsoft.com/rest/api/kubernetesconfiguration/extensions/extensions?view=rest-kubernetesconfiguration-extensions-2024-11-01) (`Microsoft.KubernetesConfiguration/extensions`), supporting both AKS and [Arc-enabled Kubernetes environments](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/overview). Learn how extensions also work on Azure Arc-enabled clusters at [extension architecture](https://learn.microsoft.com/azure/azure-arc/kubernetes/conceptual-extensions#architecture).

### What are Core Kubernetes Extensions?

A Core Kubernetes extension is a Kubernetes extension that provide broader region availability, a native AKS experience, safer version management, and enhanced security, efficiency, and reliability on AKS. Important AKS capabilities can be supported through core Kubernetes extensions while maintaining seamless integration with AKS just like add-ons. Going forward, some important AKS capabilities will be offered via core extensions rather than via Addons as has been done in the past. This approach also paves the way for more functionality to be supported across both AKS and Azure Arc-enabled Kubernetes environments in the future. 

#### Broader region availability
Core Kubernetes extensions are available in all regions across Azure Public cloud, Azure Government and China regions. See the full list of regions at [Product availability by region](https://azure.microsoft.com/explore/global-infrastructure/products-by-region/table) (search "Azure Arc enabled Kubernetes" for core Kubernetes extensions and "Azure Kubernetes Service (AKS)" for AKS in the list).

#### Native AKS experience
##### Creating and deleting core extensions
* **Unchanged experience for core extensions migrated from add-ons**: Some AKS add-ons, such as [Container Insights](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview), [Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-metrics-overview), and [Application Monitoring](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless), are transitioning to core extensions. Although the underlying technology shifts to extensions, the API and the user experience in Azure CLI, Azure Portal and ARM/Bicep/Terraform/other templates remain unchanged.

    CLI commands:

    ```bash
    az aks create/update --resource-group <group> --name <cluster> --enable/disable-<add-on>
    ```
* **More native experience for core extensions graduated from [standard extensions](https://learn.microsoft.com/azure/aks/cluster-extensions#currently-available-extensions)**: Currently, we are working on upgrading Azure Backup, which is key functionality, to core extensions for better integrated experience in AKS. More core extensions will come in the future.

    CLI commands:
    * Create/delete a **standard** extension:
    ```bash
    az k8s-extension create/delete --extension-type <type> --resource-group <group> --cluster-name <name> --cluster-type <clusterType> --name <extension name>
    ```
    * Create/delete a **core** extension:
    ```bash
    az aks extension create/delete --extension-type <type> --resource-group <group> --cluster-name <name> --name <core extension name>
    ```

#### Safer version management
Core extensions follow the same [update rules as add-ons](https://learn.microsoft.com/azure/aks/integrations#add-ons): patch versions can be upgraded within a Kubernetes minor version, while major/minor upgrades occur only with Kubernetes minor version updates to avoid introducing breaking changes within a Kubernetes minor version. This policy balances reliability with the speed of availability of new features and patches.

#### Improved security, efficiency and reliability

Extension-manager is moved from user node pool to AKS Control Plane, which improves extension security, efficiency, and reliability.

What Is extension-manager?

Extension-manager is a key component that handles lifecycle operations (create, upgrade, delete, reconcile) for Kubernetes extensions. It periodically polls for version updates on extension instances and reconciles extension configuration settings, ensuring that extensions are managed effectively. Learn more about the flow in [extension architecture](https://learn.microsoft.com/azure/azure-arc/kubernetes/conceptual-extensions#architecture). 

Previously, extension-manager pods (extension-operator and extension-agent) were deployed in the kube-system namespace on customer worker nodes. Example of a deployment before:
```bash
$ kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
coredns-558bd4d5db-7x5c8                  1/1     Running   0          5d
extension-agent-abc123                    1/1     Running   0          3d
extension-operator-def456                 1/1     Running   0          3d
```

What Has Changed?

Extension-manager components are now moved to the AKS control plane hosted on Microsoft tenant and subscriptions. Extension-manager is no longer visible to users.

Benefits of the Move
1. **Reduced Identity Footprint:** Eliminates the need for node-level identities for extension-manager, improving security and reducing setup time. This also contributes to shortening the first extension installation time.
1. **Reduced resource usage**. Moving the extension-manager pods to AKS internal infrastructure will reduce the resource usage on the customer's side.
1. **Improved extension integrity:** Prevents accidental interference with extension components, safeguarding extension integrity.
1. **Simplified Networking:** Reduces the need for complex networking configurations. Before the migration, users need to set up required networking rules as outlined in [Required FQDN / application rules](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress#required-fqdn--application-rules-5) for extension-manager. Extension-manager now communicates directly with the following endpoints from AKS Control Plane, removing the need for users to configure them. Note that some extensions may still require users to configure networking for the extension instances on the users' clusters (e.g., allowing access to MCR for pulling container images).
    * `<region>.dp.kubernetesconfiguration.azure.com`
    * `mcr.microsoft.com`, `*.data.mcr.microsoft.com`
    * `arcmktplaceprod.azurecr.io` and `arcmktplaceprod.<region>.data.azurecr.io`

## Which applications or services will be supported through core Kubernetes extensions?
We're in the process of enabling Container insights, Managed prometheus, App monitoring, and Azure Backup through core extensions, and there will be more. Keep an eye out for more updates, and share your feedback with us!

