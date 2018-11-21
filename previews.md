# AKS Preview Features and Related Projects

At any given time, there can be multiple early stage features available in AKS behind a *feature flag*, along with a set of related projects available elsewhere on GitHub that you may wish deploy manually on the service. 

In most cases, these features and associated projects will eventually make their way into AKS, or at least be supported as 1st class extensions. But before they get there, we need sufficient usage from early adopters to validate their usefulness and quality.

The purpose of this page is to capture these features and associated projects in a single place.

## Preview features

### Moby as AKS container runtime

Currently, AKS supports a fairly old version of the Docker engine (v1.13). Due to licensing restrictions introduced with the release of Docker CE, we plan to adopt Moby (the OSS project that Docker is built from) as the container runtime in AKS.

To switch to Moby for your subscription, turn on the feature flag as follows:

```
az feature register --name MobyImage --namespace Microsoft.ContainerService
```

Then refresh your registration of the AKS resource provider:

```
az provider register -n Microsoft.ContainerService
```

Now, when you create a new cluster or scale/upgrade an existing one, you will get a Moby image containing Docker API version 1.38 instead of Docker engine.

## Associated projects

Please note that while the following projects have been validated to work with recent AKS clusters, they are not yet officially supported by Azure CSS. If you run into issues, please file them in the corresponding GitHub repo.

### AAD Pod Identity

The AAD Pod Identity project enables you to provide Azure identities to pods running in your Kubernetes cluster. This allows individual applications running in Kubernetes to have their own rights to interact with Azure resources and to easily authentication tokens representing those rights, avoiding the need to share a single identity across the cluster or inject applications with service principals.

http://github.com/azure/aad-pod-identity. 

### KeyVault FlexVol

The KeyVault FlexVol project enables Kubernetes pods to mount Azure KeyVault stores as flex volumes, providing access to application-specific secrets, keys, and certs natively within Kubernetes. 

https://github.com/Azure/kubernetes-keyvault-flexvol 

### Azure Application Gateway Ingress Controller

The App Gateway ingress controller enables the use of the [Azure Application Gateway service](https://azure.microsoft.com/services/application-gateway/) as a layer 7 load balancer in front of Kubernetes services, providing a fully managed alternative to running something like Nginx directly inside the cluster.

https://github.com/Azure/application-gateway-kubernetes-ingress