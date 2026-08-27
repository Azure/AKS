---
title: "Reducing AKS Cold Starts with Prepared Image Specification"
description: "Learn how Prepared Image Specification can reduce AKS scale-out latency by preparing container images and host customizations ahead of time."
date: 2026-08-27
authors: ["spencer-libbing"]
tags:
  - performance
  - scaling
  - operations
  - gpu
keywords: ["Azure Kubernetes Service", "AKS", "Prepared Image Specification", "PIS", "node scaling", "cold starts"]
---

When an Azure Kubernetes Service (AKS) cluster needs more capacity, creating a virtual machine is only the beginning. The node still has to join the cluster, become Ready, prepare its host dependencies, pull container images, and start a workload before it can serve traffic.

That delay has a customer cost. Teams often keep extra nodes running to absorb bursts, accept slower recovery when demand changes, or build complex bootstrap automation that every new node must repeat.

Prepared Image Specification (PIS) moves stable, repeated preparation into an AKS-managed node image. Container images and host customizations are prepared once, versioned, and reused by a node pool. New nodes still have to be created and join the cluster, but they can avoid repeating much of the work between node creation and workload readiness.

<!-- truncate -->

In our controlled comparisons, the strongest end-to-end result was a Windows burst that added three nodes: PIS reduced median time to start all three workloads by **74%**. PIS also reduced the median slowest image pull by **92% on Linux** and **98% on Windows**. For a T4 GPU model-serving pool, median model-ready and first-token latency improved by about **3%**, while p95 latency improved by about **14%** and **13%**, respectively.

> **Preview notice:** PIS is currently an AKS preview feature. Preview features are opt-in, provided as-is and as-available, and not intended for production use. Review the current prerequisites, regions, limitations, and support policy before testing it.

## What PIS changes for customers

A PIS is an AKS-managed, versioned Azure resource that describes container images and Bash or PowerShell customizations to include in a prepared AKS node image. AKS builds on a supported AKS node image; this is not a bring-your-own-image workflow.

The feature creates a practical trade: pay a reusable preparation cost when a PIS-backed pool is created or updated, then avoid repeating the same downloads and initialization during later scale-outs.

| Customer goal | How PIS helps |
| --- | --- |
| Respond to demand sooner | New nodes can start with large image layers and stable host dependencies already present. |
| Reduce warm-capacity pressure | A faster, more predictable scale-out path may let a team hold fewer idle nodes solely as a cold-start buffer. |
| Make bootstrap repeatable | Versioned preparation replaces repeated best-effort downloads and installation on every new node. |
| Improve rollout control | A node pool references an exact PIS version, making prepared state explicit and testable. |
| Protect private dependencies | Managed identity and data-plane RBAC can retrieve private artifacts without embedding keys or SAS tokens in scripts. |

PIS does not remove VM allocation, node registration, networking, scheduling, driver initialization, or application startup. Its value depends on how much of the customer-visible delay comes from work that can be prepared ahead of time.

## What the results mean for customers

The following results summarize latency reduction rather than raw test times. Positive percentages mean the PIS-backed path reached the measured outcome sooner than the same-round standard path.

| Scenario | Customer-visible outcome | Observed latency reduction |
| --- | --- | ---: |
| Add three Windows nodes | All three workloads started on distinct new nodes | **74% at median; 78% at p90** |
| Add one Windows node | Workload started on the new node | **27% at median; 77% at p90** |
| Add three Linux nodes | All three workloads started on distinct new nodes | **4% at median; 24% at p90** |
| Large image pulls during a three-node burst | Slowest new-node pull completed | **92% at Linux median; 98% at Windows median** |
| Install a pinned portable runtime | Runtime verified and workload started | **10% at Linux median; 34% at Windows median** |
| Prepare a large dependency bundle | Dependencies verified and workload started | **20% at Linux median; 5% at Windows median** |
| Serve a model on a T4 GPU node | Model healthy and first token returned | **3% at median; 14% at p95** |

Most entries use same-round paired reductions. The GPU p95 percentages compare the standard and PIS treatment-distribution p95 values.

The pattern matters more than any single number:

- **Windows gained the most.** Large Windows image and startup costs created more repeated work for PIS to remove, especially during multi-node bursts.
- **Tail latency often improved more than the median.** PIS made the slowest scale-out events less severe even when the typical Linux event changed only slightly.
- **Large, stable preparation paid off.** Image layers, a portable runtime, and a large dependency bundle were useful candidates because every standard node otherwise repeated the work.
- **GPU gains were real but smaller at the median.** Preloading the model and server image helped, but GPU VM creation, node registration, accelerator readiness, scheduling, and model initialization still dominated much of the end-to-end path.

Not every task should be baked. A small Linux CA-and-policy setup was **14% slower at the median** in this test, even though its tail favored PIS. For small tasks, normal scale-out variation and other provisioning stages can outweigh the preparation that PIS removes.

## Serve burst traffic sooner

The clearest customer benefit appears when several nodes must become useful at once. Without preparation, every node may download the same large layers or dependencies concurrently. Registry throughput, storage throughput, and host initialization can all extend the event.

PIS moves that repeated work out of the burst path. In the three-node Windows comparison, this reduced median workload-start latency by 74%. For services with a strict scale-out SLO, that changes the capacity conversation from "How many idle nodes do we need?" to "How quickly can prepared capacity serve traffic?"

Faster scale-out does not automatically produce a bill reduction. The cost opportunity comes from using the measured latency profile to safely reduce warm capacity that exists only to hide cold starts.

## Make node bootstrap repeatable

Many node pools need more than a container image. They may require a portable runtime, policy files, CA certificates, model files, security tools, or other host-level dependencies.

Running that setup on every new node adds external dependencies to the critical path. A download endpoint can throttle, a package can change, or an install can fail halfway through. PIS lets teams prepare immutable inputs ahead of time and bind a pool to a version that has already been built.

Good candidates share three properties:

1. **Stable:** The content changes less often than the pool scales.
2. **Material:** Download or installation is large enough to affect readiness.
3. **Deterministic:** Inputs can be versioned, pinned, and verified.

Create a new PIS version when a dependency changes. Pin container image digests and verify downloaded artifacts with a cryptographic hash. For private dependencies, use managed identity and least-privilege data-plane RBAC instead of placing credentials in customization content.

## Prepare model-serving nodes

GPU nodes are expensive warm capacity, which makes scale-out latency especially relevant. PIS can prepare both a pinned inference-server image and an immutable model artifact before a GPU node enters the recurring scale path.

In our T4 comparison, PIS reduced median model-ready and first-token latency by about 3%. The p95 treatment latency was about 14% lower for model readiness and 13% lower for first token. This is a useful, measured improvement, but it is not a reason to assume that every AI workload will see a dramatic median change.

The customer metric should be time to serve traffic, not merely time until a node reports Ready. Include accelerator availability, model health, and the first successful inference in the readiness objective. Larger models, slower artifact delivery, or different GPU SKUs may shift how much of that path PIS can remove.

## Adopt PIS with a controlled rollout

1. **Find repeated cold-start work.** Measure image pulls, host setup, model delivery, node readiness, and workload readiness separately.
2. **Choose stable inputs.** Start with a large, digest-pinned image or an immutable dependency that changes less often than the pool scales.
3. **Build a versioned PIS.** Treat the PIS version as a release artifact and record exactly what it contains.
4. **Create a nonproduction PIS-backed pool.** Keep the VM size, AKS node image, networking, and workload equal to a standard control pool.
5. **Measure the customer endpoint.** Stop the clock when the workload can serve a representative request, not when infrastructure creation returns.
6. **Roll forward deliberately.** Validate each new PIS version before updating additional pools, and retain a tested standard path for comparison and rollback.

## Try PIS

After registering the preview and configuring registry access and RBAC, create a version with pinned images, get its resource ID, and reference it from a node pool. See the [PIS how-to](https://learn.microsoft.com/azure/aks/prepared-image-specification) for current prerequisites and feature-registration steps.

```bash
RESOURCE_GROUP=<your-resource-group>
LOCATION=<azure-region>
PIS_NAME=<your-pis-name>
PIS_VERSION=v1
CLUSTER_NAME=<your-aks-cluster-name>

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
  --container-images myacr.azurecr.io/model-server@sha256:<digest> \
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
  --pis-id "$PIS_VERSION_ID"
```

For Windows, use PowerShell and set `scriptType` to `PowerShell`. Keep secrets out of scripts and use managed identity with data-plane RBAC for private registries and artifacts.

## How to read these results

We compared standard and PIS-backed pools with the same VM size, AKS node image, networking, pinned artifacts, and workload. Image-caching tests used 100 rounds per arm. Customization and GPU scenarios used 10 same-round pairs per reported cell. Pilots and failed attempts were excluded from measured denominators.

Percentages are reductions in elapsed latency from the scale request to the stated workload outcome. PIS creation and initial prepared-pool setup are separate release-time costs and are not included in recurring scale-out percentages.

The image and customization tests ran in East US 2, and the GPU test ran in West US 3. All used AKS 1.35.7. The scenarios used one VM size per operating system and one T4 GPU size with one quantized model. Treat the smaller-sample tail results as directional rather than production SLO estimates.

These tests measured latency, not bill savings, production traffic, autoscaler decision time, cross-region variation, steady-state inference throughput, or long-lived node drift. Benchmark the complete path and workload mix that your application uses.

## Bottom line

PIS is most useful when cold-start work is large, stable, and repeated. It can help burst capacity serve traffic sooner, reduce pressure to maintain idle warm nodes, and make host preparation more deterministic and versionable.

The results also provide a useful boundary: PIS removes work that can be prepared, not the entire node-provisioning path. Start with a workload whose image, model, or dependencies materially affect readiness, measure the customer endpoint, and use the observed median and tail improvements to decide whether the feature changes your capacity plan.

- [Prepared Image Specification overview](https://learn.microsoft.com/azure/aks/prepared-image-specification-overview)
- [Create and manage a Prepared Image Specification](https://learn.microsoft.com/azure/aks/prepared-image-specification)
- [AKS preview feature support policy](https://learn.microsoft.com/azure/aks/support-policies)