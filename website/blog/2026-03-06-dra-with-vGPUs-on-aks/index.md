---
title: "DRA with NVIDIA virtualized GPU on AKS"
date: "2026-03-06"
description: "Configure dynamic resource allocation (DRA) for NVIDIA vGPU workloads and learn the prerequisites with setup steps on Azure Kubernetes Service (AKS)."
authors: ["sachi-desai", "suraj-deshmukh"]
tags: ["gpu", "performance", "operations"]
---

In recent months, dynamic resource allocation (DRA) has emerged as the standard mechanism to consume GPU resources in Kubernetes. With DRA, accelerators like GPUs are no longer exposed as static extended resources (e.g. `nvidia.com/gpu`) but are dynamically allocated through `DeviceClasses` and `ResourceClaims`. This unlocks richer scheduling semantics and better integration with virtualization technologies like NVIDIA vGPU.

Virtual accelerators such as NVIDIA vGPU are commonly used for smaller workloads because they allow a single physical GPU to be securely partitioned across multiple tenants or apps. This is especially valuable for enterprise AI/ML development environments, fine-tuning, and audio/visual processing. vGPU enables predictable performance profiles while still exposing CUDA capabilities to containerized workloads.

In this post, we’ll walk through enabling the NVIDIA DRA Driver on a node pool backed by an [NVadsA10_v5 series](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series) vGPU on Azure Kubernetes Service (AKS).

<!-- truncate -->

## Prepare your AKS cluster

### Verify DRA is enabled

Starting with your AKS cluster running *Kubernetes version `1.34` or above*, you can confirm whether DRA is enabled on your cluster by looking for `deviceclasses` and `resourceslices`.

Check `deviceclasses` via `kubectl get deviceclasses` or check `resourceslices` via `kubectl get resourceslices`.

At this point, the results for both commands should look similar to:

```output
No resources found
```

If DRA isn't enabled on your cluster (for example, if it is running an earlier Kubernetes version than `1.34`), you may instead see an error like:

```output
error: the server doesn't have a resource type "deviceclasses"/"resourceslices"
```

### Add a vGPU node pool and label your nodes

Add a GPU node pool and specify an Azure virtual machine (VM) size which supports virtualized accelerator workloads (e.g. [NVadsA10_v5 sizes series](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series)).

```bash
az aks nodepool add \
  --resource-group <resource-group> \
  --cluster-name <aks-cluster-name> \
  --name gpunodepool1 \
  --node-count 2 \
  --node-vm-size Standard_NV6ads_A10_v5 \
```

:::note
The NVIDIA DRA kubelet plugin runs as a DaemonSet and requires specific node labels, such as `nvidia.com/gpu.present=true`.
:::

Today, AKS GPU nodes already include `accelerator=nvidia`, so we'll use this selector to apply the required label:

```bash
kubectl get nodes -l accelerator=nvidia -o name | \
  xargs -I{} kubectl label {} nvidia.com/gpu.present=true
```

You can expect a similar output to the following:

```output
node/aks-gpunodepool1-12345678-vmss000000 labeled
node/aks-gpunodepool1-12345678-vmss000001 labeled
```

## Install the NVIDIA DRA driver

The recommended way to install the driver is via Helm. Ensure you have Helm updated to the [correct version](https://helm.sh/docs/topics/version_skew/#supported-version-skew).

Add the Helm chart that contains the DRA driver.

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
```

Now, install the NVIDIA DRA driver version `25.8.1`:

```bash
helm --install nvidia-dra-driver-gpu nvidia/nvidia-dra-driver-gpu \
  --version="25.8.1" \
  --create-namespace \
  --namespace nvidia-dra-driver-gpu \
  --set "resources.gpus.enabled=true" \
  --set "gpuResourcesEnabledOverride=true" \
  --set "controller.nodeSelector=null" \
  --set "controller.tolerations[0].key=CriticalAddonsOnly" \
  --set "controller.tolerations[0].operator=Exists" \
  --set "controller.affinity=null" \
  --set "featureGates.IMEXDaemonsWithDNSNames=false"
```

Confirm that the following pods are running:
```bash
kubectl get pods -n nvidia-dra-driver-gpu
```

You can expect a similar output to the following:

```output
NAME                                                  READY   STATUS    RESTARTS
nvidia-dra-controller-xxxxx                          1/1     Running   0
nvidia-dra-kubelet-plugin-aks-gpunodepool1-xxxxx     1/1     Running   0
```

### Why do these Helm settings matter?

Let's walk through some of the DRA Helm chart settings set earlier for vGPU:

1. `resources.gpus.enabled=true`

Standard DRA workloads request devices via the `gpu.nvidia.com` device class, so `resources.gpus.enabled=true` is needed for GPU-accelerated workloads to schedule on these A10 nodes.

2. `gpuResourcesEnabledOverride=true`

The Helm chart includes a validation guard to prevent collisions between the NVIDIA DRA driver (`gpu.nvidia.com`) and legacy NVIDIA device plugin (`nvidia.com/gpu` extended resource). Since we are running DRA exclusively (with no legacy device plugin), we bypass the validation: `gpuResourcesEnabledOverride=true` to ensure the chart installs successfully.

3. `featureGates.IMEXDaemonsWithDNSNames=false`

This feature gate is enabled by default and requires NVIDIA GRID GPU driver version >= `570.158.01`. For Azure VM sizes, like the A10 series, that require the distinct GRID driver `550` branch today, we explicitly set:
`featureGates.IMEXDaemonsWithDNSNames=false` to disable IMEX for this GPU size.

### Verify DeviceClass and ResourceSlices

After deployment, confirm that the `gpu.nvidia.com` DeviceClass exists:

```bash
kubectl get deviceclasses
```

Expected output:

```output
NAME             DRIVER
gpu.nvidia.com   nvidia.com/dra
```

Check ResourceSlices:

```bash
kubectl get resourceslices
```

Expected output:

```output
NAME                                  NODE
gpu-aks-gpunodepool1-xxxxx-0          aks-gpunodepool1-xxxxx-vmss000000
```

Now, we’ve confirmed that the DRA driver discovered and published our vGPU-backed resources, and the nodes are ready to accept workloads! You can follow [these steps](https://blog.aks.azure.com/2025/11/17/dra-devices-and-drivers-on-kubernetes#run-a-gpu-workload-using-dra-drivers) to run a sample workload using the DRA specifications.

## Looking ahead

As GPUs become first-class resources in Kubernetes, combining NVIDIA vGPU with DRA provides a practical way to run shared, production-grade workloads on AKS. vGPU supported Azure VM series offer partial GPUs for scenarios such as media rendering and transcoding, AI research, and simulations, while DRA ensures those resources are allocated explicitly and scheduled with awareness of real cluster state. 

For large AKS deployments, especially in regulated or cost-sensitive industries, getting GPU placement and utilization right directly affects job throughput and infrastructure efficiency. Using DRA with vGPU will enable organizations to move beyond coarse node-level allocation toward controlled, workload-driven GPU consumption at scale.
