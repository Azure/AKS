---
title: "Fully managed GPU node pools with Azure Linux on Azure Kubernetes Service (AKS)"
description: "Learn about how managed NVIDIA GPU nodes with Azure Linux OS provide efficient performance and streamlined operations for high-performance computing workloads on AKS."
date: 2025-11-17
authors: [flora-taagen, sachi-desai]
tags:
  - azure-linux
  - best-practices
  - gpu
  - monitoring
---

### Introduction

Running GPU workloads on AKS enables scalable data processing and AI
applications across Windows, Ubuntu, or Azure Linux nodes.
[Azure Linux](https://learn.microsoft.com/azure/aks/use-azure-linux),
Microsoft’s minimal and secure OS, simplifies GPU setup with validated
drivers and seamless integration, reducing operational efforts.
This blog covers how AKS supports GPU nodes on various OS platforms
and highlights the security and performance benefits of Azure Linux.

### Unique challenges of GPU node pools

Deploying a GPU workload isn’t just about picking the right virtual
machine (VM) SKU. There is also significant operational overhead that
developers and platform engineers need to manage.

We’ve found that many of our customers struggled to manage GPU device
discoverability/scheduling and observability, especially across inconsistent
OS images. Platform teams spent cycles maintaining custom node images and
post-deployment scripts to ensure CUDA compatibility, while developers had
to debug “GPU not found” errors or stalled workloads that consumed GPU
capacity with limited visibility into utilization.

The inconsistent experience across OS options on AKS was a major challenge
that we sought to improve. We wanted to encourage our customers to use the
OS that best-fit  their needs, not blocking them because of feature parity
gaps.

For example, Azure Linux support for GPU-enabled VM sizes on AKS was
historically limited to NVIDIA V100 and T4, creating a gap for Azure
Linux customers requiring higher-performance options. Platform teams
looking to run compute-intensive workloads, such as general-purpose
AI/ML workloads or large-scale simulations, were unable to do so with
Azure Linux and NVIDIA NC A100 GPU node pools -- until now.

### AKS expanding Azure Linux GPU support

#### NC A100 GPU support

The introduction of Azure Linux 3.0+ support for NC A100 GPU node pools
in AKS starts to close many of these gaps. For platform engineers, the
new OS image standardizes the underlying kernel, container runtime, and
driver stack while enabling GPU provisioning in a single declarative step.
Instead of layering custom extensions or maintaining golden images, engineers
can now define a node pool with `--os-sku AzureLinux` and get a consistent,
secure, and AKS-managed runtime that includes NVIDIA drivers/plugin setup and
GPU telemetry out of the box. The Azure Linux 3.0 image also aligns with the
AKS release cadence, which means fewer compatibility issues when upgrading
clusters or deploying existing workloads onto GPU nodes.

#### Bring your own driver for unsupported VM SKUs

If a GPU VM size is not in our list of supported VM sizes, we do not install
the necessary GPU software components or provide support. This often blocked
customers from using the latest VM sizes from NVIDIA. AKS now allows the use
of unsupported GPU VM sizes after
[skipping the automatic GPU driver installation](http://aka.ms/aks/skip-gpu-drivers).

### AKS fully managed GPU nodes (preview)

Using NVIDIA GPUs with Azure Linux on AKS requires the installation of
several components for proper functioning of AKS-GPU enabled nodes,
including GPU drivers, the NVIDIA Kubernetes device plugin, and GPU
metrics exporter for telemetry. Previously, the installation of these
components was either done manually or via the open-source NVIDIA GPU
Operator, creating operational overhead for platform engineers.

To ease this complexity and overhead, AKS has released support for
[fully managed GPU nodes (preview)](https://aka.ms/aks/gpu-default-experience),
which installs the NVIDIA GPU driver, device plugin, and Data Center GPU
Manager (DCGM) metrics exporter in a 1-step experience.

### Deploying GPU workloads on AKS with Azure Linux 3.0

Customers choose to run their GPU workloads on Azure Linux for many reasons,
such as the security posture, support model, resiliency, and/or performance
optimizations that the OS provides. Some of the benefits that Azure Linux
provides for your GPU workloads include:

[insert table here]

#### Deploy a GPU workload with Azure Linux on AKS

Deploying your GPU workloads on AKS with Azure Linux 3.0 is simple. Let’s
use the newly supported NVIDIA NC A100 GPU as our example.

1. To add an NVIDIA NC A100 node pool running on Azure Linux to your AKS cluster using the fully managed GPU node experience you can follow these instructions. Please note, the following parameters must be specified in your `az aks nodepool add` command to create an NVIDIA NC A100 node pool running on Azure Linux:
    * `--os-sku AzureLinux`: provisions a node pool with the Azure Linux container host as the node OS.
    * `--node-vm-size Standard_nc24ads_A100_v4`: provisions a node pool using the `Standard_nc24ads_A100_v4` VM size.
   * Please note, any of the sizes in the Azure `NC_A100_v4` series are supported: `Standard_NC24ads_A100_v4`, `Standard_NC48ads_A100_v4`, or `Standard_NC96ads_A100_v4`.
2. With the DCGM exporter installed by default, you can monitor and visualize detailed GPU metrics such as utilization, memory consumption, and error states. For more information on enabling and consuming GPU metrics in AKS, including integration with Azure-managed or self-hosted Prometheus and Grafana, visit the [GPU Getting Started](https://aka.ms/aks/gpu-default-experience) and [Managed GPU Metrics](https://aka.ms/aks/managed-gpu-metrics) on AKS documentation.

If you prefer not to use a preview feature, you can follow
[these instructions](https://aka.ms/aks/use-gpus) to create an NVIDIA NC
A100 node pool with Azure Linux by manually installing the NVIDIA device
plugin via a DaemonSet on AKS. You’ll also need to manually install the
DCGM exporter to consume GPU metrics.

### Observability & monitoring

Monitoring GPU performance is critical for optimizing utilization,
troubleshooting workloads, and enabling cost-efficient scaling in AKS
clusters. Traditionally, NVIDIA GPU node pools were treated as opaque
resources - jobs could succeed or fail without visibility into whether
GPUs were fully utilized or misallocated.

With the DCGM exporter now managed on AKS, cluster operators can collect
detailed GPU metrics such as utilization, memory consumption, and error
states, and expose them to Prometheus for analysis. These metrics integrate
naturally with existing observability pipelines, providing a foundation for
intelligent automation and alerting.

As an example, a platform team can configure scaling logic in the
[Cluster Autoscaler (CAS)](https://learn.microsoft.com/azure/aks/cluster-autoscaler)
or [Kubernetes Event-Driven Autoscaling (KEDA)](https://learn.microsoft.com/azure/aks/keda-about)
to add A100 nodes when GPU utilization exceeds 70%, or scale down when
utilization remains low for a defined interval. This enables GPU
infrastructure to operate as a dynamic, demand-driven resource
rather than a static, high-cost allocation.

For more information on enabling and consuming GPU metrics in AKS,
including integration with Azure-managed or self-hosted Prometheus
and Grafana, visit the
[Managed GPU Metrics](https://aka.ms/aks/managed-gpu-metrics) guide.

### What's next?

The Azure Linux and AKS teams are actively working on expanding support
for additional GPU VM sizes and managed GPU features on AKS. You can expect
to see Azure Linux support for the NVIDIA
[ND A100](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/ndma100v4-series),
[NC H100](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/ncadsh100v5-series),
and [ND H200](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/nd-h200-v5-series)
families landing in the near future, as well as support for managed
AKS GPU features like
[multi-instance GPU (MIG)](https://learn.microsoft.com/azure/aks/gpu-multi-instance)
and [KAITO](https://learn.microsoft.com/en-us/azure/aks/ai-toolchain-operator).
