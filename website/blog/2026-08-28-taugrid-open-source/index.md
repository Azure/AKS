---
title: "Open-sourcing TauGrid: cloud-native AI infrastructure for GPU workloads on Kubernetes"
description: "TauGrid combines the tau CLI, Kueue, KubeRay, GPU health monitoring, and observability into one Kubernetes-native stack for AI workloads."
date: 2026-08-28
authors: ["pengfei-ni", "june-liu", "kevin-cho", "guoxun-wei"]
tags:
  - ai
  - gpu
  - kueue
  - ray
  - open-source
---

Running AI workloads on Kubernetes often requires platform teams to assemble and maintain multiple open-source projects, custom scripts, and operational tools. This includes the glue between those components: submission scripts, queue wrappers, health checks, and result retrieval. TauGrid brings these pieces together into a single platform, so platform teams operate one stack instead of many, and researchers submit workloads without learning Kubernetes.

We are delighted to announce the open-source release of [TauGrid](https://github.com/Azure/taugrid). TauGrid combines the `tau` CLI, [Kueue](https://kueue.sigs.k8s.io/) queueing, [KubeRay](https://ray-project.github.io/kuberay/) orchestration, GPU-node health monitoring, and observability in a single Kubernetes-native stack. It supports workflows spanning data preparation, distributed training, fine-tuning, and inference.

Instead of building and maintaining these components and the integration between them separately, TauGrid provides a single Helm install with clear ownership boundaries. Platform teams get a unified way to operate the stack, while researchers get one CLI to submit workloads, observe their progress, recover from failures, and retrieve results without interacting with Kubernetes directly.

The project is MIT-licensed and available at [github.com/Azure/taugrid](https://github.com/Azure/taugrid), with container images and Helm charts published to [Microsoft Container Registry](https://mcr.microsoft.com). Full documentation is available at [azure.github.io/taugrid](https://azure.github.io/taugrid).

<!-- truncate -->

## What is TauGrid?

TauGrid is an open-source, self-hosted platform for running AI workloads on Kubernetes. It gives teams the key benefits of a managed AI platform (job submission, scalable distributed computing, shared GPU resources, experiment tracking, and operational controls) while running on infrastructure they manage in their own cloud or data center.

Researchers work from a repository and the Tau CLI. Platform teams provide governed workspaces, queues, compute profiles, storage, identity, and observability. TauGrid connects those two experiences across training, fine-tuning, batch inference, and serving. The result is reduced operational complexity for platform teams, faster onboarding for researchers, better GPU utilization through shared queueing, and consistent experiment reproducibility through evidence records.

![TauGrid architecture: from researcher intent through the TauGrid workflow layer to Kubernetes execution and evidence](./architecture.png)

## How it works

TauGrid uses a `tau.yaml` configuration file to describe the workload. Here is a GPU training example that runs a PyTorch workload on a single A100:

```yaml
schema_version: 1
name: aks-gpu-quickstart
run:
  entrypoint: train.py
  workload_kind: rayjob
compute:
  gpus: 1
  workers: 1
  cpus: 16
  memory: 64Gi
runtime:
  image: mcr.microsoft.com/aks/ai-runtime/ray:py3.12-ray2.56.0-cuda13.0
  pip:
    - torch>=2.4.0
```

Once submitted with `tau run`, TauGrid resolves platform policy, renders a KubeRay RayJob, and submits it through Kueue. Status, logs, checkpoints, and experiment evidence are tracked throughout the run. Evidence records capture workload metadata, configuration, logs, metrics, checkpoints, and execution history, helping teams reproduce results, troubleshoot failures, and maintain an audit trail.

The same stack covers the full GPU workload lifecycle. This animation shows a workload moving from data preparation through distributed training, fine-tuning, and into a ready inference endpoint, all with one continuous evidence record:

![A single workload moves through data preparation, distributed training, fine-tuning, and a ready inference endpoint, with one continuous evidence record](./taugrid-workload-lifecycle.gif)

Here is what TauGrid handles at each stage:

| Stage | What TauGrid does |
| --- | --- |
| Submission | Validates configuration and renders a Kubernetes Job or KubeRay RayJob |
| Queueing | Uses Kueue to govern quota admission and priority |
| Execution | Launches and manages distributed Ray workloads on Kubernetes |
| Monitoring | Tracks status, logs, and GPU health metrics throughout the run |
| Recovery | Supports retry, resume from checkpoints, and failure diagnosis |
| Evidence | Preserves workload history, metrics, and artifacts for reproducibility |

When multiple teams share the same cluster, their workloads enter a shared Kueue ClusterQueue. Kueue admits each job based on quota and priority, and Kubernetes places it on healthy GPUs.

![Jobs from three workspaces share a Kueue ClusterQueue, the front job receives GPU quota and Kubernetes places it on two healthy GPUs](./taugrid-control-room.gif)

## Getting started

You need a Kubernetes 1.30+ cluster, `kubectl`, Helm 3+, and Git. Install the Tau CLI:

```bash
curl -fsSL https://github.com/Azure/taugrid/releases/latest/download/install.sh | sh

export PATH="$HOME/.local/bin:$PATH"
tau version --short
```

Install TauGrid onto your cluster:

```bash
tau cluster install
tau cluster validate installation
```

Create a workspace and wait for it to be ready:

```bash
tau workspace create "taugrid-default" --apply

kubectl wait \
  --for=jsonpath='{.status.phase}'=Ready \
  workspaces.tau.azure.com/taugrid-default \
  --namespace tau-system \
  --timeout=5m
```

Submit your first workload:

```bash
git clone https://github.com/Azure/taugrid.git
cd taugrid

tau run --config examples/cpu-multi-interest-ray/tau.yaml
tau run status cpu-multi-interest-ray --watch
tau run logs cpu-multi-interest-ray -f
```

This example runs a CPU workload and does not require GPU nodes. For the full step-by-step guide including cluster preparation, workspace configuration, GPU workloads, and handoff to researchers, see the [Getting Started on Kubernetes](https://azure.github.io/taugrid/docs/platform-admin-guide/installation-guides/kubernetes/) documentation.

The repository also includes these runnable examples:

| Example | What it demonstrates |
| --- | --- |
| [CPU queueing](https://azure.github.io/taugrid/docs/examples/cpu-queueing/) | Kueue admission, pending states, and borrowing between teams (no GPU required) |
| [GPU Ray Tune](https://azure.github.io/taugrid/docs/examples/gpu-ray-tune/) | Hyperparameter search on a single GPU with deterministic validation |
| [Experiment evidence](https://azure.github.io/taugrid/docs/examples/experiment-evidence/) | Persistent metrics, Stellar visualization, and evidence verification |
| [Full cluster](https://azure.github.io/taugrid/docs/examples/full-cluster/) | Terraform-provisioned AKS cluster with GPU nodes and end-to-end validation |

For more examples and detailed walkthroughs, see the [examples documentation](https://azure.github.io/taugrid/docs/examples/).

## Looking ahead

TauGrid is under active development. The full [roadmap](https://github.com/Azure/taugrid/blob/main/ROADMAP.md) is maintained in the repository.

**Multi-tenant platform capabilities:** Support for multiple workspaces with scoped identity, RBAC, and quotas, along with an interactive portal for submitting and managing workloads.

**Distributed training workflows:** End-to-end examples for PyTorch DDP, FSDP, DeepSpeed, and Hugging Face LoRA/QLoRA, plus a complete dataset lifecycle covering fetch, staging, validation, tokenization, and registration.

**Inference workflows:** Production-oriented serving examples for vLLM, SGLang, and TensorRT-LLM.

**Multi-cluster and multi-cloud execution:** Cross-cloud workload execution with portable data, checkpoints, and artifacts, supported by provider-agnostic observability and cost attribution.

TauGrid will continue to focus on the workflow and workload lifecycle layer. Cluster provisioning, pod scheduling, quota enforcement handled by Kubernetes and Kueue, framework internals, and model code remain outside its scope.

## What's next?

Install the CLI, point it at any Kubernetes 1.30+ cluster, and submit your first workload. We are building TauGrid in the open and want your input: file an issue when something breaks, open a pull request to fix a bug or add a feature, share feedback on the lifecycle contract, or tell us how TauGrid fits (or does not fit) into your existing platform.

Get started with the [documentation](https://azure.github.io/taugrid), explore the code on [GitHub](https://github.com/Azure/taugrid), and check out the [contributing guide](https://github.com/Azure/taugrid/blob/main/CONTRIBUTING.md) to learn how to get involved.
