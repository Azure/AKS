---
title: "Node Auto Provisioning on Azure Kubernetes Service (AKS)"
description: "Learn about the background story of Node Auto Provisioning in Azure Kubernetes Service (AKS)."
date: 2025-11-25
authors: 
- wilson-darko
- sanket-bakshi
tags:
  - karpenter
  - compute
  - best-practices
  - operations
  - security
keywords: ["AKS", "Kubernetes", "Azure"]
---

Node Auto Provisioning is consistently mentioned as the preferred autoscaling experience in Azure Kubernetes Services (AKS). But what exactly is the value proposition?

<!-- truncate -->


## The Ops Bottleneck: When Growth Becomes a Liability

In the early days of Kubernetes adoption, managing infrastructure was a badge of honor. Teams took pride in crafting node pools tailored to their workloads - balancing cost, performance, and availability. But as AKS adoption scaled across enterprises, this model began to crack.
The core challenge? Manual node pool management doesn’t scale with platform success. 
Every new application, tenant, or workload profile introduced a new set of infrastructure requirements. Ops teams were forced into a reactive loop, creating and tuning node pools, managing quotas, and firefighting scale issues. The more successful the platform, the more brittle it became.
This wasn’t just a technical problem - It was an organizational one. Platform teams were spending more time managing infrastructure than enabling innovation. And in a macroeconomic climate where efficiency is king, that’s a problem.

**The Hidden Complexity of Node Pools**
Let’s unpack the operational pain points that led to Node Auto Provisioning (NAP):

- SKU Selection Paralysis: Customers had to choose the right virtual machine (VM) size for each node pool. But Azure offers hundreds of VM sizes, or VM SKUs, each with different capabilities, pricing, and regional availability. Picking the wrong one could mean wasted spend or failed deployments.
- Capacity Availability: Even if you picked the right SKU, there was always the potential of capacity limits for high-use VM sizes, or quota availability in the region. This often required coordination with Azure support, delaying deployments and frustrating developers.
- Bin Packing Inefficiency: Without precise resource requests and limits, workloads were often spread inefficiently across nodes. This led to underutilized infrastructure and inflated costs.
- Scaling Friction: Cluster Autoscaler worked well, until it didn’t. It required pre-defined node pools, which meant Ops teams had to anticipate every workload shape in advance. When they didn’t, scale-up events failed or delayed.
- Operational Drift: Over time, node pools drifted from their intended purpose. Teams reused them for convenience, leading to noisy neighbor issues and unpredictable performance.
- Maintenance Complexity: Each node pool had to be patched, upgraded, and monitored separately. This fragmented the upgrade process and increased the risk of downtime.

These challenges weren’t theoretical. They were voiced repeatedly by users across industries. From retail to healthcare to fintech, the message was clear: managing complex infrastructure should not be a prerequisite for using Kubernetes.

## Engineering the Invisible: How We Built Node Auto Provisioning

The AKS engineering team set out to flip the model. What if users didn’t have to define infrastructure at all? What if the platform could provision compute dynamically, based on workload needs?

Enter Node Auto Provisioning, built on top of [Karpenter](https://karpenter.sh/), a CNCF project designed for just-in-time compute provisioning.

### Key Design Principles

**SKU-less by Default**: Users no longer need to specify exact Virtual Machine(VM) sizes. Instead, they define workload requirements (CPU, memory, GPU, etc.), VM families and the platform selects the best-fit VMs. 
**Mixed VM Size Autoscaling**: Traditional cluster autoscalers scale pre-existing node pools with only one VM size per pool. With NAP, users can automatically scale up single-instance VMs of mixed sizes (SKUs) 
**Capacity-Aware Scheduling**: NAP is able to react to capacity constraints of certain VM size or regions, by selecting other available VM sizes. 
**Workload Consolidation**: Inspired by Karpenter’s deprovisioning controller, NAP supports automatic consolidation. If workloads are spread thin across many nodes, the system can reschedule them onto fewer  nodes or even replace nodes with cheaper options, reducing cost and improving efficiency.
**Customer Preferences, Not Prescriptions**: Customers can still express preferences like Spot vs. On-Demand, preferred VM families - but they don’t have to manage the details.
**Enforced Resource Requests**: To make intelligent provisioning decisions, we require workloads to define resource requests and limits. This is enforced via admission webhooks, ensuring consistency and predictability.
**Seamless Upgrades**: We designed NAP to work with AKS’s existing upgrade mechanisms, including node image updates and maintenance windows. Customers can opt into auto-consolidation during maintenance windows to minimize disruption.
**Simplified Compute Management**: the self-hosted Karpenter project requires additional efforts around bootstrap token rotation and helm charts, which Node Auto Provisioning takes on the responsibility for. As a managed add-on, NAP brings even more simplicity to the Karpenter experience so you can focus on your workloads and not infrastructure. 

## How node auto provisioning works

Node auto provisioning takes the requirements set by the user in the workload deployment file, and custom resource definition (CRD) files such as the [NodePool](https://learn.microsoft.com/azure/aks/node-autoprovision-node-pools) and [AKSNodeClass](https://learn.microsoft.com/azure/aks/node-autoprovision-aksnodeclass), and provisions nodes that will meet these criteria.

NAP works at the infrastructure level, and adjusts the quantity and sizes of VMs. NAP can be paired with application-level scalers, which affect CPU/Memory resource allocation and pod replica count, such as [KEDA](https://learn.microsoft.com/azure/aks/keda-about), [Horizontal Pod Autoscaler](https://learn.microsoft.com/azure/aks/concepts-scale#horizontal-pod-autoscaler), or [Vertical Pod Autoscaler](https://learn.microsoft.com/en-us/azure/aks/vertical-pod-autoscaler). For more on this, check out our [AKS Scalers Deep Dive on Youtube](https://www.youtube.com/watch?v=oILHg5hsZQ0).

## What's different about NAP vs. Cluster Autoscaler?

Node auto provisioning offers a large range of improved experiences compared to Cluster autoscaler (CAS). NAP offers more intelligent bin-packing of compute, node life cycle management, and minimizes operation overhead. 

| **Reason to Migrate**           | **Cluster Autoscaler (CAS)**                              | **Node Auto Provisioning (NAP)**                                   |
|---------------------------------|-----------------------------------------------------------|--------------------------------------------------------------------|
| **VM Size Flexibility**          | Pre-existing node pools with single VM size per pool     | Dynamic provisioning of mixed VM sizes for cost/performance balance|
| **Cost Optimization**           | Adds/removes nodes in pools; risk of underutilization    | Intelligent bin-packing reduces fragmentation and lowers costs      |
| **Management Overhead**         | Requires manual tuning of CAS profiles                   | Fully managed experience integrated with AKS                        |
| **Lifecycle Management**        | Basic scale-up/scale-down only                           | Advanced node lifecycle optimization; manage node updates, disruption + more |

## NAP vs Self-Hosted Karpenter

Karpenter is the OSS project that schedules workloads for efficient compute usage. Our [AKS Karpenter Provider (self-hosted)](https://github.com/Azure/karpenter-provider-azure) makes use of Karpenter on Azure available. Node Auto-provisioning (NAP) is our managed add-on for Karpenter on AKS that manages certain aspects of the Karpenter experience on Azure. NAP is the recommended mode for most users for a few reasons.

NAP manages:

- Node Image upgrades (Linux)
- Kubernetes version upgrades
- Karpenter version updates
- VM OS disk updates
- Karpenter Logs (through Azure Monitor)
- Metrics (through Managed Prometheus)

In self-hosted Karpenter, users are responsible for managing these processes. Self-hosted mode is useful for advanced users who want to customize or experiment with Karpenter's deployment. The managed add-on NAP simplifies this experience and allows you to focus on your workloads rather than infrastructure.

## Community Stewardship

AKS is built on community stewarded open source projects. Our teams maintain the [Azure Karpenter Provider](https://github.com/Azure/karpenter-provider-azure), and contribute to the core [Karpenter project](https://github.com/kubernetes-sigs/karpenter).

Join us in the Azure Karpenter Provider open source project, which is community-driven and governed by the Cloud Native Computing Foundation. Get involved, contribute, and help shape the future of Karpenter on Azure.

## Getting Started with NAP

To get started with NAP, you can visit the [Node Auto Provisioning documentation](https://learn.microsoft.com/azure/aks/node-autoprovision). The documentation includes resources, requirements, and all the info needed to enable node auto provisioning in your cluster today.

## Roadmap

We’re continuing to expand the capabilities for NAP for additional feature support and performance. Our upcoming roadmap of feature support for NAP includes:

- Dynamic Resource Allocation
- Spot Placement Score API
- LocalDNS Support
- Node Overlay support

To follow along with our backlog and progress, please see our public roadmaps:

- [AKS Public Roadmap](https://github.com/orgs/Azure/projects/685)
- [AKS Public Roadmap - NAP Experiences](https://github.com/orgs/Azure/projects/685/views/1?filterQuery=node-auto-provisioning)

## Next Steps

Learn more about [Node auto provisioning on AKS](https://learn.microsoft.com/azure/aks/node-auto-provisioning).

## Questions?

Connect with the AKS team through our [GitHub discussions](https://github.com/Azure/AKS/discussions) or [share your feedback and suggestions](https://github.com/Azure/AKS/issues)
