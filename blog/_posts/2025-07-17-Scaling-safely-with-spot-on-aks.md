---
title: "Scaling Safely with Azure AKS Spot Node Pools Using Cluster Autoscaler Priority Expander"
description: "How to improve workload resilience when using spot VMs in Azure AKS, specifically how to use cluster autoscaler priority expander and other best practices."
date: 2025-07-17
authors: Pavneet Ahluwalia
categories: operations
tags:
  - scaling
  - spot
---

## Introduction

As engineering teams seek to optimize costs and maintain scalability in the cloud, leveraging Azure Spot Virtual Machines (VMs) in Azure Kubernetes Service (AKS) can help dramatically reduce compute costs for workloads tolerant of interruption.

However, operationalizing spot nodes safely—especially for production or critical workloads—requires deliberate strategies around cluster autoscaling and workload placement.

Here's how to utilize cluster autoscaler's priority expander feature to improve workload availability with spot on AKS.

## 1. Understanding Azure Spot Node Pools in AKS

Azure Spot VMs provide up to 90% savings compared to pay-as-you-go prices but come with the risk of eviction when Azure needs the compute back. To use Spot VMs with cluster autoscaler in AKS:

- Your AKS cluster must use Virtual Machine Scale Sets (VMSS) for its node pools.
- You can’t use Spot VMs for the default system node pool; only user node pools can be created as spot node pools.
- The `priority` property of the node pool determines if it's a spot pool or regular VM.

## 2. Setting Up a Safe Node Pool Architecture

A resilient AKS architecture for spot scaling typically looks like:

| Node Pool Type | Purpose | Node VM Priority |
| :-- | :-- | :-- |
| System (Default) | Core system workloads | Regular |
| On-demand | User/service-critical pods | Regular |
| Spot | Cost-optimized workloads | Spot |

- The default node pool (system) runs kube-system and other critical pods on regular VMs.
- Additional node pools can be created for workload pods: some regular, some spot.
- Workloads are assigned to node pools via Kubernetes node selectors and taints/tolerations.

## 3. Enabling and Configuring the Cluster Autoscaler and spot VM nodepool

**Cluster Autoscaler** automatically adjusts the number of nodes to meet pod scheduling needs. On AKS:

- You can enable autoscaler when creating a node pool:

```bash
az aks nodepool add \
  --resource-group <ResourceGroup> \
  --cluster-name <AKSCluster> \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 10
```

- Each pool can scale independently by setting different min/max counts.

## 4. Using the Priority Expander

The [**priority expander**](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/expander/priority/readme.md) lets you influence which node pool the cluster autoscaler scales first. For example, you might want the autoscaler to scale spot pools before on-demand pools to optimize for cost, but fall back to regular VMs if no spot capacity is available.

**In AKS, set the expander profile to `priority` and define your node pool priorities:**

- Add an autoscaler profile to cluster creation or update, specifying `expander=priority`:

```bash
az aks update \
  --resource-group <ResourceGroup> \
  --name <AKSCluster> \
  --cluster-autoscaler-profile expander=priority
```

- Configure a ConfigMap with pool patterns and their numeric priorities: higher number = higher priority.
- The ConfigMap must be named `cluster-autoscaler-priority-expander` and placed in the `kube-system` namespace.
- Below is an example of a configuration providing higher priority for spot VM node pools (higher number):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-priority-expander
  namespace: kube-system
data:
  priorities: |
    50:
      - .*spot.*
    10:
      - .*on-demand.*
    1:
      - .*catch-all.*
```

- Apply the above ConfigMap:

```bash
kubectl apply -f <path-to-configmap-file>
```

## 5. Best Practices for Spot Node Pool Scaling

- **Eviction Handling:** Create disruption budgets and readiness checks so pods are safely rescheduled if spot nodes are reclaimed.
- **Hedge capacity across SKUs:** Create multiple node pools of different VM family and SKUs to increase probability of spot capacity availability.
- **Pod Scheduling:** Use `nodeSelector`, `affinity`, and taints/tolerations to schedule tolerant workloads onto spot nodes, while keeping critical workloads on on-demand pools.
- **Zone Redundancy:** Distribute node pools across multiple availability zones to minimize simultaneous spot interruptions.
- **Cost Monitoring:** Use Azure monitoring to track node evictions (vmss activity logs), pool utilization, and right-size your pools regularly.
- **Horizontal Pod Autoscaler:** Combine with HPA to orchestrate scaling at both node and pod level for optimal elasticity.

## 6. Failover and Reliability Patterns

If spot capacity runs out or spot nodes are evicted:

- The priority expander allows autoscaler to fall back gracefully, scaling the next-eligible (on-demand) pool.
- Application workloads can continue on on-demand nodes, maintaining uptime and minimizing interruption.
- Use multiple node pools with appropriate affinity/anti-affinity to balance workloads and risk.

## 7. Clean-Up and Observation

When scaling down, the autoscaler will cordon and drain underutilized nodes, maintaining minimum pool counts and moving pods as needed. Always validate behavior in test environments before onboarding production workloads.

**Summary:**
Implementing spot node pool scaling in Azure AKS, combined with the cluster autoscaler’s priority expander, brings cost savings and elasticity to Kubernetes workloads—while protecting critical applications from unwanted interruptions through flexible, intelligent failover strategies.
