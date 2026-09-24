# Module 1: Check prerequisites

**Goal:** prove that your subscription can create two RDMA GPU nodes before
creating billable resources. **Time:** about 5 minutes.

## Requirements

- Azure CLI, `kubectl`, Helm 3, `jq`, and Python 3.
- Permission to create resource groups, AKS clusters, node pools, and feature
  registrations.
- An exact RDMA-capable GPU SKU. The `r` in an ND-series name denotes RDMA, but
  the script also requires the Azure `RdmaEnabled=True` capability.
- Quota for two nodes. The default A100 pool requires 192 family vCPUs.

Select the subscription and run preflight:

```bash
export LAB_SUBSCRIPTION=<subscription-id>
./scripts/00-preflight.sh
```

The check uses `az vm list-skus` without `--all`, so a SKU hidden by a
subscription restriction does not pass merely because quota exists. It then
checks both family quota and total regional vCPU quota.

## Checkpoint

The final line is:

```text
PASS  Preflight passed. Continue with modules/02-provision-cluster.md.
```

## Troubleshooting

- **SKU unavailable:** choose a region returned by `az vm list-skus`, or request
  subscription access. `az vm list-usage` alone is not proof of entitlement.
- **Quota shortfall:** request at least two times the SKU's vCPU count.
- **Feature not registered:** this is informational at preflight; the next
  script registers `AKSInfinibandSupport` and waits for propagation.
- **Capacity:** there is no capacity preflight API. `AllocationFailed` can still
  occur later even after entitlement and quota pass.

**Next:** [Provision the cluster](02-provision-cluster.md).
