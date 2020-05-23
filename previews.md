# AKS Preview Features and Related Projects

> **WARNING:** Preview features are enabled at the Azure
subscription level. Do not install preview features on production subscription
as it can change default API behavior impacting regular operations.

## How to opt-in to a preview feature
For a given feature, there may be multiple early stages available in AKS
behind a user opt-in often referred to as a *feature flag*.

Most features and associated projects will eventually make
their way into AKS as an integrated feature of the managed service or supported as 1st class add-ons.

The purpose of this page is strictly educational on what preview features are in AKS and how to opt-in.

**Note**: AKS Preview features are self-service, opt-in. They are provided to
gather feedback and bugs from our community. Features in public preview receive 'best effort' support from Azure technical support. Preview features are not meant for
production and are supported by the AKS technical support teams during business
hours only. For additional information please see:

* [AKS Support Policies](https://docs.microsoft.com/en-us/azure/aks/support-policies)
* [Azure Support FAQ](https://azure.microsoft.com/en-us/support/faq/)

## Getting Started

### Install Azure CLI
In order to use / opt into preview features via command line, you will need to install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).

### Install aks-preview module
In addition to the core installation, you will need to install the `aks-preview` module to use preview features and ensure it is up to date with the latest release.
You can install the `aks-preview` extension by running:

```
az extension add --name aks-preview
```

**Warning**: Installing the preview extension will update the CLI to use the
**latest** extensions and properties. Please do not enable this for production
clusters & subscriptions.

In order to uninstall the extension, run:

```
az extension remove --name aks-preview
```

### Register specific features
To use AKS preview features, first enable a feature flag on your subscription. To register a feature flag, use the [az feature register][az-feature-register] command as shown in the following example:

```
az feature register --name <INSERT_FEATURE_NAME> --namespace Microsoft.ContainerService
```

Next, refresh the registration of the *Microsoft.ContainerService* resource provider using the `az provider register` command:

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

## Preview features

Reference the [AKS project roadmap](https://github.com/Azure/AKS/projects/1#column-5273286) for a list of features currently in preview. Each feature issue will have links to related technical documentation.

## Associated projects

> **NOTE:** The following projects have been validated to work with
recent AKS clusters, but **they are not** officially supported by Azure technical
support. If you run into issues with a given project, file issues in the corresponding GitHub
project. These must be manually installed by the user from the below open source projects. Read more on [support for open source projects from Azure](https://github.com/Azure/container-compute-upstream/blob/master/README.md#support).

Reference the [Azure Compute Upstream list of projects](https://github.com/Azure/container-compute-upstream/blob/master/README.md#project-list) for a list of associated projects which can be self-installed on to an AKS cluster.
