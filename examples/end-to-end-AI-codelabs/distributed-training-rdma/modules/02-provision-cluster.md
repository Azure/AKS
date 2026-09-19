# Module 2: Provision the cluster

**Goal:** put two RDMA GPU VMs in the same AKS node-pool VMSS and verify its
placement boundary. **Time:** 20–35 minutes.

Run:

```bash
./scripts/10-create-cluster.sh
```

The script performs these operations in order:

1. Registers `Microsoft.ContainerService/AKSInfinibandSupport` and waits for
   `Registered`. This asks AKS to place the pool on one physical InfiniBand
   fabric.
2. Creates a Kubernetes 1.35 AKS cluster with non-overlapping `10.0.0.0/16`
   service and `10.244.0.0/16` pod CIDRs. Azure reserves `172.16.0.0/16` for
   its RDMA network.
3. Creates one **two-node** RDMA GPU pool. Do not split the peers across pools:
   different pools are different VM scale sets and therefore isolation
   boundaries.
4. Finds the generated VMSS and fails unless `singlePlacementGroup=true`.

The default uses the AKS-managed NVIDIA driver. Module 3 installs the device
plugin and loads `nvidia-peermem`; it does not replace the AKS-managed driver.

## Checkpoint

Two `rdmagpu` nodes are `Ready`, have the same SKU, and the script prints:

```text
PASS  Both RDMA nodes are in one single-placement-group VMSS
```

## Troubleshooting

- **AllocationFailed:** quota is not capacity. Retry later or choose another
  region with entitlement and quota.
- **Feature registration permission denied:** a subscription owner must register
  `AKSInfinibandSupport`.
- **One node only:** don't continue. Cross-node validation requires two Ready
  nodes in the same pool.
- **CIDR overlap:** retain the lab CIDRs or choose ranges that do not overlap
  Azure's `172.16.0.0/16` RDMA space.

**Next:** [Enable RDMA and GPUDirect](03-enable-rdma.md).
