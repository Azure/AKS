---
title: "Recommendations for K8s optimized OS options on Azure Kubernetes Service (AKS)"
description: "Discover best practices and actionable guidance to help you select a Kubernetes optimized OS for your AKS deployments."
date: 2025-11-10
authors: [ally-ford, thilo-fromm, sudhanva-huruli]
tags:
  - azure-linux
  - flatcar-container-linux
  - best-practices
  - operations
  - security
keywords: ["AKS", "Kubernetes", "Azure", "Flatcar", "Azure Linux", "OS Guard"]
---
## Introduction

Selecting an operating system for your Kubernetes deployments may appear straightforward; however, this decision can significantly influence both security and operational complexity. In this blog, we’ll share key recommendations to help you select a Kubernetes optimized OS for your AKS deployments.

<!-- truncate -->

## What K8s optimized OS options are available on AKS?

AKS has just released support for two new K8s optimized Linux OS options, Azure Linux OS Guard (preview) and Flatcar Container Linux for AKS (preview). 

When deciding between which K8s optimized OS options to use, AKS recommends the following:
•	Use **Azure Linux OS Guard (preview)** if you’re looking for an enterprise-ready immutable OS, recommended by Microsoft.
•	Use **Flatcar Container Linux for AKS (preview)** if you’re looking for a vendor neutral immutable OS with cross-cloud support.

## What's different about a K8s optimized Linux OS option? 

The main optimization in OS options like Azure Linux OS Guard and Flatcar Container Linux is their immutability. 

An immutable operating system refers to a type of operating system that cannot be modified at runtime. All OS binaries, libraries and static configuration are read-only, the bit-for-bit integrity is often cryptographically protected. These special purpose operating systems usually come without any kind of package management or other traditional means of altering the OS, shipping as self-contained images. User workloads run in isolated environments like containers, sandboxed from the OS.

While these are certainly limiting factors compared to general purpose operating systems, immutable systems perform unparalleled in security and compliance:
•	Binaries cannot be changed, eliminating whole classes of sandbox escapes and exploits.
•	Special purpose operating systems include only what’s absolutely necessary, minimizing the attack surface.
•	As individual parts of the OS cannot be swapped in or out, any given OS release always corresponds to the full version-set of all software and libraries included with that release. This significantly eases software inventory management and makes version drift impossible.

What’s more, immutable operating systems can bring similar benefits to node configuration. By applying node configuration at provisioning time only, there is no configuration drift. To phrase it differently, a node does not hold *state*, its state is defined by configuration passed during provisioning – making node provisioning reproducible.

### Comparing OS Options 

While immutability is the core difference, there’s typically more security features offered with Kubernetes optimized OS options:

| | Azure Linux OS Guard | Flatcar Container Linux for AKS | Other Linux OS |
|--|--|--|--|
| Filesystem | Immutable (read-only) | Immutable (read-only) | Writable (read-write) |
| Focus on | Trusted code execution backed by IPE (Integrity Policy Enforcement) | Multi-cloud, on-prem, Adaptability and sovereignty  | Extensibility, flexibility, and choice |
| Mandatory Access Control | SELinux | SELinux | AppArmor|
| Secure Boot | Supported by default with UKI (Unified Kernel Image) | Not yet supported with AKS | Supported with certain VM sizes |

## Migration to a K8s optimized Linux OS option

If you’d like to migrate to Azure Linux OS Guard (preview) or Flatcar Container Linux for AKS (preview), you’ll want to keep in mind the following limitations and recommendations.

Immutable operating systems, by implication, make large parts of a node’s file system read-only. While Kubernetes workloads in general should not break abstraction and interfere with a node’s OS, the reality is often different. Care must be taken when migrating from general purpose operating systems. We have observed workloads’ expectations not being uniformly upheld on immutable systems particularly with, but not limited to:
-	Any containers that require access to the host filesystem (e.g. via a /host/... mount), in particular init containers and daemonsets.
-	Containers required to run in host PID and / or Networking namespace

Some AKS features may not be supported when using Azure Linux OS Guard (preview) or Flatcar Container Linux for AKS (preview). If you are using a feature that is not supported by the new OS, you will not be able to migrate your existing clusters/node pools. 

When planning to migrate to a K8s optimized OS option, AKS recommends the following:
•	Ensure your workloads configure and run successfully on the new OS in test/dev before migrating any production clusters.
•	If you’d like to migrate existing Linux clusters or node pools to Azure Linux OS Guard (preview), you can use in-place OS Sku migration. There are pre-requisites and limitations to this process, see documentation for details.
•	If you’d like to migrate to Flatcar Container Linux for AKS (preview), you’ll need to create new clusters and/or node pools and migrate existing workloads. Flatcar is available on all AKS supported Kubernetes versions.

## Microsoft contributions to K8s optimized OS options

Microsoft has long-standing contributions to the success of Kubernetes optimized OS options. With internal teams maintaining both Azure Linux OS Guard and Flatcar Container Linux, collaboration in the Immutable Linux community, UAPI group, etc.

-	OS Guard’s research and development excellence with contributions to kernel, system, containerd, and other upstreams to improve the state of trusted execution across the ecosystem
-	Collaboration with other cloud vendors on integrating Flatcar as a first choice OS to run Kubernetes on.
-	Collaboration with other image-based distributions like Fedora CoreOS / Red Hat CoreOS, SUSE MicroOS on foundational software like provisoining-time configuration agents
-	Community collaboration and technical leadership in the CNCF special purpose operating systems working group.
-	Contributions to key OS components like system extensions and the GRUB bootloader to features and improve robustness for image-based immutable Linux distributions
-	Contributions to cloud-native infrastructure projects like accelerated container images / overlaybd, the blob CSI driver, and others, adding features and improving robustness.

### Community Stewardship

AKS is built on community stewarded open source projects. Our continued engagement with projects like Flatcar improves the ecosystem for everybody and also empowers our users and customers to actively engage and participate in both development as well as project stewardship – driving the technology as well as determining the course and direction of these projects.

## Roadmap

We’re excited to continue to extend AKS support for these Kubernetes optimized OS options. Our long-term goals include:
•	In-place updates of OS and Kubernetes: faster, safer, less resource constraining
•	Trusted and Confidential computing, locked-down execution through code signing
•	Making signed execution available to everyone, by means of multiple trust levels and the option for users to use their own signing keys for their workloads

And of course sharing all these achievements with the broader Linux and Kubernetes ecosystem by contributing back and by making building blocks available.

## Questions?
Connect with the AKS and Azure Linux teams and communities through our [GitHub discussions](https://github.com/Azure/AKS/discussions) or share your [feedback and suggestions](https://github.com/Azure/AKS/issues).

To follow along with our backlog and progress, please see our public roadmaps:
-	AKS Public Roadmap
-	Azure Linux roadmap?

To follow along, engage with, and participate in the Flatcar Container Linux open source project, check out:
-	The [Flatcar Container Linux roadmap](https://github.com/orgs/flatcar/projects/7/views/9)
-	[Our participation how-to](https://github.com/flatcar/Flatcar?tab=readme-ov-file#participate-and-contribute)
-	[Chat with us over at Matrix](https://app.element.io/?#/room/#flatcar:matrix.org)
