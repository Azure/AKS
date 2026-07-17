# Module 1 — Infrastructure

Provision an AKS cluster with an **autoscaling** node pool and install the Kueue
controller. This is the foundation the queue configuration (Module 2) and
workload (Module 3) build on.

## What gets created

- An AKS cluster.
- A user node pool named `scalepool` with the cluster autoscaler enabled
  (`--enable-cluster-autoscaler --min-count 1 --max-count 5`). Kueue's
  ProvisioningRequest AdmissionCheck grows this pool on demand.
- The Kueue controller, installed via Helm.

## Provision the cluster

```bash
RG=kueue-cas-demo
LOCATION=eastus2
CLUSTER=kueue-cas

az group create --name $RG --location $LOCATION

az aks create \
  --resource-group $RG \
  --name $CLUSTER \
  --node-count 1 \
  --generate-ssh-keys

az aks nodepool add \
  --resource-group $RG \
  --cluster-name $CLUSTER \
  --name scalepool \
  --node-count 1 \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5 \
  --node-vm-size Standard_D4s_v3
```

> [!IMPORTANT]
> The ProvisioningRequest path requires the cluster autoscaler to run with
> `--enable-provisioning-requests`. On AKS this is gated behind a preview
> capability — if `kubectl -n cas-demo get provisioningrequest` shows no
> `status.conditions` after a few minutes, the autoscaler is not consuming
> ProvisioningRequests on your cluster. See
> [Cluster autoscaler overview](https://learn.microsoft.com/azure/aks/cluster-autoscaler-overview)
> for the current availability of this capability.

## Get credentials

```bash
az aks get-credentials --resource-group $RG --name $CLUSTER
```

## Install Kueue

```bash
helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
  --version 0.14.2 \
  --namespace kueue-system \
  --create-namespace \
  --wait
```

Verify the controller is running:

```bash
kubectl -n kueue-system get pods
```

## Next

Continue to [Module 2 — Kueue Queues](../2-kueue-queues/).
