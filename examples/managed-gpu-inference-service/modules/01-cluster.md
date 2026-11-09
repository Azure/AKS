# Module 1: Create the cluster

Create an AKS cluster with a CPU-only system node pool. GPU capacity is added
separately in Module 2 so you can remove the expensive nodes without removing
the cluster.

## Create the cluster

```bash
./scripts/10-create-cluster.sh
```

The script:

1. Creates a dedicated resource group with an ownership tag.
2. Creates two `Standard_D4s_v5` system nodes.
3. Enables the Azure Blob Container Storage Interface (CSI) driver.
4. Writes the cluster credentials to your kubeconfig.
5. Selects the new cluster as the active `kubectl` context.

The ownership tag prevents cleanup from deleting a resource group that this
example did not create.

## Checkpoint

```bash
kubectl get nodes -l agentpool=system
az aks show \
  --resource-group "${LAB_RESOURCE_GROUP:-aks-managed-gpu-inference}" \
  --name "${LAB_CLUSTER:-aks-managed-gpu-inference}" \
  --query 'storageProfile.blobCsiDriver.enabled'
```

Expect two `Ready` system nodes and `true` for the Blob CSI driver.

No node should advertise GPU capacity yet:

```bash
kubectl get nodes \
  -o custom-columns='NODE:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

The GPU column should be empty.

## Troubleshoot

| Problem | Action |
| --- | --- |
| The resource group already exists without the ownership tag | Set a different `LAB_RESOURCE_GROUP` |
| Cluster creation reports quota limits | Resolve the system VM family or total regional virtual CPU quota reported by preflight |
| `kubectl` points to another cluster | Rerun `./scripts/10-create-cluster.sh` |
| Blob CSI reports `false` | Wait for the cluster operation to finish, then inspect `az aks show` and rerun the script |

## Next step

[Module 2: Create the managed GPU pool](02-managed-gpu-nodepool.md)
