---
title: "Announcement - Node Auto-provisioning"
description: "Sample - Add your description"
date: 2025-08-14
author: Wilson Darko # must match the authors.yml in the _data folder
categories: 
- general, add-ons, compute
---

We’re excited to announce the General Availability (GA) of Node Auto Provisioning (NAP) in Azure Kubernetes Service (AKS)! 

Managing dynamic workloads in Kubernetes often leads to overprovisioning, idle resources, and operational overhead from maintaining pre-configured node pools. Karpenter, the open-source CNCF project allows for compute-optimized node provisioning, that offers flexibility, cost savings, and simplicity.  

With node auto provisioning (NAP), our managed add-on for Karpenter on Azure, AKS now automatically provisions single-instance nodes (VMs) in response to unscheduled pods,  and optimizes the scaling experience. With NAP, we bring a new approach to autoscaling and provisioning that outperforms cluster autoscaler in compute efficiency, cost, and ease of use. NAP allows for many SKU sizes, spot and on-demand capacity, and multiple architecture types in the same cluster, without the need for separate nodepools.  

## 🚀 What’s New with NAP since Preview Launch 

- NAP now uses VM images from Shared Image Galleries, unlocking additional capabilities (such as coming FIPS support). 
- More networking options: Azure CNI with or without Overlay is supported, Cilium dataplane is supported; BYO CNI is allowed. Custom Virtual Networks (VNet) is supported. 
- New method of node bootstrapping; much better reliability, from compatibility with AKS VM image releases and AKS bootstrapping configuration updates. 
- Improved upgrade experience, including support for AKS Maintenance Windows (and Karpenter disruption budgets) 
- New Karpenter core capabilities integrated and supported: v1 NodePool API, support for disruption budgets (allows users to control the speed of disruption in the cluster), terminationGracePeriod, consolidateAfter, forceful expiration, node repair, and more. NodePools now have status conditions that indicate if they are ready. See core releases for details. 
- New Azure provider capabilities: support for Azure Linux (including v3), ephemeral disk placement, Linux admin username, custom kubelet config, tagging of Azure resources, artifact streaming, non-zonal regions and VM SKUs, zone constraint in NodePool requirements (and generally cleaner set of selectors), node auto-repair, network interface garbage collection, support for NVMe-only VM SKUs, AKS/Kubernetes 1.30-33, readiness status in AKSNodeClass, and more. See Azure provider releases for details. 
- Improved observability, via rich set of metrics (accessible through Managed Prometheus), accessible and improved logs through Azure Monitor, NodePool / AKSNodeClass / NodeClaim conditions (including reasons for drift or provisioning failures), and events. 
- Default NAP node pools are now optional; disabling NAP is supported. 
- Better performance, reliability, error handling (including handling of provisioning failures), and security. Numerous bugfixes and issues resolved. 
- Extensive test coverage. Eight new E2E test suites, ~100 total scenarios. 95% unit test coverage. 
- Github Contributions welcome! (GitHub Codespace-based dev/test environment in 5 min) 
- Many customers tell us that keeping Kubernetes up to date is one of their biggest obstacles in managing clusters. In AKS, we've put significant effort into making automated upgrades easy and effective. 

## Getting Started with NAP


## Roadmap + Next Steps 

We’re continuing to expand the capabilities for NAP for additional feature support and performance. Stay on the 

- Sovereign Cloud + Air-Gapped Cloud Support 
- FIPS Support 
- Disk Encryption Sets 
- Windows support
- Private Cluster Support
- and more ... 

## Section 2


## Section 3


## Summary
