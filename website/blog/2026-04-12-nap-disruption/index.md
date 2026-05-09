---
title: "Managing disruption with AKS Node Auto-Provisioning"
description: "Learn AKS best practices for managing NAP disruption with Pod Disruption Budgets, node pool budgets, consolidation, and maintenance windows."
date: 2026-04-12
authors: ["wilson-darko"]
tags:
  - node-auto-provisioning
---

Azure Kubernetes Service (AKS) Node Auto-Provisioning (NAP) keeps your clusters efficient: it provisions nodes for pending pods, and it continuously *removes* nodes when it's safe to do so, for example, when nodes are empty or underutilized. That node-removal disruption is where many production surprises happen.

When you manage Kubernetes, a few disruption questions come up fast:

- How do I control when scale down happens, or when it should not happen?
- How do I make workload disruption predictable?
- Why won’t NAP scale down my nodes, even with lots of underused capacity?
- Why do upgrades get stuck on certain nodes?

This post focuses on **NAP disruption best practices**, not workload scheduling tools such as topology spread constraints, node affinity, and taints. For scheduling best practices, see the [NAP scheduling fundamentals blog post](./2025-12-06-node-auto-provisioning-capacity-management/index.md).

If you’re new to these features, start here. If you already use NAP disruption settings, use this post as a checklist for the behaviors AKS users most commonly ask about.

---

<!-- truncate -->

![Diagram showing two concentric defensive layers protecting workloads during NAP node consolidation](./hero-image.png)

:::info

Learn more about how to [configure disruption policies for NAP](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption)

:::

---

## Two layers of disruption control

When NAP decides a node (virtual machine) *could* be removed, two layers of controls determine whether it actually happens:

### Workload layer: Pod Disruption Budgets (PDBs)

PDBs are Kubernetes-native guardrails that limit **voluntary evictions** of pods. PDBs tell Kubernetes:

"During voluntary disruptions, keep at least N replicas available, or limit max unavailable."

:::note
Pod disruption budgets protect against **voluntary evictions**, not involuntary failures, forced migrations, or spot node eviction.
:::

### Infrastructure layer: node-level disruption settings

NAP exposes disruption controls at the node level.

NAP is built on Karpenter concepts and exposes disruption controls on the **NodePool**:

- **Consolidation policy**: when NAP is allowed to consolidate
- **Disruption budgets**: how many nodes can be disrupted at once, and when
- **Expire-after**: node lifetime
- **Drift**: replace nodes that are out of date with the desired NodePool configuration

A good operational posture is simple: **use PDBs to protect applications** and **use NAP disruption tools to control the cluster's disruption rate**.

---

## NAP overview

Node auto-provisioning (NAP) provisions, scales, and manages nodes. NAP bases its scheduling and disruption logic on settings from three sources:

- Workload deployment file: for disruption, NAP honors the PodDisruptionBudgets you define here.
- [NodePool CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools): lists the allowed virtual machine options, such as size, zones, and architecture, and also defines disruption settings.
- [AKSNodeClass CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-aksnodeclass): defines Azure-specific settings.

### How NAP handles disruption

NAP honors Kubernetes-native concepts such as PodDisruptionBudgets when making disruption decisions. NAP also includes Karpenter-based concepts such as consolidation, drift, and node disruption budgets.

### What disruption means in NAP

In NAP, disruption typically refers to **voluntary** actions that delete nodes after draining them, such as:

- **Consolidation**: delete or replace nodes with better virtual machine sizes to improve compute efficiency and reduce cost.
- **Drift**: replace existing nodes that no longer match the desired configuration, for example, updated settings in your NodePool and AKSNodeClass CRDs.
- **Expiration**: replace nodes after a configured lifetime.

These actions differ from **involuntary** disruptions such as:

- Spot eviction events
- Hardware failures
- Host reboots outside your control

PDBs and Karpenter disruption budgets mainly help with **voluntary** disruptions. These features do not regulate involuntary disruption, for example, spot VM evictions, node termination events, or node stopping events.

---

## Pod Disruption Budgets (PDBs): controlling voluntary disruption

Most NAP disruption problems come from PDBs that are either:

- **Too strict**: a strong guardrail blocks node drains indefinitely.
- **Missing**: no guardrail limits disruption.

### A good default PDB

Kubernetes documentation describes `minAvailable` and `maxUnavailable` as the two key availability settings for PDBs. You can specify only one per PDB.

Here's an example of a PDB that regulates disruption without blocking scale down, upgrades, and consolidation:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: web
```

Why it works well in practice:

- Consolidation, drift, and expiration can still proceed.
- It helps you avoid large brownouts caused by draining too many replicas at once.
- It reduces the chance of NAP thrashing a service by repeatedly moving too many pods.

### The common PDB pitfall: zero voluntary evictions

If you effectively set zero voluntary evictions, for example, `maxUnavailable: 0` or `minAvailable: 100%`, Kubernetes warns that this can block node drains indefinitely for a node running one of those pods.

This common misconfiguration can cause scenarios such as:

- Node and cluster upgrades fail because nodes do not voluntarily scale down.
- Migration fails.
- NAP consolidation never happens.

This can be intentional for extremely sensitive workloads, but it has a cost. If a node has one of these pods, draining that node can become impossible without changing the PDB or taking an outage. Set some tolerance in these PDB settings, and use disruption budgets or maintenance windows to control disruption.

**Practical guidance:**

- For critical workloads that you do not want to disrupt, zero eviction may be intentional. Be deliberate. When you're ready to allow disruption to these workloads, you may need to change the PDBs in the workload deployment file.
- For general workloads that can tolerate minor disruption, prefer a small `maxUnavailable` value, such as `1`, instead of zero evictions.
- Be clear on the tradeoff. Zero tolerance can block upgrades, NAP consolidation, and scale down.

## Controlling consolidation: when vs. how fast

Two operator intents often get conflated:

- **When** consolidation is allowed and happens.
- **How much** disruption can happen concurrently.

Use these settings to control consolidation behavior:

- `consolidationPolicy: WhenEmptyOrUnderutilized`: triggers when NAP identifies existing nodes as underutilized or empty. NAP runs cost simulations of virtual machine size combinations that best match the current configuration. When it finds a better combination, consolidation starts.
- `consolidateAfter: 1d`: controls the delay before NAP consolidates underutilized nodes, and works with the `consolidationPolicy` setting.
- `expireAfter: 24h`: determines how long nodes in this NodePool CRD can exist. Older nodes are deleted regardless of consolidation policies.

**Note:** Underutilized is not a value you can set. NAP determines it through its cost simulations.

The following example shows these disruption tools in action:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
  template:
    spec:
      nodeClassRef:
        name: default
      expireAfter: Never
```

### Node disruption budgets: how fast

NAP exposes Karpenter-style disruption budgets on the NodePool. If you don’t set them, a default budget of `nodes: 10%` applies. Use budgets to regulate how many nodes are consolidated at a time.

The following example sets the node disruption budget to one node at a time.

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    budgets:
    - nodes: "1"
```

This is often the simplest way to prevent NAP from moving too many nodes at once.

---

## Maintenance windows

A good practice is to allow some consolidation, but only during a specific time window.

NAP node disruption budgets support `schedule` and `duration`, so you can create time-based rules with cron syntax. Define these budgets in the `spec.disruption.budgets` field of the [NodePool CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools).

For example, block disruptions during business hours:

```yaml
budgets:
- nodes: "0"
  schedule: "0 9 * * 1-5"  # 9 AM Monday-Friday
  duration: 8h
```

Or allow higher disruption on weekends, and block disruption otherwise:

```yaml
budgets:
- nodes: "50%"
  schedule: "0 0 * * 6"    # Saturday midnight
  duration: 48h
- nodes: "0"
```

**Why this matters:** It aligns cost optimization, including consolidation, drift, and expiration, with the timeline that works for your workload needs.

To learn more about node disruption budgets, see the [NAP disruption documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption#disruption-budgets).

---

## Keep node images current

NAP nodes are regularly updated as images change. The node image updates documentation calls out a key behavior: **if a node image version is older than 90 days, NAP forces pickup of the latest image version and bypasses any existing maintenance window**.

Operational takeaway:

- Set up maintenance windows and budgets, but also make sure you do not drift long enough to hit a forced update scenario.
- Treat keeping nodes reasonably fresh as part of disruption planning.

---

## Observability: verify disruption decisions with events and logs

Before you change policies, confirm what NAP *thinks* it's doing:

- View events:
  - `kubectl get events --field-selector source=karpenter-events`
- Or use AKS control plane logs in Log Analytics, filtered for `karpenter-events`

This helps you distinguish between these cases:

- NAP wants to disrupt nodes, but PDBs or disruption budgets block it.
- NAP is not trying to disrupt nodes because the consolidation policy does not allow it.
- NAP can't replace nodes because provisioning is failing.

---

## Common disruption pitfalls

### Symptom: NAP won’t consolidate or drains hang forever

Behavior: Nodes do not scale down for consolidation or updates.

Cause:

- PDBs effectively allow zero voluntary evictions, for example, `maxUnavailable: 0` or `minAvailable: 100%`.
- Too few replicas exist to satisfy the PDB during drain.

Fix:

- Relax PDBs, for example, `maxUnavailable: 1`, or increase replicas.
- If a workload truly must not be disrupted, accept that nodes running it will not consolidate. This also increases the risk of update failure. A strict `100%` available PDB can cause scale down and update failures.

### Symptom: NAP disrupts too often or too much at once

Behavior: NAP consolidates too often or voluntarily disrupts too many nodes at once.

Cause:

- No guardrails exist for node disruption behavior, such as PDBs or node disruption budgets.
- No maintenance window exists for scheduled disruption times.

Fix:

- Add PDBs that regulate disruption pace.
- Add NodePool disruption budgets. Start with `nodes: "1"` or a small percentage.
- Add time-based budgets so disruption happens when you want it.

### Symptom: disruption happens at the wrong time

Behavior: Disruption happens during inconvenient times, such as work hours or peak usage windows.

Cause:

- No time-based budgets or maintenance window exists.

Fix:

- Add Karpenter disruption budgets to block disruption during business hours.
- Combine a maintenance window with a small allowed-disruption budget outside the window.

---

## Next steps

1. **Try NAP today:** Check out the [Enable Node Auto Provisioning steps](https://learn.microsoft.com/azure/aks/use-node-auto-provisioning).
2. **Learn more:** Visit the AKS [operator best-practices guidance](https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler).
3. **Share feedback:** Open issues or ideas in [AKS GitHub Issues](https://github.com/Azure/AKS/issues).
4. **Join the community:** Subscribe to the [AKS Community YouTube](https://www.youtube.com/@theakscommunity) and follow [@theakscommunity](https://x.com/theakscommunity) on X.
