---
title: "Recommendations for Major OS Version Upgrades with Azure Kubernetes Service (AKS)"
description: "Discover best practices and actionable guidance to plan and execute major OS version upgrades on AKS with confidence and minimal disruption."
date: 2025-09-18
authors: [flora-taagen, ally-ford]
tags:
  - azure-linux
  - best-practices
  - operations
  - security
---
### Introduction

Upgrading the operating system version on your AKS nodes is a critical step that can impact workload security, stability, and performance. In this blog, we’ll share key recommendations to help you plan and execute major OS version upgrades smoothly and confidently on AKS.

<!-- truncate -->

### Why Upgrading OS versions matters

In Azure Kubernetes Service (AKS), the operating system (OS) serves as the foundational layer for every node in your cluster. It governs how containers are executed, how resources are managed, and how workloads interact with the underlying infrastructure.

![AKS Linux Node ](node.png)

_Figure 1: AKS Linux Node Image including Operating system, container runtime, and core Kubernetes node components._

Keeping your OS version up to date is essential for maintaining security, performance, and compatibility. There are two kinds of OS upgrades that can be made to keep you on the latest OS version: 

1.	**Minor Version Upgrade or Patch Upgrade**: Upgrading your node image version so that you have the latest release within an OS version. For example, upgrading your Ubuntu 22.04 node image from the 202509.11.0 release to the 202509.18.0 release. When you perform a minor version or patch upgrade you benefit from the latest OS-level security patches, resolved bugs, and ensure alignment with AKS lifecycle guarantees.
2.	**Major Version Upgrade**: Upgrading your OS version when a new major version becomes available.[SH3.1][FT3.2] For example, upgrading your OS version from Azure Linux 2.0 to Azure Linux 3.0.[KS4.1][KS4.2] When you perform a major OS version upgrade you benefit from new package versions, performance improvements, security enhancements, improved developer tooling, and more.

![AKS Major OS Version Upgrade ](upgrade.png)

_Figure 2: Major version upgrade from Azure Linux 2.0 to Azure Linux 3.0,_



