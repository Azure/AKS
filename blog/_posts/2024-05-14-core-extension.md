---
title: "Introducing Core Kubernetes Extensions for AKS"
description: "Learn what are core Kubernetes extensions, and how that extends functionality of your AKS clusters"
date: 2025-05-14 # date is important. future dates will not be published
author: Jane Guo # must match the authors.yml in the _data folder
categories: 
- extensions 
# - general
# - operations
# - networking
# - security
# - developer
# - add-ons
# - extensions
---

## Introducing Core Kubernetes Extensions

### What Are Kubernetes Extensions?

[Kubernetes extensions](https://learn.microsoft.com/en-us/azure/aks/cluster-extensions?tabs=azure-cli) (or cluster extensions) are pre-packaged applications that simplify the installation and lifecycle management of Azure capabilities on Kubernetes clusters. Examples include [Azure Backup](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-backup-overview), [GitOps (Flux)](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2), and [Azure Machine Learning](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-attach-kubernetes-anywhere?view=azureml-api-2). Third-party extensions (or Kubernetes apps), such as [Datadog AKS Cluster Extension](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/datadog1591740804488.dd_aks_extension?tab=Overview) and [Isovalent Cilium Enterprise](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/isovalentinc1662143158090.isovalent-cilium-enterprise?tab=Overview), are also available in the Azure Marketplace.

### Extensions vs. Add-ons

Extensions and add-ons both enhance AKS functionality but differ in scope and management:

- **Add-ons**: Part of the AKS resource provider (`Microsoft.ContainerService/managedClusters`), limited to AKS.
- **Extensions**: Managed via the Extension API (`Microsoft.KubernetesConfiguration/extensions`), supporting both AKS and Arc-enabled Kubernetes environments.

### What Are Core Kubernetes Extensions?

 Compared to regular Kubernetes extensions, core Kubernetes extensions provide a native AKS experience, with the goal of supporting important AKS capabilities through Kubernetes extensions while maintaining seamless integration just like add-ons. This approach also paves the way for more services and applications to be supported across both AKS and [Arc-connected Kubernetes](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/overview) environments in the future.

#### Transitioning Add-ons to Core Extensions

Some AKS add-ons, such as Container Insights, Azure Managed Prometheus, and App Monitoring, are transitioning to core extensions. The user experience remains unchanged, but the underlying technology shifts to extensions.

CLI command to enable a core Extension that transitioned from an add-on:
```bash
az aks create/update --resource-group <group> --name <cluster> --enable-<core-extension>
```
#### Upgrading Regular Extensions to Core Extensions
Key extensions like Azure Backup are being upgraded to core extensions for better integration with AKS.

CLI commands:
* Create a regular extension:
```bash
az k8s-extension create --extension-type <type> --resource-group <group> --cluster-name <name> --cluster-type <clusterType> --name <extension name>
```
* Create a core extension:
```bash
az aks extension create --extension-type <type> --resource-group <group> --cluster-name <name> --name <core extension name>
```
Note, core extensions follow the same update rules as add-ons: patch versions can be upgraded within a Kubernetes minor version, while major/minor upgrades occur only with Kubernetes minor version updates.

## Other recent Updates for Kubernetes Extensions
### Expanded Region and Cloud Support
Kubernetes extensions are now available in more regions across public, fairfax, mooncake, and air-gapped clouds. See the full list at [Azure Arc enabled Kubernetes region support](https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/?products=azure-arc&regions=all).

### ExtensionManager Moved to AKS Control Plane
#### What Is ExtensionManager?
ExtensionManager is a key component that handles lifecycle operations (create, upgrade, delete, reconcile) for Kubernetes extensions. It periodically polls for version updates on extension instances and reconciles extension configuration settings, ensuring that extensions are managed effectively. Previously running on customer worker nodes, it has now been moved to the AKS control plane.

#### What Has Changed?
Previously, extension-operator and extension-agent were deployed in the kube-system namespace by ExtensionManager on worker nodes. These components are now part of the AKS control plane, so they are no longer visible in the kube-system namespace.

Example of previous deployment:
```bash
$ kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
coredns-558bd4d5db-7x5c8                  1/1     Running   0          5d
extension-agent-abc123                    1/1     Running   0          3d
extension-operator-def456                 1/1     Running   0          3d
```
#### Benefits of the Move
1. **Improved extension integrity:** Prevents accidental interference with extension components, safeguarding extension integrity.
1. **Simplified Networking:** Reduces the need for complex networking configurations (as outlined in [Required FQDN / application rules](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress#required-fqdn--application-rules-5)) for ExtensionManager. You only need to configure networking for the extensions themselves (e.g., allowing access to MCR for pulling container images).
1. **Reduced Identity Footprint:** Eliminates the need for node-level identities for ExtensionManager, improving security and reducing setup time. This also contributes to shortening the first extension installation time.
1. **Reduced pod footprint and resource usage**. Moving the two pods - extension-operator and extension-agent - to AKS internal infrastructure will reduce the resource usage on the customer's side.

## Summary
More AKS functionality will be available through core Kubernetes extensions. Keep an eye out for more updates, and share your feedback with us!

