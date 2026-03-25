---
title: "AI Inference on AKS Arc — Part 0: Introduction, Audience, and Lab Contract"
date: 2026-03-25
description: "Generative & Predictive AI Inference on Azure Arc: A Multi‑Part, Contract‑Driven Lab Series"
authors:
- datta-rajpure
tags: ["aks-arc", "ai", "inference"]
---
This blog series provides hands-on, step-by-step labs for running generative and predictive AI inference workloads on Azure Arc–enabled AKS clusters using CPUs, GPUs, and NPUs. The labs are designed to run in on‑premises and edge environments—specifically Azure Local (Azure Stack HCI)—and focus on repeatable, production‑oriented validation scenarios rather than abstract examples.

<!-- truncate -->

## Introduction
These labs were created to address a consistent gap observed with AKS Arc customers: while AI inference patterns are well-documented for public cloud environments, those patterns often do not translate cleanly to on‑premises or edge deployments. Customers operating AKS Arc commonly face constraints such as limited or intermittent connectivity, heterogeneous hardware, stricter security and compliance requirements, and tighter operational coupling with existing infrastructure.
Rather than presenting reference architectures or simplified samples, this series focuses on end‑to‑end validation scenarios that reflect how customers actually deploy, test, and operate inference workloads on Arc-enabled Kubernetes. Each lab is structured to help readers evaluate feasibility, understand performance characteristics, and assess operational readiness before making broader platform or hardware investments.
The intent is not to prescribe a single “correct” inference stack, but to provide a grounded, repeatable framework that enables informed decision‑making for AI inferencing on AKS Arc.

## Audience & Assumptions
This series is written for readers who meet all of the following criteria:
- You are already familiar with Kubernetes concepts such as pods, deployments, services, and node scheduling.
- You are operating, or plan to operate, AKS enabled by Azure Arc on Azure Local or a comparable on‑premises / edge environment.
- You are comfortable using command‑line tools such as kubectl, Azure CLI, and Helm.
- You are evaluating AI inference workloads (LLMs or predictive models) from an infrastructure and platform perspective, not from a data science or model‑training perspective.

### Explicit Non‑Goals
To keep the labs focused and actionable, the following topics are intentionally not covered in this series:
- **Kubernetes fundamentals or onboarding:**
  Readers new to Kubernetes should complete foundational material first:
  - Introduction to Kubernetes (Microsoft Learn): https://learn.microsoft.com/training/modules/intro-to-kubernetes/
  - Kubernetes Basics Tutorial (Upstream): https://kubernetes.io/docs/tutorials/kubernetes-basics/

- **Azure Arc conceptual overview or onboarding:**
  This series assumes you already understand what Azure Arc provides and how Arc-enabled Kubernetes works:
  - Azure Arc–enabled Kubernetes overview: https://learn.microsoft.com/azure/azure-arc/kubernetes/overview
  - AKS enabled by Azure Arc documentation: https://learn.microsoft.com/azure/aks/aksarc/

- **Model training, fine‑tuning, or data preparation:**
  All labs assume models are already trained and packaged in formats supported by the selected inference engine.

- **Deep internals of inference engines:**
Engine-specific internals are referenced only where required for deployment or configuration. For deeper learning:
  - NVIDIA Triton Inference Server documentation: https://docs.nvidia.com/deeplearning/triton-inference-server/
  - NVIDIA GPU Operator documentation: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html

If you are looking for conceptual comparisons, performance benchmarks, or model‑level optimizations, those topics are intentionally out of scope for this lab series.

## Lab Contract (What This Series Guarantees)
Part 0 establishes a contract that applies to all subsequent labs in this series:
  - All labs run on the same Arc-enabled AKS environment unless explicitly stated otherwise.
  - Azure Arc is used as the management and control plane only; inference execution always occurs locally on the cluster.
  - No managed Azure AI services are used to execute inference.
  - Each lab follows a consistent, repeatable structure so results can be compared across inference engines and hardware types.

### Standard Lab Flow
Each lab follows the same high‑level sequence:
- **Connect & Verify:**
Log in to Azure and get cluster credentials. Inspect available compute resources (CPU, GPU, NPU) and node labels/capabilities
- **Prepare the Accelerator (If Required):**
Install or validate the required accelerator enablement based on the scenario.
  - GPU: NVIDIA GPU Operator
  - NPU: Vendor‑specific enablement (future)
  - CPU: No accelerator setup required
- **Step 3: Deploy the Inference Workload:**
  - Deploy the model server or inference pipeline (LLM server, Triton, or other engine)
  - Configure runtime parameters appropriate to the selected hardware
- **Validate  Inference:**
  - Send a test request (prompt, image, or payload)
  - Confirm functional and expected inference output
- **Clean Up Resources:**
  - Remove deployed workloads
  - Release cluster resources (compute, storage, accelerator allocations)

## Series Outline: 
This blog series explores multiple AI inferencing approaches on AKS Arc, starting with a set of representative solutions and evolving over time as new labs are added. The initial labs cover the following scenarios, and this section, along with the prerequisites and table of contents, will be updated as additional inferencing engines, hardware targets, and scenarios are introduced.

### Part 1 - Generative AI
  1. AI Inference with Ollama on Azure Arc – Deploying an open-source LLM server (Ollama) on an Arc-enabled cluster.
  2. AI Inference with vLLM on Azure Arc – Using the high-throughput vLLM engine to serve an LLM on Arc.
  
### Part 2, 3, and 4 - Predictive AI
  3. AI Inference with Triton (ONNX) on Azure Arc – Running an ONNX-based ResNet-50 vision model on Arc via NVIDIA Triton.
  4. AI Inference with Triton (TRT‑LLM) on Azure Arc – Deploying a TensorRT-LLM pipeline for optimized large-model inference on Arc.
  5. AI Inference with Triton (vLLM) on Azure Arc – Serving a vision-language LLM using Triton with the vLLM backend on Arc.

All labs share a common AKS Arc environment with a baseline set of prerequisites outlined below.
## Prerequisites
Before starting, ensure you have the following in place:

- **Arc-enabled AKS cluster with a GPU node:** A Kubernetes cluster enabled for Azure Arc on Azure Local (Azure Stack HCI) with at least one GPU node and appropriate NVIDIA drivers installed. The GPU node needs the NVIDIA device plugin (via the NVIDIA GPU Operator) running so pods can access nvidia.com/gpu resources.

- **Azure CLI with Arc extensions:** The [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed on your admin machine, plus the aks-preview extension and either the aksarc or connectedk8s extension (for Arc-enabled Kubernetes). Use az extension list -o table to confirm these are installed.

- **kubectl:** The Kubernetes CLI installed on your workstation for applying manifests and managing cluster resources.

- **Helm :** The [Helm](https://helm.sh/docs/intro/install/) package manager installed (v3), for deploying the GPU Operator and helm charts as needed.

- **PowerShell 7+ (optional):** If using PowerShell for CLI steps and REST calls, upgrade to PowerShell 7.4 or later (older Windows PowerShell 5.1 may cause JSON quoting issues in our examples).

- **Cluster access:** Ensure you can connect to your Arc-enabled cluster (e.g. same network or VPN to the Azure Local environment). After logging in to Azure and retrieving cluster credentials, verify access by listing nodes:

```powershell
az login
az aks get-credentials --resource-group <YourResourceGroup> --name <YourClusterName>
kubectl get nodes
#This should show your cluster’s nodes, including any GPU node(s).
```

Note On Windows 11, you can use Winget to quickly install prerequisites. For example:
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

# Install or Update – Azure CLI Extensions (AKS Arc)
az extension add --name aksarc
az extension add --name connectedk8s
az extension update --name aksarc
az extension update --name connectedk8s
```

### Install the NVIDIA GPU operator
Next, install the NVIDIA GPU Operator on the cluster. This operator installs the necessary drivers and Kubernetes device plugin to expose GPU resources to your workloads. vLLM requires the NVIDIA Kubernetes plugin to access the GPU hardware.
1.	Add the NVIDIA Helm repository: If you haven’t already, add NVIDIA’s Helm chart repository and update it:
```powershell
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
```
This adds the official NVIDIA chart source (which contains the GPU operator chart) to your Helm client.

2.	Install the GPU operator: Use Helm to install the NVIDIA GPU Operator onto your cluster:
```powershell
helm install --wait --generate-name nvidia/gpu-operator
```
This will install the GPU operator into your cluster (in its default namespace) and wait for all components to be ready. The --generate-name flag automatically assigns a name to the Helm release. The operator will set up the NVIDIA device plugin and drivers on your cluster nodes.

:::note 
Ensure your cluster nodes have internet connectivity to pull the necessary container images for the operator. This may take a few minutes the first time as images are downloaded.
:::


