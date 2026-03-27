---
title: "Managing Disruption with AKS Node Auto-Provisioning (NAP): PDBs, Consolidation, and Disruption Budgets"
description: "Learn AKS best practices to control voluntary disruption from Node Auto-Provisioning (NAP): how Pod Disruption Budgets interact with Karpenter consolidation/drift/expiration, and how to use NodePool disruption budgets and maintenance windows to keep workloads stable."
date: 2026-04-12
authors: ["wilson-darko"]
tags:
  - node-auto-provisioning
---

## Background
AKS users want to ensure that their workloads scaling when needed, and are disrupted only when (or where) desired. 
AKS Node Auto-Provisioning (NAP) is designed to keep clusters efficient: it provisions nodes for pending pods, and it also continuously *removes* nodes when it’s safe to do so (for example, when nodes are empty or underutilized). That second half **disruption** is where many production surprises happen.

When managing Kubernetes, operational questions that users might have are:

- How do I control when scale downs happen, or where it shouldn't?
- How do I control workload disruption so it happens predictably (and not in the middle of business hours)?
- Why won’t NAP scale down, even though I have lots of underused capacity?
- Why do upgrades get “stuck” on certain nodes?


This post focuses on **NAP disruption best practices**, and not workload scheduling (tools like topology spread constraints, node affinity, taints, etc.). For more on scheduling best practices, check out our [blog post](<will edit once part 1 blog is published>).

If you’re new to these NAP features, this post will give you “good defaults” as a starting point. If you’re already deep into NAP disruption settings, treat it as a checklist for the behaviors AKS users most commonly ask about.

---

<!-- truncate -->

:::info

Learn more about how to [configure disruption policies for NAP](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption)

:::

---

## Part 1 — The mental model: two layers of disruption control

When NAP decides a node (virtual machine) *could* be removed, there are two layers of controls that determine whether it actually happens:

### Workload layer: Pod Disruption Budgets (PDBs)

PDBs are Kubernetes-native guardrails that limit **voluntary evictions** of pods. PDBs are how you tell Kubernetes:

“During voluntary disruptions, keep at least N replicas available (or limit max unavailable).”


:::note
Pod disruption budgets protect against **voluntary evictions**, not involuntary failures, forced migrations, or spot node eviction.
:::

### Infrastructure layer: Node-level disruption settings

NAP allows setting disruption settings at the node level

NAP is built on Karpenter concepts and exposes disruption controls on the **NodePool**:
- **Consolidation policy** (when NAP is allowed to consolidate)
- **Disruption budgets** (how many nodes can be disrupted at once, and when)
- **Expire-after** (node lifetime)
- **Drift**(replace nodes that are out o)

A good operational posture is: **use PDBs to protect *applications*** and **use NAP disruption tools to control *the cluster’s disruption rate***.

---

## Part 2 - NAP Overview

Node auto-provisioning (NAP) provisions, scales, and manages nodes. NAP bases it's scheduling and disruption logic on settings from 3 sources:

- Workload deployment file - For disruption NAP honors the pod disruption budgets defined by the user here
- [NodePool CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools) - Used to list the range of allowed virtual machine options (size, zones, architecture) and also disruption settings
- [AKSNodeClass CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-aksnodeclass) - Used to define Azure-specific settings

### How NAP handles disruption

NAP honors Kubernetes-native concepts such as Pod Disruption Budgets when making disruption decisions. NAP also has Karpenter-based concepts such as Consolidation, Drift, and Node Disruption Budgets.

#### What “disruption” means in NAP (and what it doesn’t)

In NAP, “disruption” typically refers to **voluntary** actions that delete nodes after draining them, such as:

- **Consolidation**: deleting or replacing nodes (with better VM sizes) to increase compute efficiency (and reduce cost).
- **Drift**: replacing existing nodes that no longer match desired configuration (for example, an updated settings in your NodePool and AKSNodeClass CRDs).
- **Expiration**: replacing nodes after a configured lifetime.

These are different from **involuntary** disruptions such as:

- Spot/eviction events
- Hardware failures
- Host reboots outside your control

PDBs and Karpenter disruption budgets mainly help with **voluntary** disruptions. These features do not regulate involuntary disruption (for example, spot VM evictions, node termination events, node stopping events).

---

## Part 3 — Pod Disruption Budgets (PDBs): controlling voluntary disruption

The most common NAP disruption problems come from PDBs that are either:

- **Too strict**, blocking drains indefinitely, or
- **Missing**, allowing too much disruption at once.

### A good default PDB

Kubernetes documentation describes minAvailable / maxUnavailable as the two key availability knobs for PDBs, and notes you can only specify one per PDB.

Here's an example of a PDB that regulates disruption without blocking scale downs, upgrades, and consolidation:

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

Kubernetes describes minAvailable / maxUnavailable as the two key availability knobs, and notes you can only specify one per PDB.

Why it works well in practice:
- Consolidation/drift/expiration can still proceed.
- You avoid large brownouts caused by draining too many replicas at once.
- You reduce the chance of NAP “thrashing” a service by repeatedly moving too many pods.

### The common PDB pitfall: “zero voluntary evictions”

If you effectively set zero voluntary evictions (`maxUnavailable: 0` or `minAvailable: 100%`), Kubernetes warns this can block node drains indefinitely for a node running one of those pods.

This common misconfiguration can cause scenarios such as:

- Node / Cluster upgrades fail as nodes won't voluntarily scale down
- Migration fails
- NAP Consolidation never happens

This can be intentional for extremely sensitive workloads, but it has a cost: if a node has one of these pods, draining that node can become impossible without changing the PDB (or taking an outage). We recommend setting some tolerance for their two settings, and also using disruption budgets or maintenance windows to control disruption.

**Practical guidance:**

- For critical workloads that you do not want to be disrupted at all, strictness of "zero eviction" may be intentional — but be deliberate. When you're ready to allow disruption to these workloads, you may have to change the PDBs in the workload deployment file.
- For general workloads that can tolerate minor disruption, prefer a small maxUnavailable (like 1) rather than “zero evictions.”
- Be clear on the tradeoff between zero tolerance (blocks upgrades, NAP consolidation, and scale down).


## Part 4 — Controlling consolidation - “when” vs “how fast”

There are two different operator intents that often get conflated:

- **When** consolidation is allowed and will happen- **How much** disruption can happen concurrently (budgets / rate limiting)

### Consolidation policy (when)

Use the NodePool’s consolidation policy to express your comfort level with cost-optimization moves. For many clusters, a safe baseline is “only consolidate when empty or underutilized,” and then use budgets to keep the pace controlled.

Consolidation Settings


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


### Node Disruption budgets (how fast)

NAP exposes Karpenter-style disruption budgets on the NodePool. If you don’t set them, a default budget of `nodes: 10%` is used. Use budgets to regulate how many nodes are consolidate at a time.

The following example sets the node disruption budget to 1 node at a time. 

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

This is often the simplest way to prevent “NAP moved too many nodes at once”.

---

## Part 5 — Maintenance windows

A good practice for managing disruption is to **allow some consolidation, but only during a specific time-window**.

NAP node disruption budgets support `schedule` and `duration` so you can create time-based rules (cron syntax). These node disruption budgets can be defined by setting the `spec.disruption.budgets` field in the [NodePool CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools)

For example, block disruptions during business hours:

```yaml
budgets:
- nodes: "0"
  schedule: "0 9 * * 1-5"  # 9 AM Monday-Friday
  duration: 8h
```

Or allow higher disruption on weekends, and block otherwise:

```yaml
budgets:
- nodes: "50%"
  schedule: "0 0 * * 6"    # Saturday midnight
  duration: 48h
- nodes: "0"
```

**Why this matters:** it aligns cost-optimization (consolidation/drift/expiration) and updates with the regulated timeline that works for your workload needs.

To learn more about node disruption budgets, visit our [NAP Disruption documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption#disruption-budgets)

---

## Part 6 — Don’t forget node image updates (drift) and the “90-day” reality

NAP nodes are regularly updated as images change. The node image updates doc calls out a key behavior: **if a node image version is older than 90 days, NAP forces pickup of the latest image version, bypassing any existing maintenance window**.

Operational takeaway:
- Set up maintenance windows and budgets, but also ensure you’re not drifting so long that you hit a forced-update scenario.
- Treat “keep nodes reasonably fresh” as part of disruption planning, not an afterthought.

---

## Part 7 — Observability: verify disruption decisions with events/logs

Before changing policies, confirm what NAP *thinks* it’s doing:

- View events:
  - `kubectl get events --field-selector source=karpenter-events`
- Or use AKS control plane logs in Log Analytics (filter for `karpenter-events`)

This helps distinguish:
- “NAP wants to disrupt but is blocked by PDBs / budgets”
from
- “NAP isn’t trying to disrupt because consolidation policy doesn’t allow it”
from
- “NAP can’t replace nodes because provisioning is failing”

---

## Common disruption pitfalls

### Symptom: NAP won’t consolidate / drains hang forever

**Likely cause**
- PDBs effectively allow zero voluntary evictions (`maxUnavailable: 0` / `minAvailable: 100%`), or
- Too few replicas to satisfy the PDB during drain.

**Fix**
- Relax PDBs (for example `maxUnavailable: 1`) or increase replicas.
- If a workload truly must be undisruptable, accept that nodes running it won’t be good consolidation targets.

### Symptom: NAP disrupts too often or too much at once

Behavior: NAP consolidates too often or voluntarily disrupts too many nodes at once
Cause: User has not set any guardrails on node disruption behavior.

**Fix**
- Add PDBs that regulate disruption pace
- Add NodePool disruption budgets (start with `nodes: "1"` or a small percentage).
- Add time-based budgets (maintenance windows) so disruption happens when you want it.

### Symptom: disruption happens at the wrong time

**Likely cause**
- No time-based budgets / maintenance window.

**Fix**
- Add `schedule` + `duration` budgets to block disruption during business hours.
- Combine “block window” with a “small allowed disruption” budget outside the window.

#### Common pitfalls for NAP disruption

Behavior: NAP consolidates too often or voluntarily disrupts too many nodes at once
Cause: User has not set any guardrails on node disruption behavior.

- Fix: Add PDBs that regulate disruption pace
- Fix: Consider adding [Consolidation Policies](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption)
- Fix: Configure [Node Disruption Budgets](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption#disruption-budgets) and/or enable a Maintenance Window using the [AKS Node OS Maintenance Schedule](https://learn.microsoft.com/azure/aks/node-auto-provisioning-upgrade-image#node-os-upgrade-maintenance-windows-for-nap)

Behavior: NAP node upgrades fail and/or NAP nodes will not scale down voluntarily
Cause: PDBs are set too strictly (for example, `maxUnavailable = 0` or `minAvailable: 100%`)

- Fix: Ensure PDBs are not too strict; set maxUnavailable to a low (but not 0) number like 1.

_**Note:**_ This section is describing voluntary disruption, not to be confused with involuntary eviction (for example, spot VM evictions, node termination events, node stopping events)

---

## Next steps

1. **Try NAP today:** Check out the [Enable Node Auto Provisioning steps](https://learn.microsoft.com/azure/aks/use-node-auto-provisioning).
1. **Learn more:** Visit our AKS [operator best-practices guidance](https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler)
1. **Share feedback:** Open issues or ideas in [AKS GitHub Issues](https://github.com/Azure/AKS/issues).
1. **Join the community:** Subscribe to the [AKS Community YouTube](https://www.youtube.com/@theakscommunity) and follow [@theakscommunity](https://x.com/theakscommunity) on X.
