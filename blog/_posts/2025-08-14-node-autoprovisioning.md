---
title: "Announcement - Node Auto Provisioning"
description: "Learn about Node Auto Provisioning for Azure Kubernetes Service, based on Karpenter, and how it can simplify the scaling experience for your workloads on AKS."
date: 2025-08-14
author: Wilson Darko # must match the authors.yml in the _data folder
categories: 
- general, add-ons, compute
---

We’re excited to announce the General Availability (GA) of Node Auto Provisioning (NAP) for Azure Kubernetes Service (AKS)!

Managing dynamic workloads in Kubernetes often leads to overprovisioning, idle resources, and operational overhead from maintaining pre-configured node pools. [Karpenter](https://karpenter.sh/), the open-source CNCF project, allows for compute-optimized node provisioning, that offers flexibility, cost savings, and simplicity.

With node auto provisioning (NAP), our managed add-on for the open-source [Karpenter](https://karpenter.sh/) project on AKS, AKS now automatically provisions single-instance nodes (VMs) in response to pending pod requirements, and optimizes the scaling experience by provisioning right-sized compute in the more efficient and cost-effective manner. With NAP, we bring a new approach to autoscaling and provisioning that outperforms cluster autoscaler in compute efficiency, cost, and ease of use. NAP offers greater flexibility, allowing many SKU sizes, spot and on-demand capacity, and multiple architecture types such as AMD and ARMx64 in the same cluster, without the need for separate node pools.

![nap-ga-announcement](/assets/images/aks-nap/nap-ga-announcement.jpg)

## What’s New with NAP since Preview Launch

- More networking options: Azure CNI with or without Overlay is supported, Cilium dataplane is supported; BYO CNI is allowed. Custom Virtual Networks (VNet) is supported. For more on networking, visit our [NAP networking documentation](https://learn.microsoft.com/azure/aks/node-autoprovision-networking)
- New method of node bootstrapping; better reliability, from compatibility with AKS VM image releases and AKS bootstrapping configuration updates.
- Improved upgrade experience, including support for [AKS Maintenance Windows](https://learn.microsoft.com/azure/aks/planned-maintenance) and [Karpenter disruption budgets](https://learn.microsoft.com/azure/aks/node-autoprovision-disruption#disruption-budgets), which allow users to control the speed of disruption in the cluster.
- New Karpenter core capabilities integrated and supported: v1 NodePool API, expanded support for [disruption budgets](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision-disruption) features such as terminationGracePeriod, consolidateAfter, forceful expiration, node repair, and more. [NodePool configuration files](https://learn.microsoft.com/azure/aks/node-autoprovision-node-pools) now have status conditions that indicate if they are ready. See core releases for details.
- New Azure Karpenter Provider capabilities: support for Azure Linux (including v3), ephemeral disk placement, Linux admin username, custom kubelet configuration, tagging of Azure resources, artifact streaming, non-zonal regions and VM SKUs, zone constraint in NodePool requirements (and generally cleaner set of selectors), node auto-repair, network interface garbage collection, support for NVMe-only VM SKUs, AKS/Kubernetes 1.30-33, readiness status in AKSNodeClass, and more. See [Azure Karpenter provider releases](https://github.com/Azure/karpenter-provider-azure/releases) for details.
- Improved observability, via rich set of metrics (accessible through [Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-metrics-overview)), accessible and improved logs through [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/metrics/data-platform-metrics), NodePool / AKSNodeClass / NodeClaim conditions (including reasons for drift or provisioning failures), and events.
- Default NAP node pools are now optional; [disabling NAP is supported](https://learn.microsoft.com/azure/aks/node-autoprovision#disabling-node-autoprovisioning).
- Better performance, reliability, error handling (including handling of provisioning failures), and security. Numerous bugfixes and issues resolved.
- [Extensive test coverage](https://github.com/Azure/karpenter-provider-azure/tree/main/test). Eight new E2E test suites, ~100 total scenarios. 95% unit test coverage.
- Github Contributions welcome! (GitHub Codespace-based dev/test environment in 5 min)

## How node auto provisioning works

Node auto provisioning takes the requirements set by the user in the workload deployment file, and custom resource definition (CRD) files such as the [NodePool](https://learn.microsoft.com/azure/aks/node-autoprovision-node-pools) and [AKSNodeClass](https://learn.microsoft.com/azure/aks/node-autoprovision-aksnodeclass), and provisions nodes that will meet these criteria.

![nap-how-it-works](/assets/images/aks-nap/nap-how-it-works-image.png)

NAP works at the infrastructure level, and adjusts the quantity and sizes of VMs. NAP can be paired with application-level scalers, which affect CPU/Memory resource allocation and pod replica count, such as [KEDA](https://learn.microsoft.com/azure/aks/keda-about), [Horizontal Pod Autoscaler](https://learn.microsoft.com/azure/aks/concepts-scale#horizontal-pod-autoscaler), or [Vertical Pod Autoscaler](https://learn.microsoft.com/en-us/azure/aks/vertical-pod-autoscaler). For more on this, check out our [AKS Scalers Deep Dive on Youtube](https://www.youtube.com/watch?v=oILHg5hsZQ0).

## Node auto provisioning vs. cluster autoscaler

Cluster autoscaler, the standard Kubernetes autoscaler solution, requires the use of same VM size node pools, and scales pre-existing node pools up or down. NAP works instead at the cluster level, and manages single-instance VMs, also handling the provisioning experience for multiple VM sizes and architecture at once. NAP allows for better bin-packing, cost savings, and performance than cluster autoscaler.

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

## Getting Started with NAP

To get started with NAP, you can visit the [Node Auto Provisioning documentation](https://learn.microsoft.com/azure/aks/node-autoprovision). The documentation includes resources, requirements, and all the info needed to enable node auto provisioning in your cluster today.

## Roadmap + Next Steps

We’re continuing to expand the capabilities for NAP for additional feature support and performance. Our upcoming roadmap of feature support includes:

- Sovereign Cloud + Air-Gapped Cloud Support
- FIPS compliant node image support
- Disk Encryption Sets
- Custom CA Certificates
- Windows support
- Private Cluster Support
- and more...

## Get Involved

Contribute to the open-source [Azure Karpenter Provider](https://github.com/Azure/karpenter-provider-azure), which Node Auto Provisioning is based on. The provider features over 37 releases, 1000+ PRs, 14,000 CI runs, and a growing communitiy of contributors.
