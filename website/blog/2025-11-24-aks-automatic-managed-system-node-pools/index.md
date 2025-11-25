---
title: "Announcing AKS Automatic managed system node pools (preview)"
description: "Discover how AKS Automatic now offers Microsoft-managed system node pools so you can ship apps faster with zero infrastructure overhead, built-in add-on reliability, and optimized costs."
date: 2025-11-24
authors: [ahmed-sabbour]
tags:
  - aks-automatic
  - managed-system-node-pools
keywords: ["AKS", "Kubernetes", "Automatic", "Managed system node pools"]
---

 We built Azure Kubernetes Service (AKS) Automatic so teams can ship applications with production-grade defaults from day one. Today we're taking that vision further with **managed system node pools (preview)**: the system pool is now fully managed by AKS, with core platform components hosted on Microsoft infrastructure.

<!-- truncate -->

> Learn more in the official documentation: [Managed system node pools on AKS Automatic (preview)](https://learn.microsoft.com/azure/aks/automatic/aks-automatic-managed-system-node-pools-about)

## Why it matters

- **Reduced operational overhead:** AKS handles provisioning, patching, upgrades, and scaling for the system pool, so you spend less time on infrastructure maintenance.
- **Managed add-on hosting at lower cost:** Core services like Azure Monitor agents, CoreDNS, KEDA, VPA, Konnectivity, Eraser, and Metrics Server run on Microsoft-owned infrastructure. Some add-ons and `DaemonSets` still run on nodes in your subscription.
- **Built-in security policies:** Deployment Safeguards enforce pod security standards, restrict access to platform namespaces, and block risky configurations by default.
- **Automatic upgrades:** AKS keeps platform components current, reducing the risk of running outdated or vulnerable system software.

## How managed system node pools differ from traditional system node pools

| Aspect | AKS Standard system pool | AKS Automatic managed system pool |
| --- | --- | --- |
| **Provisioning** | You create the pool, select VM SKUs, set node count, and configure OS disk size | AKS provisions and sizes the pool for you automatically |
| **Capacity planning** | You estimate headroom for system components like CoreDNS, konnectivity, metrics-server, and any add-ons; scale manually or configure cluster autoscaler with min/max counts | AKS right-sizes capacity for platform components and scales automatically when add-ons need more room |
| **Cost** | System nodes are billed as standard VMs to your subscription; you pay for system pool capacity | System nodes do not run on your subscription |

## Components running on managed system node pools

AKS manages the following platform components on the managed system node pool. You don't need to provision capacity for these services:

| Component | Description |
| --- | --- |
| [Azure Monitor](https://learn.microsoft.com/azure/aks/monitor-aks) | Collects logs, metrics, and Kubernetes state for observability dashboards and alerts |
| [CoreDNS](https://learn.microsoft.com/azure/aks/coredns-custom) | Provides cluster DNS resolution for service discovery |
| [Eraser](https://learn.microsoft.com/azure/aks/image-cleaner) | Removes unused and vulnerable container images from nodes |
| [KEDA](https://learn.microsoft.com/azure/aks/keda-about) | Scales workloads based on event-driven metrics such as queue length or HTTP traffic |
| Konnectivity | Maintains secure connectivity between the control plane and nodes |
| [Metrics Server](https://learn.microsoft.com/azure/aks/monitor-aks-reference) | Exposes resource metrics for Horizontal Pod Autoscaler and kubectl top |
| [VPA](https://learn.microsoft.com/azure/aks/vertical-pod-autoscaler) | Recommends and applies optimal CPU and memory requests for pods |
| [Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview) | Enables pods to authenticate to Azure services using Microsoft Entra ID |

Other add-ons and extensions run on `aks-system-surge` nodes, with scaling handled by [Node Auto-Provisioning (NAP)](https://learn.microsoft.com/azure/aks/node-auto-provisioning). `DaemonSets` run on both managed system node pools and nodes in your subscription.

## Guardrails for security and reliability

Security misconfigurations are a leading cause of container breaches. AKS Automatic addresses this by enforcing [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) that validate every workload against the [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) before it reaches your cluster. Baseline policies block dangerous privilege escalations while restricted policies enforce maximum hardening. Compliance flows into Azure Policy dashboards automatically.

These policies also improve workload reliability. Resource limits prevent runaway containers from starving neighbors. Health probes ensure traffic reaches only healthy pods. Anti-affinity rules spread replicas across failure domains. `PodDisruptionBudget` validation keeps node maintenance on schedule.

Since AKS manages the system node pool on your behalf, additional restrictions protect platform stability. User workloads cannot run on the managed system node pool and all create, update, and delete operations on managed system pool resources are denied, as are pod `exec` and `attach` operations.

**Preventing container escapes:** Blocking privileged containers, host namespaces, host ports, and hostPath volumes keeps security incidents contained to a single workload rather than spreading across the cluster.

**Reducing attack surface:** Restricting Linux capabilities to a minimal set means processes run with only the permissions they need. Fewer capabilities translate directly to fewer exploitation opportunities.

**Enforcing least privilege:** Requiring containers to run as non-root and disabling privilege escalation limits the blast radius of any vulnerability.

**Maintaining kernel protections:** Seccomp, AppArmor, and SELinux profiles filter system calls and confine container behavior. Policies ensure these protections stay active.

**Enabling safe cluster operations:** Limiting sysctls to safe parameters and protecting node objects ensures platform components run undisturbed and node drains proceed smoothly.

For detailed specifications, see the [Deployment Safeguards documentation](https://learn.microsoft.com/azure/aks/deployment-safeguards).

## Pod Readiness SLA for AKS Automatic

Uptime means more than a healthy control plane; it means your applications are actually serving users. The [Pod Readiness SLA](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services) guarantees that pods reach readiness targets, closing the gap between "the cluster is healthy" and "my app is ready."

- **Faster recovery during failures:** Node failures and scale events trigger remediation so pods return to a ready state within defined thresholds.
- **Predictable reliability:** Availability planning aligns with measurable guarantees instead of best-effort behavior.
- **Reduced operational overhead:** Platform automation handles remediation, eliminating manual firefighting during disruptions.
- **Business continuity at scale:** Mission-critical services experience minimal disruption even during infrastructure events.

## Pricing

AKS Automatic pricing includes a fixed monthly cluster fee and per-vCPU charges on top of standard VM compute costs. This pricing includes financially backed SLAs for both API server uptime and pod readiness. For current rates and a full breakdown by VM category, see the [Azure Kubernetes Service pricing page](https://azure.microsoft.com/pricing/details/kubernetes-service#pricing).

## Getting started

### Prerequisites

- Azure CLI 2.77.0 or later.
- `aks-preview` extension 19.0.0b15 or later.

```bash
# Install or update the aks-preview extension
az extension add --name aks-preview
az extension update --name aks-preview
```

### Register the preview feature

```bash
az feature register --name AKS-AutomaticHostedSystemProfilePreview --namespace Microsoft.ContainerService
```

### Create the cluster

```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --sku automatic \
  --enable-hosted-system \
  --location $LOCATION
```

The output includes `"hostedSystemProfile": { "enabled": true }` confirming the feature is active.

### Connect to the cluster and deploy an application

Get credentials for your cluster and deploy the [AKS Store demo application](https://github.com/Azure-Samples/aks-store-demo):

```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

kubectl create ns aks-store-demo
kubectl apply -n aks-store-demo -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-ingress-quickstart.yaml
```

Check the ingress address and open it in your browser once an IP is assigned:

```bash
kubectl get ingress store-front -n aks-store-demo --watch
```

Your workload runs on user node pools in your subscription while system services stay on the managed pool.

> **Tip:** Prefer a graphical experience? [AKS Desktop](https://learn.microsoft.com/azure/aks/aks-desktop-overview) lets you manage clusters, view workloads, and troubleshoot issues without leaving your desktop.

## Next steps

1. **Try it now:** Follow the [managed system node pools quickstart](https://learn.microsoft.com/azure/aks/automatic/aks-automatic-managed-system-node-pools).
2. **Share feedback:** Open issues or ideas in [AKS GitHub Issues](https://github.com/Azure/AKS/issues).
3. **Track progress:** Watch the [AKS public roadmap](https://aka.ms/aks/roadmap) for GA timelines and upcoming features.

We can't wait to see what you build. Let us know how managed system node pools simplify your operations and where we can keep raising the bar.

