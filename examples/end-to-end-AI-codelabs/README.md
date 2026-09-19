# End-to-end AI codelabs on AKS

Build complete AI scenarios on Azure Kubernetes Service (AKS). Each codelab
starts with Azure infrastructure and ends with a working application and an
observable result.

These examples are designed as hands-on learning experiences. Each module has a
goal, an estimated time, commands, a checkpoint, focused troubleshooting, and a
clear next step.

## Codelabs

| Codelab | What you build | Time |
|---|---|---:|
| [Provision GPU inference with Kueue](kueue-gpu-inference-autoscaling/) | Start with zero GPU nodes, submit a three-pod inference workload through Kueue, and watch the AKS cluster autoscaler provision all three GPU nodes before the models serve requests | 45–60 minutes |
| [Accelerate distributed training with GPUDirect RDMA](distributed-training-rdma/) | Provision two InfiniBand GPU nodes, validate RDMA end to end, and measure the same PyTorch DDP workload over Ethernet and GPUDirect RDMA | 60–90 minutes |

## Before you begin

The codelabs create billable Azure resources. Review the prerequisites and cost
notes for a codelab before you start, and run its cleanup module when you finish.

The examples are intentionally kept in Markdown, shell scripts, and Kubernetes
manifests. This makes them easy to run from GitHub now and suitable for a more
interactive lab experience later.
