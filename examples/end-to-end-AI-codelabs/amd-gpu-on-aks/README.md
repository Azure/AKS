# AMD GPU on AKS

Create an AKS cluster with an AMD `MI300X` GPU node pool, install the AMD GPU
Operator to build and deploy the driver, then explore Dynamic Resource
Allocation (DRA) to share a single GPU between multiple Pods.

## Prerequisites

- Azure subscription with `az login` completed, and permission to create AKS
  clusters and an Azure Container Registry.
- Azure CLI ≥ 2.85.0.
- kubectl and Helm 3 installed.
- [`Standard_ND96isr_MI300X_v5`](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/ndmi300xv5-series)
  quota in this subscription.

## Steps

| # | Step | What you do |
|---|---|---|
| 1 | [Install the GPU driver and device plugin](0-install-gpu-driver-and-device-plugin.md) | Create the AKS cluster and GPU node pool, then install the AMD GPU Operator and run a sample workload |
| 2 | [DRA for the AMD GPU](1-dra-driver-for-amd-gpu.md) | Switch from the device plugin to DRA and share a single GPU between two Pods |

## Clean up

The last section of [1-dra-driver-for-amd-gpu.md](1-dra-driver-for-amd-gpu.md#clean-up)
deletes the AKS cluster and the ACR resource created in step 1.
