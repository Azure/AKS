# Module 2: Create the cluster

**Goal:** Create an AKS cluster with a CPU-only system node pool.

**Time:** About 15 minutes.

## Create AKS

```bash
./scripts/10-create-cluster.sh
```

The script creates:

- resource group `aks-kueue-inference-lab`;
- AKS cluster `aks-kueue-inference` running Kubernetes 1.35;
- two `Standard_D4s_v5` system nodes.

It then downloads credentials and selects the new kubeconfig context.

GPU nodes aren't created yet. Keeping system services on CPU nodes lets the GPU
pool scale to zero without disrupting the control components used by the lab.

## Checkpoint

```bash
kubectl get nodes -L agentpool
kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}'
```

Expect two Ready nodes in the `system` pool. The second command should return no
GPU capacity.

## Troubleshoot

| Problem | Action |
|---|---|
| Kubernetes version isn't available | Set `LAB_KUBERNETES_VERSION` to a supported version that is 1.33 or later |
| Cluster creation reports quota limits | Change `LAB_SYSTEM_SKU` or request regional vCPU quota |
| kubectl connects to another cluster | Rerun `./scripts/10-create-cluster.sh`; it overwrites the current credentials |

## Next step

Continue to [Module 3: Create the GPU pool](03-create-gpu-pool.md).
