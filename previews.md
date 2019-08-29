# AKS Preview Features and Related Projects

**Please be aware, enabling preview features takes effect at the Azure
subscription level. Do not install preview features on production subscription
as it can change default API behavior impacting regular operations.**

At any given time, there can be multiple early stage features available in AKS
behind a *feature flag*, along with a set of related projects available
elsewhere on GitHub that you may wish deploy manually on the service.

In most cases, these features and associated projects will eventually make
their way into AKS, or at least be supported as 1st class extensions. But
before they get there, we need sufficient usage from early adopters to validate
their usefulness and quality.

The purpose of this page is to capture these features and associated projects
in a single place.

**Note**: AKS Preview features are self-service, opt-in. They are provided to
gather feedback and bugs from our community. Features in public preview are fall
under 'best effort' support as these features are in preview and not meant for
production and are supported by the AKS technical support teams during business
hours only. For additional information please see:

* [AKS Support Policies](https://docs.microsoft.com/en-us/azure/aks/support-policies)
* [Azure Support FAQ](https://azure.microsoft.com/en-us/support/faq/)

## Getting Started

In order to use / opt into preview features, you will need to use the
[Azure CLI][7] and ensure it is up to date with the latest release. Once that
is complete, you must install the `aks-preview` extension via:

```
az extension add --name aks-preview
```

**Warning**: Installing the preview extension will update the CLI to use the
**latest** extensions and properties. Please do not enable this for production
clusters & subscriptions. In order to uninstall the extension,
you can do the following:

```
az extension remove --name aks-preview
```

## Preview features

* [Availability Zones](#zones)
* [Standard Load Balancers](#standard-load-balancers)
* [Windows Worker Nodes](#windows)
* [Locked down cluster egress](#egress)
* [Multiple Node Pools](#nodepools)
* [Secure access to the API server using authorized IP address ranges](#apideny)
* [Virtual Machine Scale Sets (VMSS) / Cluster Autoscaler](#vmss)
* [Kubernetes Audit Log](#noauditforu)
* [Kubernetes Pod Security Policies](#psp)

### Availability zones <a name="zones"></a>

This feature enables customers to distribute their AKS clusters across
availability zones providing a higher level of availability.

Getting started:
* [AKS availability zones documentation](https://aka.ms/aks/zones)
* [About availability zones on Azure](https://docs.microsoft.com/en-us/azure/availability-zones/az-overview)
* [Swagger reference (2019-06-01)](https://github.com/Azure/azure-rest-api-specs/blob/master/specification/containerservice/resource-manager/Microsoft.ContainerService/stable/2019-06-01/managedClusters.json#L1399)

### Standard Load Balancers

This has been a long awaited feature which enables selection of the SKU type
offered by Azure Load Balancer to be used with your AKS cluster, a full table
of comparisons between the two is linked below.

This is a create time property that can be set on new clusters created with the
2019-06-01 API and forward. Support is available via preview CLI module as well
which is captured in below documentation.

* [Basic vs Standard Load Balancers](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview#skus)
* [Using Azure SLB with AKS](https://docs.microsoft.com/en-us/azure/aks/load-balancer-standard)
* [AKS API Definition](https://github.com/Azure/azure-rest-api-specs/blob/master/specification/containerservice/resource-manager/Microsoft.ContainerService/stable/2019-06-01/managedClusters.json#L1585)

Behavioral differences and deployment instructions are outlined in the official
documentation below.

### Windows worker nodes <a name="windows"></a>

This preview feature allows customers to add Windows Server node to their
clusters for use with common Windows or .NET workloads. Please note that
this feature will enabled multiple node pools as a dependency, and AKS clusters
will always contains a Linux node pool as the first node pool. This first
Linux-based node pool can't be deleted unless the AKS cluster itself is deleted.

Please see the [documentation][8] for additional information including setup
and known limitations.

```
az feature register -n WindowsPreview --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

### Locked down cluster egress <a name="egress"></a>

By default, AKS clusters have unrestricted outbound (egress) internet access.
This level of network access allows nodes and services you run to access
external resources as needed. If you wish to restrict egress traffic, a
limited number of ports and addresses must be accessible to maintain healthy
cluster maintenance tasks.

```
az feature register -n AKSLockingDownEgressPreview --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

### Multiple Node Pools  <a name="nodepools"></a>

Multiple Node Pool support is now in public preview. You can see the
[preview documentation][nodepool] for instructions and limitations.

```
az feature register -n MultiAgentpoolPreview --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

### Secure access to the API server using authorized IP address ranges  <a name="apideny"></a>

This feature allows users to restrict what IP addresses have access to the
Kubernetes API endpoint for clusters. Please see details and limitations
in the [preview documentation][api server].

You can opt into the preview by registering the feature flag:

```
az feature register -n APIServerSecurityPreview --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

### Virtual Machine Scale Sets (VMSS) / Cluster Autoscaler <a name="vmss"></a>

[Azure virtual machine scale sets][6] let you create and manage a group of
identical, load balanced VMs. VMSS usage is commonly used in conjunction with
the [cluster autoscaler][5]. Both of these are in active preview and can be
used today.

You can opt into the preview by registering the feature flag:

```
az feature register -n VMSSPreview --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

To create a VMSS backed cluster run:

```bash

az aks create -n <CLUSTER_NAME> -g <CLUSTER_RG> --vm-set-type VirtualMachineScaleSets

```

### Kubernetes Audit Log <a name="noauditforu"></a>

The [Kubernetes audit log][3] provides a detailed account of security-relevant
events that have occurred in the cluster.

Kubernetes audit log support is GA, the documentation for enabling it
on AKS clusters is here: https://docs.microsoft.com/en-us/azure/aks/view-master-logs

## Kubernetes Pod Security Policies <a name="psp"></a>

To improve the security of your AKS cluster, you can limit what pods can be
scheduled. Pods that request resources you don't allow can't run in the AKS
cluster. You define this access using [pod security policies][9].

First, register the feature flag:

```
az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```


## Associated projects

Please note that while the following projects have been validated to work with
recent AKS clusters, they are not yet officially supported by Azure technical
support. If you run into issues, please file them in the corresponding GitHub
repository.

### AAD Pod Identity

The AAD Pod Identity project enables you to provide Azure identities to pods
running in your Kubernetes cluster. This allows individual applications running
in Kubernetes to have their own rights to interact with Azure resources and to
easily authentication tokens representing those rights, avoiding the need to
share a single identity across the cluster or inject applications with service
principals.

http://github.com/azure/aad-pod-identity.

### KeyVault FlexVol

The KeyVault FlexVol project enables Kubernetes pods to mount Azure KeyVault
stores as flex volumes, providing access to application-specific secrets, keys,
and certs natively within Kubernetes.

https://github.com/Azure/kubernetes-keyvault-flexvol

### Azure Application Gateway Ingress Controller

The App Gateway ingress controller enables the use of the
[Azure Application Gateway service][1] as a layer 7 load balancer in front of
Kubernetes services, providing a fully managed alternative to running something
like Nginx directly inside the cluster.

https://github.com/Azure/application-gateway-kubernetes-ingress

[1]: https://azure.microsoft.com/services/application-gateway/
[2]: https://docs.microsoft.com/azure/aks/view-master-logs
[3]: https://kubernetes.io/docs/tasks/debug-application-cluster/audit/
[4]: https://kubernetes.io/docs/concepts/services-networking/network-policies/
[5]: https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
[6]: https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview
[7]: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
[8]: https://docs.microsoft.com/en-us/azure/aks/windows-container-cli
[9]: https://docs.microsoft.com/en-us/azure/aks/use-pod-security-policies

[api server]: https://docs.microsoft.com/en-us/azure/aks/api-server-authorized-ip-ranges
[nodepool]: https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools
