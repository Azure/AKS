# Simple Istio app deployment on Azure AKS

This bash script will mirror the Bookinfo app guide available on [Istio's site](https://istio.io/docs/guides/bookinfo/).

For this script to work you must have:

- An Azure account with a valid subscription
- [Azure cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed on your path
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed on your path
- [Helm](https://docs.helm.sh/using_helm/#installing-helm) installed on your path

Before running the script you have to populate the variables defined at the beginning (AZURE_SUBSCRIPTION_ID, LOCATION, etc).

This script was tested on:
- azure-cli (v2.0.42)
- kubectl (v1.9.9)
- helm (v2.9.1.)
- istio (v0.8.0)

