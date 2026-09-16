# Module 3: Create the GPU pool

**Goal:** Create an autoscaling GPU node pool with no running nodes.

**Time:** About 5 minutes. No GPU is billed while the pool remains at zero.

## Create the pool

```bash
./scripts/20-create-gpu-pool.sh
```

The pool has these important settings:

- `min-count: 0` starts and returns to zero GPU nodes.
- `max-count: 1` limits cost during the codelab.
- `sku=gpu:NoSchedule` keeps general workloads off the GPU.
- `workload=gpu-inference` selects nodes for the NVIDIA device plugin.
- `nvidia.com/gpu.present=true` satisfies the plugin chart's GPU discovery affinity without requiring Node Feature Discovery.
- `agentpool=gpupool`, added by AKS, binds the Kueue ResourceFlavor to this pool.

This is a conventional GPU pool. AKS installs the NVIDIA driver, and Module 4
installs the device plugin that advertises `nvidia.com/gpu` to Kubernetes.

## Checkpoint

```bash
. ./scripts/lib.sh
az aks nodepool show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  --name "$LAB_GPU_POOL" \
  --query '{count:count,min:minCount,max:maxCount,autoscaling:enableAutoScaling}'
```

Expected values:

```json
{
  "autoscaling": true,
  "count": 0,
  "max": 1,
  "min": 0
}
```

## Troubleshoot

| Problem | Action |
|---|---|
| `AllocationFailed` | The region has no capacity for the selected GPU SKU; select another region or retry later |
| Pool starts with one node | Run `az aks nodepool scale ... --node-count 0` before submitting the workload |
| `--min-count 0` is rejected | Confirm the pool uses `--mode User` and cluster autoscaler is enabled |

## Next step

Continue to [Module 4: Install the controllers](04-install-controllers.md).
