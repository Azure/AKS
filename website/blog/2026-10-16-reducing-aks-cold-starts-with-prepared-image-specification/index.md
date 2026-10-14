---
title: "Reducing AKS cold starts with Prepared Image Specification"
description: "Learn how Prepared Image Specification can reduce AKS scale-out latency by preparing container images, models, and host customizations before nodes start."
date: 2026-10-16
authors: ["spencer-libbing"]
tags:
  - performance
  - scaling
  - operations
  - gpu
keywords: ["Azure Kubernetes Service", "AKS", "Prepared Image Specification", "PIS", "node scaling", "cold starts"]
---

When an Azure Kubernetes Service (AKS) cluster needs more capacity, creating a virtual machine (VM) is only the beginning. Each new node still has to join the cluster, install host dependencies, pull container images, and start your workload before it can serve traffic.

While new nodes start, workloads wait. To compensate, teams keep spare nodes running, accept slower recovery when demand spikes, or maintain bootstrap scripts that every new node has to rerun.

Prepared Image Specification (PIS) lets you list the container images and host setup scripts that every new node needs, such as a large inference image, a language runtime, or an internal CA bundle. AKS bakes them into a versioned node image once, and new nodes in the pool boot from it instead of repeating that work.

<!-- truncate -->

![Prepared Image Specification reuses prepared container images, host setup, and model assets across new AKS nodes](./hero-image.png)

**Bottom line:** PIS saves roughly the time each new node would otherwise spend pulling images and running setup. The more of that work your nodes do, the more PIS saves. In our tests, it cut a three-node Windows scale-out from 810 seconds to 202 seconds and returned the first token from a GPU model server 26 seconds sooner.

> **Preview notice:** PIS is currently an AKS preview feature. Preview features are opt-in, provided as-is and as-available, and not intended for production use. Review the current prerequisites, regions, limitations, and support policy before using it.

## What PIS does

**Bottom line:** You define what every new node needs once, and AKS prepares it ahead of time so scale-outs skip that work.

A PIS is a versioned Azure resource that lists container images to cache and Bash or PowerShell setup scripts to run. AKS builds a prepared node image from a supported AKS node image, and every new node in a PIS-backed pool boots from it. You don't build or maintain the image yourself.

PIS complements tools you might already use. An image pre-pull DaemonSet or [Artifact Streaming](https://learn.microsoft.com/azure/aks/artifact-streaming) still does its work after each node starts. PIS finishes the work before the node joins the pool, and it covers host setup as well as container images.

The tradeoff is a one-time build. Creating a PIS-backed pool took about 20 to 30 minutes in our tests, compared with about 4 minutes for a standard pool. You pay that cost when the pool is created or moves to a new PIS version, not on every scale-out.

## How much time PIS saves

**Bottom line:** Savings grow with the amount of download and setup work you move into the image. Large images, runtimes, and Windows workloads benefited most; a small image with no setup saw little change.

Each row compares a standard pool and a PIS-backed pool that scaled out at the same time. Times run from the scale request until the workload was running, and are medians except for the GPU row, which uses averages.

| Scenario | What each new node needed | Standard | PIS | Time saved |
| --- | --- | ---: | ---: | ---: |
| Add three Windows nodes | A .NET application image | 810s | 202s | **About 10 minutes (74%)** |
| Add a Windows node with a runtime | A pinned Node.js runtime | 320s | 207s | **About 2 minutes (34%)** |
| Add a Linux node with dependencies | A 512 MiB dependency bundle | 135s | 110s | **28s (20%)** |
| Serve a model on a T4 GPU node | A 2.6 GB inference image and a 2.4 GB model | 484s | 458s | **26s (5%)** |
| Add three Linux nodes | A 90 MB .NET application image | 86s | 82s | **3s (4%)** |

The Windows results stand out because standard Windows nodes sometimes took more than 10 minutes to become ready, and none of the PIS-backed nodes did. When a scale-out adds several nodes, it waits for the slowest one, so PIS avoided that delay in most bursts.

On Linux, the savings tracked the size of the work removed. Skipping a 90 MB image pull saved only a few seconds, while skipping a 512 MiB bundle saved about half a minute. PIS-backed Linux nodes also took a few seconds longer to start, so very small setup tasks can come out even or slightly slower; a small certificate setup was 14% slower in our tests.

For GPU model serving, PIS removed a 95-second image pull. Most of that saving was offset because the prepared model was read from the new node's disk for the first time, which was slower than reading a freshly downloaded copy that was still in memory.

## When to use PIS

**Bottom line:** Use PIS for pools that scale out often and whose new nodes spend more than about half a minute pulling images or running setup.

Good fits include:

- **Large container images**, such as AI inference, data processing, or Windows application images.
- **Runtimes and dependency bundles** that every node installs, such as language runtimes, SDKs, or shared libraries.
- **Windows node pools**, where provisioning and image pulls tend to be slow.
- **Burst scaling**, where waiting for the slowest of several new nodes delays the whole scale-out.

PIS is a poor fit for small images, quick setup, content that changes more often than the pool scales, and pools that rarely scale. Kubernetes upgrades rebuild the prepared image automatically. To pick up new content or a newer AKS node image, create a new PIS version and point the pool at it.

## Get started

**Bottom line:** Start with the images and setup your nodes repeat most, and compare one PIS-backed pool with your current pool.

1. Register the preview and install the `aks-preview` Azure CLI extension.
2. Create a PIS version that lists your digest-pinned container images and setup scripts.
3. Create a node pool that references the PIS version, and compare its scale-out time with your current pool.

The [PIS how-to guide](https://learn.microsoft.com/azure/aks/prepared-image-specification) walks through each step with Azure CLI examples.

## Conclusion

**Bottom line:** PIS turns repeated per-node setup into a one-time build, so pools with large images or heavy setup scale out faster and more predictably.

The benefit is largest for Windows pools, large images, and runtime or dependency installs, and smallest when nodes have little to download. Because PIS is in preview, try it in a nonproduction pool first and follow the [AKS roadmap](https://github.com/orgs/Azure/projects/685) as the feature evolves.

## Resources

- [Prepared Image Specification overview](https://learn.microsoft.com/azure/aks/prepared-image-specification-overview)
- [Create and manage a Prepared Image Specification](https://learn.microsoft.com/azure/aks/prepared-image-specification)
- [Reduce image pull time with Artifact Streaming](https://learn.microsoft.com/azure/aks/artifact-streaming)
- [AKS preview feature support policy](https://learn.microsoft.com/azure/aks/support-policies)
- [AKS roadmap](https://github.com/orgs/Azure/projects/685)
