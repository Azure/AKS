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
gather feedback and bugs from our community. However, they are not supported by
Azure technical support and adding these to existing clusters will render the
clusters as unsupported until the feature exits preview and graduate to general
availability. If you encounter issues with preview features, please file issues
on this GitHub repo with the name of the preview feature in the bug title.

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

### Multiple Availability Zones (Multi-Az)

To provide a higher level of availability to your applications, AKS clusters
can be distributed across availability zones. These zones are physically
separate data centers within a given region. When the cluster components are
distributed across multiple zones, your AKS cluster is able to tolerate a
failure in one of those zones. Your applications and management operations
continue to be available even if one entire data center has a problem.

You can opt-into the Multi-AZ functionality by installing (see above) the
AKS preview extension for the Azure CLI and performing a cluster create command
with `--node-zones`:

```
az aks create ... --node-zones (Allowed values: 1 2 3)
```

Where `--node-zones` is a space-separated list of availability zones where
agent nodes will be placed.

### Virtual Machine Scale Sets (VMSS) / Cluster Autoscaler

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

To create a cluster with VMSS enabled, use the `--enable-vmss` switch in `az aks create`.


### Kubernetes Network Policy

[Network policy][4] enables network segmentation of a Kubernetes cluster.
Network policy uses a plugin model, with different providers implementing the
core Kubernetes API. In AKS, we offer two plugins: a native `azure` solution
and the open-source `calico` project.

You can opt into the preview by registering the feature flag:

```
az feature register -n EnableNetworkPolicy --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

To create a cluster with network policy enabled, use the `--network-policy`
switch in `az aks create` and specify the network policy plugin you would like
to use, `azure` or `calico`. Note that both require the `azure` network plugin.

### Kubernetes Audit Log

The [Kubernetes audit log][3] provides a detailed account of security-relevant
events that have occurred in the cluster. You can enable it for your
subscription by turning on the **AKSAuditLog** feature flag.

First, register the feature flag:

```
az feature register --name AKSAuditLog --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

Once you've done this, you will see a new **kube-audit** log source in the
diagnostic settings for your cluster, as described in [this doc][2].

**Please note:** AKS will only capture audit logs for clusters which are
 created or upgraded after the feature flag is enabled.

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
