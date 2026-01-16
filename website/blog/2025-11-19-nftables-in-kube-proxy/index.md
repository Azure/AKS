---
title: "Preview: nftables support for kube-proxy in Azure Kubernetes Service (AKS)"
description: "Learn about how to use the nftables mode of kube-proxy on AKS."
date: 2025-11-19
authors: [jack-ma]
tags:
  - networking
---

We're announcing the preview availability of **nftables** mode for kube-proxy in Azure Kubernetes Service (AKS). This feature was requested in [GitHub issue #5061](https://github.com/Azure/AKS/issues/5061) and is now aligned with the upstream Kubernetes GA release of the nftables backend.

<!-- truncate -->

## Background

Kubernetes 1.33 introduced **nftables** as a fully supported kube-proxy mode. It serves as the modern replacement for iptables, offering a more efficient rule model and improved performance characteristics on newer Linux kernels. As highlighted by the upstream project, nftables reduces rule churn and avoids the scaling and latency limitations seen in large clusters using iptables.

Unlike iptables, which implements the ruleset in an O(n) manner that slows down processing as the number of services grows, nftables utilizes a structure with a roughly O(1) map lookup. As a result, packet processing time is more or less constant regardless of cluster size, and the best/average/worst cases are very similar:

![kube-proxy nftables first packet latency at various percentiles in clusters of various sizes](nftables-only.svg)

In clusters with 5,000 and 10,000 Services, the p50 (average) latency for nftables is approximately the same as the p01 (best-case) latency for iptables. In the 30,000 Service cluster, the p99 (worst-case) latency for nftables manages to beat the p01 latency for iptables by a few microseconds! Here's both sets of data together, though you may have to squint to see the nftables results:

![kube-proxy iptables vs nftables first packet latency at various percentiles in clusters of various sizes](iptables-vs-nftables.svg)

For additional context, see the upstream GA announcement: [Kubernetes blog: NFTables mode for kube-proxy](https://kubernetes.io/blog/2025/02/28/nftables-kube-proxy/).

## What's available in AKS

AKS now exposes nftables through the **kube-proxy configuration preview feature**. You can configure kube-proxy in one of three modes:

- `IPTABLES`
- `IPVS`
- `NFTABLES` *(new – preview)*

This configuration is applied through `--kube-proxy-config` during cluster creation or update.

Example:

```json
{
  "enabled": true,
  "mode": "NFTABLES"
}
```

## Enabling the preview

1. Install the latest `aks-preview` CLI extension.  
2. Register the `KubeProxyConfigurationPreview` feature flag.  
3. Create or update your cluster with the nftables kube-proxy configuration.

Full details are in the updated documentation: [Configure kube-proxy in AKS](https://learn.microsoft.com/azure/aks/configure-kube-proxy).

## Notes for operators

- Switching kube-proxy modes may cause brief disruptions as rules are reprogrammed.  

## Feedback

We encourage you to try the feature in non-production clusters and share feedback in the original GitHub thread:  
[GitHub issue #5061](https://github.com/Azure/AKS/issues/5061)
