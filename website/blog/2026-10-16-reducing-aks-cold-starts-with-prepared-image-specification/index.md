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

Have you ever watched your Azure Kubernetes Service (AKS) cluster add nodes right on cue, only to wait several more minutes before any of them could take traffic? Or kept extra nodes running all day so a traffic spike wouldn't leave you waiting on cold starts? If large container images or runtime dependencies are making your scale-outs slow and your bill bigger, this post is for you.

A new virtual machine (VM) is only the start. Each node still has to join the cluster, install whatever your hosts need, pull your container images, and start your workload. With a multi-gigabyte inference image, a Windows app, or a runtime that every node installs at boot, that work adds up quickly, and it repeats on every new node.

The usual workarounds all cost something. You can keep spare nodes running and pay for idle capacity, accept slow recovery when demand jumps, or maintain bootstrap scripts that every new node has to rerun.

Prepared Image Specification (PIS) takes a different approach. You tell AKS which container images and setup scripts your nodes need, such as a large inference image, a language runtime, or an internal CA bundle. AKS bakes them into a versioned node image once, and every new node in the pool boots with that work already done.

<!-- truncate -->

![Prepared Image Specification reuses prepared container images, host setup, and model assets across new AKS nodes](./hero-image.png)

**Bottom line:** PIS saves roughly the time each new node would otherwise spend pulling images and running setup. The more of that work your nodes do, the more PIS saves. In our tests, it cut a three-node Windows scale-out from 810 seconds to 202 seconds and returned the first token from a GPU model server 74 seconds sooner.

> **Preview notice:** PIS is currently an AKS preview feature. Preview features are opt-in, provided as-is and as-available, and not intended for production use. Review the current prerequisites, regions, limitations, and support policy before using it.

## What PIS does

The idea is straightforward: do the slow work once, ahead of time, instead of on every node.

A PIS is a versioned Azure resource with two lists: container images to cache, and Bash or PowerShell setup scripts to run. AKS starts from a supported AKS node image, applies your lists, and produces a prepared node image. Every new node in a PIS-backed pool boots from it. You don't have to build, patch, or host that image yourself.

If you already use an image pre-pull DaemonSet or [Artifact Streaming](https://learn.microsoft.com/azure/aks/artifact-streaming), PIS works alongside them. The difference is timing. Those tools do their work after a node starts, while your workload waits. PIS does it before the node ever joins the pool, and it handles host setup too, not just container images.

There's one tradeoff to plan for: the build. Creating a PIS-backed pool took about 20 to 30 minutes in our tests, compared with about 4 minutes for a standard pool. You pay that once, when you create the pool or move it to a new PIS version. After that, every scale-out benefits.

## How much time PIS saves

Savings grow with the amount of download and setup work you move into the image. Windows pools, runtime installs, and large dependencies benefited most, and PIS made slow Windows scale-outs far less common.

Each comparison scaled a standard pool and a PIS-backed pool at the same time and measured from the scale request until the workload was running. Unless noted, Standard and PIS columns show median (50th percentile) times, and time saved is the difference between them. "Slowest 10%" values are the 90th percentile (p90).

### Scaling out with cached container images

Windows scale-outs were up to 10 minutes faster, and the slowest 10% of Windows scale-outs dropped from about 14 minutes to about 4.

| Scenario | Standard (median) | PIS (median) | Time saved (median) | Slowest 10% (p90) |
| --- | ---: | ---: | ---: | ---: |
| Add three Windows nodes | 810s | 202s | **About 10 minutes (75%)** | 849s vs. 246s (**71% faster**) |
| Add one Windows node | 246s | 190s | **56s (23%)** | 823s vs. 238s (**71% faster**) |
| Add three Linux nodes | 86s | 82s | **4s (5%)** | 104s vs. 98s (**6% faster**) |
| Add one Linux node | 81s | 80s | **1s (1%)** | 104s vs. 94s (**10% faster**) |

These workloads used a .NET application image of 90 MB on Linux and 171 MB on Windows. PIS removed almost all of the image pull time, about 10 seconds on Linux and 20 seconds on Windows.

The larger Windows gains came from more predictable node startup. Standard Windows nodes sometimes took more than 10 minutes to become ready, and none of the PIS-backed nodes did. A multi-node scale-out waits for its slowest node, so avoiding that delay is why the three-node Windows result is so large.

On Linux, a 90 MB image takes only a few seconds to pull, so the median saving was small. In the slowest 10% (p90) of Linux scale-outs, PIS finished 6 to 10 seconds sooner. Larger images and setup tasks, shown below, produce larger Linux savings.

### Preparing runtimes and dependencies

Moving installs into the image saved up to 2 minutes per Windows node and up to 25 seconds per Linux node.

| Setup task | Standard (median) | PIS (median) | Time saved (median) |
| --- | ---: | ---: | ---: |
| Install a Node.js runtime on Windows | 320s | 207s | **About 2 minutes (35%)** |
| Install a certificate and security policy on Windows | 254s | 198s | **56s (22%)** |
| Install a 512 MiB dependency bundle on Windows | 252s | 242s | **10s (4%)** |
| Install a 512 MiB dependency bundle on Linux | 135s | 110s | **25s (19%)** |
| Install a Node.js runtime on Linux | 123s | 107s | **16s (13%)** |

Windows installs take longer at node startup, so baking them into the image saved the most time. On Linux, the saving grew with the size of the download: the 512 MiB dependency bundle saved more time than the smaller runtime.

### Scaling out ten Linux nodes with a large image and setup

When each new Linux node had to pull a 5.7 GB machine learning image and install a Node.js runtime and a 512 MiB dependency bundle, PIS had all 10 workloads running about 3.5 minutes sooner at the median.

| Scenario | Standard (median) | PIS (median) | Time saved (median) | Slowest 10% (p90) |
| --- | ---: | ---: | ---: | ---: |
| Add ten Linux nodes, all workloads running | 315s | 104s | **About 3.5 minutes (67%)** | 338s vs. 115s (**66% faster**) |

Nodes became ready in about the same time on both pools. The difference came from what happened next: standard nodes spent about 3 minutes pulling the image and 45 seconds on setup, while PIS-backed nodes had the image already present and finished setup in about 4 seconds.

### Serving a model on a GPU node

For a T4 GPU model server, PIS returned the first token 74 seconds sooner on average by preloading a 2.6 GB inference image and a 2.4 GB model.

| Outcome | Standard (average) | PIS (average) | Time saved (average) |
| --- | ---: | ---: | ---: |
| Model ready to serve | 466s | 390s | **76s** |
| First token returned | 499s | 425s | **74s** |

With the inference image already on the node, the model server container started without waiting for a multi-gigabyte pull. Files in a prepared image are fetched from storage the first time they're read, so read large model files in parallel before the model server starts. That loads the model into memory faster than letting the server read it on demand.

## When to use PIS

So is PIS a good fit for your pool? A useful rule of thumb: if the pool scales out often and each new node spends more than about half a minute pulling images or running setup, it's worth trying.

Good fits include:

- **Large container images**, such as AI inference, data processing, or Windows application images.
- **Runtimes and dependency bundles** that every node installs, such as language runtimes, SDKs, or shared libraries.
- **Windows node pools**, where provisioning and image pulls tend to be slow.
- **Burst scaling**, where waiting for the slowest of several new nodes delays the whole scale-out.

On the other hand, if your images are small, setup is quick, your content changes more often than the pool scales, or the pool rarely scales at all, you probably won't notice much difference.

Once a pool uses PIS, keeping it current is mostly hands-off. Kubernetes upgrades rebuild the prepared image for you. When you want new content or a newer AKS node image, create a new PIS version and point the pool at it.

## How to adopt PIS

The easiest way to see what PIS does for your workload is to run it side by side with a pool you already have.

1. **Pick what to prepare.** Start with the largest images and the setup steps every new node repeats.
2. **Create a PIS version.** List digest-pinned container images and any setup scripts.
3. **Create a PIS-backed node pool.** Reference the PIS version, scale it alongside your current pool, and compare how long workloads take to start.
4. **Expand carefully.** While PIS is in preview, keep it to nonproduction pools. Point more of them at the tested version, and create a new version when your images or scripts change.

Register the preview feature:

```bash
az feature register --namespace Microsoft.ContainerService --name AKSPreparedImageSpecificationPreview
```

Registration can take a few minutes. Rerun this command until it prints `Registered`:

```bash
az feature show --namespace Microsoft.ContainerService --name AKSPreparedImageSpecificationPreview --query properties.state --output tsv
```

Then refresh the resource provider and install the `aks-preview` extension:

```bash
az provider register --namespace Microsoft.ContainerService
az extension add --name aks-preview --upgrade
```

Create a PIS version that caches an image, then add a node pool that uses it. This example uses a public image. To cache images from a private registry such as Azure Container Registry (ACR), the PIS build needs its own access: create a user-assigned managed identity, grant it the `AcrPull` role on the registry, and pass it to `az aks prepared-image-specification create` with `--assign-identity`. The [PIS how-to guide](https://learn.microsoft.com/azure/aks/prepared-image-specification) lists the full permissions.

```bash
RESOURCE_GROUP="my-resource-group"
CLUSTER_NAME="my-aks-cluster"
PIS_NAME="my-pis"

az aks prepared-image-specification create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PIS_NAME" \
  --version v1 \
  --location "$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --query location --output tsv)" \
  --container-images "mcr.microsoft.com/dotnet/samples:aspnetapp@sha256:<digest>"

PIS_VERSION_ID=$(az aks prepared-image-specification version show \
  --resource-group "$RESOURCE_GROUP" \
  --pis-name "$PIS_NAME" \
  --name v1 \
  --query id \
  --output tsv)

az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name pispool \
  --prepared-image-specification-id "$PIS_VERSION_ID"
```

To also bake in runtimes, dependencies, or certificates, add setup scripts with `--customization-scripts`. The how-to guide covers scripts in detail.

## Conclusion

Slow cold starts don't have to be the price you pay for scaling. With PIS, the slow, repetitive part of node startup happens once, in a build, instead of on every new node, so nodes show up ready to work.

If your pools carry large images, run Windows workloads, or repeat the same setup on every node, try PIS in a nonproduction pool and see how much time you get back. It's still in preview, so keep an eye on the [AKS roadmap](https://github.com/orgs/Azure/projects/685) as the feature evolves.

## Resources

- [Prepared Image Specification overview](https://learn.microsoft.com/azure/aks/prepared-image-specification-overview)
- [Create and manage a Prepared Image Specification](https://learn.microsoft.com/azure/aks/prepared-image-specification)
- [Reduce image pull time with Artifact Streaming](https://learn.microsoft.com/azure/aks/artifact-streaming)
- [AKS preview feature support policy](https://learn.microsoft.com/azure/aks/support-policies)
- [AKS roadmap](https://github.com/orgs/Azure/projects/685)
