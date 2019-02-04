# Azure Kubernetes Service Changelog

## Releases

### Release 01-31-19

* [Kubernetes 1.12.4 GA Release][7]
  * With the release of 1.12.4 *Kubernetes 1.8 support has been removed*, you will need to upgrade to at least 1.9.x
* CoreDNS support GA release
  * Conversion from kube-dns to CoreDNS completed, CoreDNS is the default for all new AKS clusters.
  * If you are using configmaps or other tools for kube-dns modifications, you will need to be modify them to be CoreDNS compatible.
* Network Security Policies are now GA
  * This means you can not use `calico` as a valid entry when creating clusters using Advanced Networking
* Users may now self update/rotate Security Principal credentials using the [Azure CLI]
* Additional non-user facing stability and reliability service enhancements

*Features Released to Preview*

*Note*: Features in preview are considered beta/non-production ready and unsupported. Please do not enable these features on production AKS clusters.

* [Cluster Autoscaler / Virtual machine Scale Sets][5]
* [Kubernetes Audit Log][1]
* [AAD Pod Identity][2]
* [KeyVault FlexVol][3]
* [Azure Application Gateway Ingress Controller][4]


[1]: https://github.com/Azure/AKS/blob/master/previews.md#kubernetes-audit-log
[2]: https://github.com/Azure/AKS/blob/master/previews.md#aad-pod-identity
[3]: https://github.com/Azure/AKS/blob/master/previews.md#keyvault-flexvol
[4]: https://github.com/Azure/AKS/blob/master/previews.md#azure-application-gateway-ingress-controller
[5]: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler#create-an-aks-cluster-and-enable-the-cluster-autoscaler
[6]: https://docs.microsoft.com/en-us/azure/aks/update-credentials
[7]: https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions