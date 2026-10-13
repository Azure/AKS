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

When an Azure Kubernetes Service (AKS) cluster needs more capacity, creating a virtual machine (VM) is only the beginning. The node still has to join the cluster, become Ready, prepare its host dependencies, pull container images, and start a workload before it can serve traffic.

That delay has a customer cost. Teams often keep extra nodes running to absorb bursts, accept slower recovery when demand changes, or build complex bootstrap automation that every new node must repeat.

Prepared Image Specification (PIS) moves stable, repeated preparation into an AKS-managed node image. Container images and host customizations are prepared once, versioned, and reused by a node pool. New nodes still have to be created and join the cluster, but they can avoid repeating much of the work between node creation and workload readiness.

<!-- truncate -->

![Prepared Image Specification reuses prepared container images, host setup, and model assets across new AKS nodes](./hero-image.png)

In our controlled comparisons of otherwise-equivalent standard and PIS-backed pools, the strongest result was a Windows burst that added three nodes: median time to start all three workloads fell from 810 seconds to 202 seconds, a **74%** reduction. For a T4 graphics processing unit (GPU) model-serving pool, PIS returned the first token **26 seconds sooner on average** across 54 paired scale-outs. Not every scenario improved, and the results section explains where the time went.

> **Preview notice:** PIS is currently an AKS preview feature. Preview features are opt-in, provided as-is and as-available, and not intended for production use. Review the current prerequisites, regions, limitations, and support policy before testing it.

## What Prepared Image Specification changes for customers

A PIS is an AKS-managed, versioned Azure resource that describes container images and Bash or PowerShell customizations to include in a prepared AKS node image. AKS builds on a supported AKS node image; this is not a bring-your-own-image workflow.

The tradeoff is timing: spend preparation time and operational effort when a PIS-backed pool is created or updated, then avoid repeating the same downloads and initialization during later scale-outs.

| Customer goal | How PIS helps |
| --- | --- |
| Respond to demand sooner | New nodes can start with large image layers and stable host dependencies already present. |
| Reduce warm-capacity pressure | A faster, more predictable scale-out path may let a team hold fewer idle nodes solely as a cold-start buffer. |
| Eliminate repeated bootstrap work | Build stable host setup into a reusable image instead of running it again on every new node. |

PIS does not remove VM allocation, node registration, networking, scheduling, driver initialization, or application startup. Its value depends on how much of the customer-visible delay comes from work that can be prepared ahead of time.

## What the results mean for customers

The table separates the customer-visible outcomes. Reductions mean the PIS-backed path completed sooner; the final row shows the one median regression. The Standard and PIS columns show each pool's median time, or mean time for the GPU row, so you can see the size of each change.

<!-- markdownlint-disable MD033 -->

| Scenario | Customer-visible outcome | Standard | PIS | Improvement |
| --- | --- | ---: | ---: | ---: |
| Add three Windows nodes | All three workloads started on distinct new nodes | 810s | 202s | **74% at median**<br />**78% at p90** |
| Add one Windows node | Workload started on the new node | 246s | 190s | **27% at median**<br />**77% at p90** |
| Add three Linux nodes | All three workloads started on distinct new nodes | 86s | 82s | **4% at median**<br />**24% at p90** |
| Add one Linux node | Workload started on the new node | 81s | 80s | **3% at median**<br />**28% at p90** |
| Large image pulls during a three-node burst | Slowest new-node pull completed | Linux: 11s<br />Windows: 22s | Linux: under 1s<br />Windows: under 1s | **92% at Linux median**<br />**98% at Windows median** |
| Install a pinned portable runtime | Runtime verified and workload started | Linux: 123s<br />Windows: 320s | Linux: 107s<br />Windows: 207s | **10% at Linux median**<br />**34% at Windows median** |
| Prepare a large dependency bundle | Dependencies verified and workload started | Linux: 135s<br />Windows: 252s | Linux: 110s<br />Windows: 242s | **20% at Linux median**<br />**5% at Windows median** |
| Serve a model on a T4 GPU node | Model healthy and first token returned | First token: 484s<br />Model ready: 451s<br />First token p95: 511s | First token: 458s<br />Model ready: 425s<br />First token p95: 517s | **26 seconds sooner on average**<br />**Similar at p95** |
| Apply a small Linux certificate authority (CA) and policy setup | Setup verified and workload started | 127s | 144s | **14% slower at median**<br />**Tail latency favored PIS** |

<!-- markdownlint-enable MD033 -->

### How to read these results

Each result compares matched standard and PIS-backed pools. The timer starts with the scale request and stops at the outcome in the table; PIS creation and initial pool setup are not included. Percentages are the median or p90 of same-round improvements, while the Standard and PIS columns show each pool's own median, so the two can differ slightly. The GPU row uses means because its 54 pairs support confidence intervals. Times are rounded to whole seconds.

Image tests used 100 same-round pairs per operating system, customization tests used 10 same-round pairs per cell, and the GPU test used 54 pairs in which scale requests were issued concurrently to two matched clusters, each scaling from one to two nodes. VM size, AKS node image, networking, artifacts, and workload were held constant.

The customization and GPU preparation checks ran through Azure VM Run Command, whose status was polled about every 30 seconds, so those steps have roughly 30-second resolution. The GPU test also recorded timestamps on the node to measure the model check precisely. Treat the 10-pair customization results, including their medians, as directional.

These are controlled observations, not service-level objectives. The tests did not measure cost savings, production traffic, autoscaler decisions, cross-region variation, throughput, upgrades, or long-lived drift.

Preparation also has a one-time cost. Creating a PIS-backed pool took about 22 minutes at the median for the customization pools and 30 minutes for the GPU pool, compared with about 4 minutes for the standard GPU pool. That time is spent when the pool is created or its prepared image is rebuilt, not on each scale-out.

### Where the time went

**Linux.** PIS removed about 10 seconds of image pull time, but PIS-backed Linux nodes reached Ready 2 to 12 seconds later at the median across the Linux tests, so the net gain was small. In the small CA and policy setup, the setup check took the same time on both pools, so the later node readiness made PIS 14% slower. On Linux, the prepared work has to save more time than this startup difference.

**Windows.** Most of the Windows saving occurred before the node reported Ready, not in image pulls, which saved about 20 seconds. In the single-node test, about 30% of standard Windows nodes took more than 10 minutes to become Ready; no PIS-backed node did. A three-node burst waits for its slowest node, so about two-thirds of standard bursts included at least one such node. That is why the three-node median improved by 74% while the single-node median improved by 27%, and why it is close to the single-node p90 of 77%. We didn't isolate why standard Windows nodes sometimes took this long, so validate this behavior with your own node image and VM size. For the Windows dependency bundle, the standard install-and-verify check and the PIS verify-only check finished in the same polling interval, so the download removed was small at this resolution.

**GPU.** In each pair, the standard node downloaded and hash-verified the model and pulled the pinned container image. The PIS-backed node verified the same model from its prepared image and used the preloaded container image. Both paths then loaded the model and served the same inference request.

| Stage (mean) | Standard | PIS | Difference |
| --- | ---: | ---: | --- |
| Scale request to GPU allocatable | 219s | 214s | PIS 5s sooner |
| GPU allocatable to model check finished | 99s | 161s | PIS 62s longer |
| Model check finished to container started | 106s | 12s | PIS 95s sooner |
| Container started to model ready | 27s | 38s | PIS 11s longer |
| Model ready to first token | 33s | 34s | About the same |
| **Scale request to first token** | **484s** | **458s** | **PIS 26s sooner** |

The preloaded container image saved 95 seconds, but PIS gave back much of that time in two later stages. Timestamps recorded on the nodes show why. The standard node downloaded the 2.4 GB model in 58 seconds and then hash-verified it in 2 seconds, because the file it had just written was still in memory. The PIS-backed node only had to verify the prepared model, but that check took 115 seconds, about 21 MB per second, because it was the first read of that data from the new node's disk. The model also took 11 seconds longer to load on the PIS-backed node. Time to GPU allocatable was similar for both pools.

The 95% confidence intervals for the paired mean savings were 17 to 36 seconds for model readiness and 16 to 35 seconds for first token, and PIS returned the first token sooner in 43 of 54 pairs. At p95, the two pools were within 6 seconds of each other.

For large models, measure each stage rather than only the total. On this path, the first read of the prepared model was the largest remaining cost. Avoiding a full re-hash of a model that was already verified during the image build, or reading the model before the workload needs it, could recover much of that time.

## When to use PIS

Start with work that every new node repeats and that can be completed before the node joins a pool. A strong candidate is:

- **Stable:** It changes less often than the pool scales.
- **Material:** Its download or installation time is large enough to outweigh any slower node startup you measure.
- **Deterministic:** Its inputs can be versioned, pinned, and verified.

Large, digest-pinned images, portable runtimes, dependency bundles, security tools, and immutable model artifacts can fit this profile. Keep frequently changing, node-specific, or inexpensive setup on the normal startup path.

For GPU pools, measure the operating event that matters to the workload. Teams that reserve scarce GPU capacity might care more about planned upgrades or node replacement than routine scale-out. During a supported Kubernetes upgrade, AKS rebuilds the prepared node image for the referenced PIS version so replacement nodes still receive its specified images and customizations. This benchmark covered scale-out through the first successful inference; it did not measure upgrade duration or replacement disruption. Validate the target PIS and node image versions in a matched nonproduction pool, then measure until the replacement workload serves a representative request.

## How to adopt PIS

1. **Record a control path.** Measure image pulls, host setup, node readiness, workload readiness, and any model-serving milestones on a standard pool.
2. **Choose one preparation target.** Start with a stable image or dependency that contributes materially to that path.
3. **Create a versioned PIS.** Pin image digests, verify downloaded artifacts, and record exactly what the version contains.
4. **Create a matched nonproduction pool.** Keep the VM size, AKS node image, networking, and workload equal to the control pool.
5. **Repeat the same scale event.** Stop the clock when the workload can serve a representative request, not when infrastructure creation returns.
6. **Promote the tested version.** Update pools deliberately and retain a standard path for comparison and rollback.

### Create and attach a PIS

After registering the preview and configuring registry access and role-based access control (RBAC), create a version with pinned images, get its resource ID, and reference it from a node pool. See the [PIS how-to](https://learn.microsoft.com/azure/aks/prepared-image-specification) for current prerequisites and feature-registration steps.

```bash
az extension add --name aks-preview --upgrade

RESOURCE_GROUP="my-resource-group"
PIS_NAME="my-pis"
PIS_VERSION="v1"
CLUSTER_NAME="my-aks-cluster"

LOCATION=$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --query location \
  --output tsv)

cat >scripts.json <<'JSON'
[
  {
    "name": "install-bootstrap",
    "script": "#!/usr/bin/env bash\nset -euo pipefail\nmkdir -p /opt/example\nprintf '%s\\n' 'v1' >/opt/example/version",
    "scriptType": "Bash",
    "executionPoint": "NodeImageBuildTime",
    "postScriptAction": "None"
  }
]
JSON

az aks prepared-image-specification create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PIS_NAME" \
  --version "$PIS_VERSION" \
  --location "$LOCATION" \
  --container-images "myacr.azurecr.io/model-server@sha256:<digest>" \
  --customization-scripts @scripts.json

PIS_VERSION_ID=$(az aks prepared-image-specification version show \
  --resource-group "$RESOURCE_GROUP" \
  --pis-name "$PIS_NAME" \
  --name "$PIS_VERSION" \
  --query id \
  --output tsv)

az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name userpool \
  --prepared-image-specification-id "$PIS_VERSION_ID"
```

For Windows, use PowerShell and set `scriptType` to `PowerShell`. Keep secrets out of scripts and use managed identity with data-plane RBAC for private registries and artifacts.

## Conclusion

PIS is most useful when new nodes repeatedly pull large images, fetch models, or run stable host setup before workloads can serve. It shifts that work to a versioned image build so later scale-outs can be faster and more predictable. PIS doesn't remove every cold-start stage, so measure the full customer path and optimize the remaining bottleneck. Because PIS is in preview, validate it in matched nonproduction pools and follow the [AKS roadmap](https://github.com/orgs/Azure/projects/685) as the feature evolves.

## Resources

- [Prepared Image Specification overview](https://learn.microsoft.com/azure/aks/prepared-image-specification-overview)
- [Create and manage a Prepared Image Specification](https://learn.microsoft.com/azure/aks/prepared-image-specification)
- [AKS preview feature support policy](https://learn.microsoft.com/azure/aks/support-policies)
- [AKS roadmap](https://github.com/orgs/Azure/projects/685)
