---
title: "AI Inference on AKS enabled by Azure Arc: Series Introduction and Scope"
date: 2026-04-07T00:01:01
description: "Scenario driven series for generative and predictive AI inference on AKS enabled by Azure Arc, across CPUs, GPUs, and NPUs in on-premises and edge environments."
authors:
- datta-rajpure
tags: ["aks-arc", "ai", "ai-inference"]
---
This series gives you **practical, step-by-step guidance** for running generative and predictive AI inference workloads on Azure Kubernetes Service (AKS) enabled by Azure Arc clusters, using CPUs, GPUs, and neural processing units (NPUs). The scenarios target on‑premises and edge environments, specifically Azure Local, with a focus on **repeatable, production-ready validation** rather than abstract examples.

<!-- truncate -->

![AI inference on AKS enabled by Azure Arc series overview showing generative and predictive AI patterns across hybrid environments](./hero-image.png)

## Introduction

[Part 1](/2026/04/07/ai-inference-on-aks-arc-part-1) covered why running AI inference at the edge matters. This post defines the series scope, ground rules, and shared prerequisites so each tutorial can focus on the hands-on deployment.

## Scope and ground rules

This series assumes you are familiar with Kubernetes (pods, deployments, services, node scheduling), comfortable with kubectl, Azure CLI, and Helm, and operating or planning to operate AKS enabled by Azure Arc on Azure Local or a comparable environment. The focus is infrastructure and platform validation, not data science or model training.

**Not covered:**

- [Kubernetes fundamentals](https://learn.microsoft.com/training/modules/intro-to-kubernetes/)
- [AKS enabled by Azure Arc overview](https://learn.microsoft.com/azure/azure-arc/kubernetes/overview)
- [AKS enabled by Azure Arc documentation](https://learn.microsoft.com/azure/aks/aksarc/)
- Model training and fine-tuning
- [Triton Inference Server internals](https://docs.nvidia.com/deeplearning/triton-inference-server/)
- [GPU Operator internals](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html)

**Ground rules:** All scenarios use the same AKS enabled by Azure Arc environment and follow a consistent structure. Inference execution always occurs locally on the cluster. No managed Azure AI services are used. Each scenario follows the same steps: **connect and verify** cluster access, **prepare the accelerator** if required, **deploy the inference workload**, **validate inference** with a test request, and **clean up resources**.

## Series outline

The series is designed to evolve. New topics will be added as additional scenarios, runtimes, and architectures are validated.

### Topics covered in this series

| Topic | Type | Status |
| ----- | ---- | ------ |
| [**Ollama**: open-source LLM server](/2026/04/07/ai-inference-on-aks-arc-part-3) | Generative | ✅ Available |
| [**vLLM**: high-throughput LLM engine](/2026/04/07/ai-inference-on-aks-arc-part-3) | Generative | ✅ Available |
| [**Triton + ONNX**: ResNet‑50 image classification](/2026/04/07/ai-inference-on-aks-arc-part-4) | Predictive | ✅ Available |
| **Triton + TensorRT‑LLM**: optimized large-model inference | Generative | 🔜 Coming soon |
| **Triton + vLLM backend**: vision-language model serving | Generative | 🔜 Coming soon |

## Prerequisites

All scenarios in this series run on a common AKS enabled by Azure Arc clusters environment. Before you begin, make sure you have the following in place:

- **AKS enabled by Azure Arc clusters with a GPU node:** A Azure Local clusters with at least one GPU node and appropriate NVIDIA drivers installed. The GPU node needs the NVIDIA device plugin (via the NVIDIA GPU Operator) running so pods can access nvidia.com/gpu resources.

- **Azure CLI with Azure Arc extensions:** The [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed on your admin machine and `connectedk8s` extensions (for Azure Arc-enabled Kubernetes). Use `az extension list -o table` to confirm these are installed.

- **kubectl:** The Kubernetes CLI installed on your workstation for applying manifests and managing cluster resources.

- **Helm:** The [Helm](https://helm.sh/docs/intro/install/) package manager installed (v3), for deploying the GPU Operator and helm charts as needed.

- **PowerShell 7+ (optional):** If using PowerShell for CLI steps and REST calls, upgrade to PowerShell 7.4 or later (older Windows PowerShell 5.1 may cause JSON quoting issues in our examples).

- **Cluster access:** Ensure you can connect to your AKS enabled by Azure Arc clusters (e.g. same network or VPN to the Azure Local environment). After logging in to Azure and retrieving cluster credentials, verify access by listing nodes:

```powershell
az login

# Use this command when you have AKS RBAC to export cluster credentials.
az aks get-credentials --resource-group <YourResourceGroup> --name <YourClusterName>

# Otherwise, use this command to access the cluster via the proxy without exporting credentials.
az connectedk8s proxy --resource-group <YourResourceGroup> --name <YourClusterName>

# This should show your cluster’s nodes, including any GPU node(s).
kubectl get nodes
```

Note: On Windows 11, you can use `winget` to quickly install prerequisites. For example:

```powershell
# Install PowerShell
winget install -e --id Microsoft.PowerShell
pwsh -v

# Install or Update - Azure CLI, Kubectl, Helm, Git
winget install -e --id Microsoft.AzureCLI
winget install -e --id Kubernetes.kubectl
winget install -e --id Helm.Helm
winget install -e --id Git.Git
winget update -e --id Microsoft.AzureCLI
winget update -e --id Kubernetes.kubectl
winget update -e --id Helm.Helm
winget update -e --id Git.Git

# Install or Update – Azure CLI Extensions
az extension add --name aksarc
az extension add --name connectedk8s
az extension update --name aksarc
az extension update --name connectedk8s
```

### Install the NVIDIA GPU operator

Next, install the NVIDIA GPU Operator on the cluster. This operator installs the necessary drivers and Kubernetes device plugin to expose GPU resources to your workloads. vLLM requires the NVIDIA Kubernetes plugin to access the GPU hardware.

- **Add the NVIDIA Helm repository:** If you haven’t already, add NVIDIA’s Helm chart repository and update it:

```powershell
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
```

This adds the official NVIDIA chart source (which contains the GPU operator chart) to your Helm client.

- **Install the GPU operator:** Use Helm to install the NVIDIA GPU Operator onto your cluster:

```powershell
helm install --wait --generate-name nvidia/gpu-operator
```

This will install the GPU operator into your cluster (in its default namespace) and wait for all components to be ready. The --generate-name flag automatically assigns a name to the Helm release. The operator will set up the NVIDIA device plugin and drivers on your cluster nodes.

:::note
Ensure your cluster nodes have internet connectivity to pull the necessary container images for the operator. This may take a few minutes the first time as images are downloaded.
:::

### Next up: [Generative AI with Open‑Source LLM Server](/2026/04/07/ai-inference-on-aks-arc-part-3)
