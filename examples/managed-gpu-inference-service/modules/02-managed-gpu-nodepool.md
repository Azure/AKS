# Module 2: Create the managed GPU pool

> [!IMPORTANT]
> Fully managed GPU nodes are a preview feature and aren't intended for
> production use. Preview CLI flags and API fields can change before general
> availability.

Add two A100 nodes with the AKS-managed NVIDIA stack.

## Create the pool

```bash
./scripts/20-create-managed-gpu-pool.sh
```

The script creates a Linux user node pool with:

- Two `Standard_NC24ads_A100_v4` nodes.
- `--enable-managed-gpu=true`.
- The `sku=gpu:NoSchedule` taint.
- A managed operating system disk.

With managed GPU enabled, AKS installs and maintains the NVIDIA driver,
Kubernetes device plugin, Data Center GPU Manager (DCGM) exporter, and GPU
health integration described in the
[managed GPU documentation](https://learn.microsoft.com/azure/aks/aks-managed-gpu-nodes).

The taint keeps general workloads off the GPU nodes. Every GPU workload in this
example includes the matching toleration.

## Understand the immutable profile

AKS stores the configuration under `gpuProfile`. The driver, management mode,
and Multi-Instance GPU strategy cannot be changed after pool creation. To
change them, create another node pool.

The script validates an existing pool before reusing it. It stops if the VM
size, node count, operating system, taint, or managed GPU profile differs from
the expected configuration.

Managed GPU node pools do not support cluster autoscaler during preview. This
example uses a fixed two-node pool and removes it during cleanup.

## Checkpoint

```bash
az aks nodepool show \
  --resource-group "${LAB_RESOURCE_GROUP:-aks-managed-gpu-inference}" \
  --cluster-name "${LAB_CLUSTER:-aks-managed-gpu-inference}" \
  --name a100np \
  --query '{count:count,vmSize:vmSize,osType:osType,gpuProfile:gpuProfile,tags:tags}'
```

Expect:

- `count` is `2`.
- `vmSize` is `Standard_NC24ads_A100_v4`.
- `osType` is `Linux`.
- `gpuProfile.nvidia.managementMode` is `Managed`.
- `tags.aks-example` is `managed-gpu-inference-service`.

## Troubleshoot

| Problem | Action |
| --- | --- |
| `AllocationFailed` | The region has no capacity for the VM size; try another region where preflight passes |
| `InsufficientVCPUQuota` | Request quota for the A100 family or total regional virtual CPUs |
| An existing pool does not match | Delete the example-owned pool and rerun the script |
| `gpuProfile.nvidia` is `null` | Recreate the pool with `--enable-managed-gpu=true` |

## Next step

[Module 3: Verify GPU access](03-verify.md)
