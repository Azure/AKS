# Azure Kubernetes Service Changelog

## Releases

### Release 01-31-19

* [Kubernetes 1.12.4 GA Release][1]
  * With the release of 1.12.4 *Kubernetes 1.8 support has been removed*, you will need to upgrade to at least 1.9.x
* CoreDNS support GA release
  * Conversion from kube-dns to CoreDNS completed, CoreDNS is the default for all new 1.12.4+ AKS clusters.
  * If you are using configmaps or other tools for kube-dns modifications, you will need to be adjust them to be CoreDNS compatible.
    * The CoreDNS add-on is set to `reconcile` which means modifications to the deployments will be discarded.
    * We have identified two issues with this release that will be resolved in a hot fix begining rollout this week:
      * https://github.com/Azure/AKS/issues/811 (kube-dns onfig map not compatible with CoreDNS)
      * https://github.com/Azure/AKS/issues/812 (kube-dns/coreDNS autoscaler conflicts)
* Kube-dns (pre 1.12) / CoreDNS (1.12+) autoscaler(s) are enabled by default, this should resolve the DNS timeout and other issues related to DNS queries overloading kube-dns.
  * In order to get the dns-autoscaler, you must perform an **AKS cluster upgrade** to a later supported release (clusters prior to 1.12 will continue to get kube-dns, with kube-dns autoscale)
* Users may now self update/rotate Security Principal credentials using the [Azure CLI][6]
* Additional non-user facing stability and reliability service enhancements
* **New Features in Preview**
  * **Note**: Features in preview are considered beta/non-production ready and unsupported. Please do not enable these features on production AKS clusters.
  * [Cluster Autoscaler / Virtual machine Scale Sets][2]
  * [Kubernetes Audit Log][3]
  * Network Policies/Network Security Policies
    * This means you can now use `calico` as a valid entry in addition to `azure` when creating clusters using Advanced Networking
    * There is a known issue when using Network Policies/calico that prevents `exec` into the cluster containers which will be fixed in the next release
  * For all product / feature previews including related projects, see [this document][5].

[1]: https://docs.microsoft.com/azure/aks/supported-kubernetes-versions
[2]: https://docs.microsoft.com/azure/aks/cluster-autoscaler#create-an-aks-cluster-and-enable-the-cluster-autoscaler
[3]: https://github.com/Azure/AKS/blob/master/previews.md#kubernetes-audit-log
[5]: https://github.com/Azure/AKS/blob/master/previews.md
[6]: https://docs.microsoft.com/azure/aks/update-credentials
