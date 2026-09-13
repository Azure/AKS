# Module 1: Check prerequisites

**Goal:** Confirm that your environment can create the cluster and allocate the
GPU used by this codelab.

**Time:** 5 minutes. This module creates no resources.

## Before you begin

You need:

- An Azure subscription where you can create resource groups and AKS clusters.
- Azure CLI, kubectl, and Helm.
- Quota for `Standard_NC4as_T4_v3` in the selected region.

The default region is `centralus`. Override any default before running a script:

```bash
export LAB_LOCATION=<region>
export LAB_GPU_SKU=<gpu-vm-size>
```

The supplied workload requests one GPU and is sized for a 16-GB T4. A different
SKU must provide at least one NVIDIA GPU with enough memory for
Qwen2.5-0.5B-Instruct.

## Run the preflight check

```bash
./scripts/00-preflight.sh
```

The script checks local tools, Azure sign-in, resource providers, SKU
restrictions, and available family quota. SKU availability and quota are
separate checks—a subscription can have quota for a family while a specific SKU
is restricted in that region.

## Checkpoint

Continue only after the script ends with:

```output
PASS  Preflight passed. Continue with modules/02-create-cluster.md.
```

## Troubleshoot

| Problem | Action |
|---|---|
| Azure CLI isn't signed in | Run `az login`, then `az account set --subscription <subscription-id>` |
| Resource provider isn't registered | Run the registration command printed by the script, then wait for `Registered` |
| SKU is restricted | Select another region or GPU SKU |
| Quota is insufficient | Request quota for the reported VM family or select a smaller SKU |

## Next step

Continue to [Module 2: Create the cluster](02-create-cluster.md).
