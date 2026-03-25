---
title: "Controlling Node Provisioning Outcomes on AKS: PDBs, Affinity, and Topology Spread"
description: "Learn best practices for using Node auto provisioning and to set predictable scheduling when scaling an AKS cluster."
date: 2026-03-30
authors: ["wilson-darko"]
tags:
  - node-auto-provisioning
  - scheduler
---

## Background

AKS users want to ensure their workloads schedule, scale, and are disrupted only when (or where) desired. The problem here is Kubernetes can feel complex, and its easy to be unclear what settings to use to accomplish this. Node Auto-Provisioning allows amazing benefits for compute efficiency, but to best utilize it - users need to make sure certain best practices are followed for predictable behavior. 

When adopting Kubernetes at scale, the hardest operational questions often aren’t “How do I scale nodes (or VMs)?” — they’re:

- Where will my workload replicas land (zones / nodes)?
- How do I keep critical workloads stable during disruption (drain, consolidation, upgrades)?
- How do I express node preferences without accidentally blocking scheduling?
- If I’m using Node Auto-Provisioning (NAP), how does it interpret the rules I set?

This post will connect NAP with the three most important workload-level tools for shaping predictable node provisioning outcomes on AKS:

1. **Pod Disruption Budgets (PDBs)** – control voluntary disruption
2. **Affinity/Anti-Affinity** – control where workloads can (or should not) run
3. **Topology Spread Constraints** – control replica distribution across failure domains

Then we’ll connect the dots to explain what AKS Node Auto-Provisioning (NAP) does with those signals to manage your workloads.

If you’re new to these Kubernetes features, this post will give you “good defaults” as a starting point. If you’re already deep into scheduling, treat it as a checklist for the behaviors AKS users most commonly ask about.

---

<!-- truncate -->

![Diagram showing NAP topology spread behavior](./nap-topology-spread-image-1.png)

:::info

Learn more in the official documentation: [Node Auto Provisioning](https://learn.microsoft.com/azure/aks/node-auto-provisioning) and [AKS Operator Best Practices](https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler)
:::

---

## How NAP handles node selection

Node auto-provisioning provisions, scales, and manages nodes. NAP senses pending pod pressure, chooses/provisions nodes that satisfy workload specs and NodePool allowed options — and then schedules pods onto those nodes.

NAP uses the following levers to control workload scheduling:

- NodePool CRD (policies / constraints) - Node settings like (SKU selection, capacity type, zones, labels, node-level resource limits)
- AKSNodeClass CRD (policies / constraints) - Azure-specific node settings like subnet behavior, image/OS disk/kubelet configuration, etc
- NodeClaims - details the state of provisioned and provisioning nodes
- Workload spec / deployment file - The Kubernetes manifest that defines your workload's resource requirements and scheduling constraints

Simply put, Workload spec expresses “where and how this pod should run”, NodePool / AKSNodeClass expresses “what nodes are allowed to exist for this class of workloads”, NodeClaims track what nodes are being scheduled or currently running.

You can think of the NodePool/AKSNodeClass as your “node policy envelope,” which your workload intent has to fit inside it.

_**Note:**_ NAP is a node-level (or infrastructure) autoscaler that schedules pods to nodes (VMs). For application level autoscaling, you can use [KEDA](https://learn.microsoft.com/azure/aks/keda-about) with NAP. We also suggest using [Vertical Pod Autoscaler (VPA)](https://learn.microsoft.com/azure/aks/vertical-pod-autoscaler) (in recommend mode) for resource sizing recommendations.

## Part 1 — The mental model: scheduling constraints are “workload intent”

Kubernetes scheduling is a negotiation between:

- Workload intent (what your pod spec asks for), and
- Available capacity (what nodes exist, and what the platform can create)

On AKS, you can express workload intent in your workload deployment file using Kubernetes concepts including:

- nodeSelector / nodeAffinity / podAffinity / podAntiAffinity
- taints & tolerations
- topologySpreadConstraints
- Pod Disruption Budgets (which don’t pick nodes, but do constrain eviction/drain behavior)

AKS also publishes [operator best-practices guidance](https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler) for these scheduler features, including taints/tolerations and affinity.

## Part 2 — Topology Spread Constraints: the #1 tool for zone-aware replicas

**Topology Spread Constraints** let you tell the scheduler: “Keep these replicas balanced across domains like zones or nodes.” The Kubernetes docs describe it as a way to spread pods across failure domains such as regions, zones, nodes, and custom topology keys.

### How NAP handles Topology Spread

NAP honors workload [topologyspreadconstraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#topologyspreadconstraints-field). While you can list the allowed zones in the NodePool CRD, `topologyspreadconstraints` are the means to ensure topology spread.

- NAP (**without** pod-level `topologyspreadconstraints` defined) will provision wherever there is availability for the preferred VM SKU. This can look like NAP provisioning all preferred nodes in zone 1 and none in zone 2 and zone 3.
- NAP (**with** pod-level `topologyspreadconstraints` defined) ensures topology spread. NAP honors pod-level constraints (number of replicas, topology spread behavior) in the workload deployment file. See the Kubernetes docs on topology spread for other examples also.

### A good default: spread across Availability Zones

Here’s a typical “3-zone spread” pattern for a Deployment:

```yaml
spec:
  replicas: 6
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        minDomains: 3
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: web
```

What these fields mean (in plain language):

- topologyKey: topology.kubernetes.io/zone → spread across zones (not just nodes).
- maxSkew: 1 → keep zone counts close (difference between most/least loaded domains can’t exceed 1 when DoNotSchedule). 
- minDomains: 3 (only valid with DoNotSchedule) → treat it as a requirement that at least 3 eligible domains participate; if fewer than minDomains are eligible, Kubernetes treats the “global minimum” as 0, affecting skew calculation.
- whenUnsatisfiable: DoNotSchedule → enforce the rule strictly; if it can’t be met, pods stay Pending.

### “Hard” vs “soft” topology spreading

Kubernetes gives you two behaviors:

- _DoNotSchedule_: strict; better for HA-critical workloads, but can stall rollouts (pods stay pending) if capacity is constrained.
- _ScheduleAnyway_: best-effort; scheduler still places pods wherever there is capacity but prioritizes choices that reduce skew.

**Practical guidance:**

Start with `DoNotSchedule` for Tier-0 services where zonal placement is critical and more important than scheduling speed.
Use `ScheduleAnyway` if you’d rather progress than block workload readiness during partial zone pressure.

For more info, visit the [upstream Kubernetes docs on topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#topologyspreadconstraints-field).

## Part 3 — Node Affinity / Anti-Affinity: shaping which nodes are eligible

Node affinity is the evolution of [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector): it’s more expressive and lets you define hard requirements vs soft preferences.

Common use cases:
1) “Only run on GPU nodes”
You typically implement this with node labels + nodeSelector / nodeAffinity (and often taints/tolerations if you want strong isolation).
Basic Example (with NodeSelector):

```yaml
spec:
  template:
    spec:
      nodeSelector:
        accelerator: gpu
```

Standard Example (with nodeAffinity):

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: accelerator
          operator: In
          values:
          - gpu
```

2) “Prefer this node type, but don’t block if it’s unavailable”
Use preferredDuringSchedulingIgnoredDuringExecution (soft preference).

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["Standard_D16ds_v5"]
```

3) “Never co-locate replicas on the same node”
That’s usually podAntiAffinity or topology spread across hostname.
A simple (but strict) approach is to spread on kubernetes.io/hostname:

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: web
```



## Part 4 — Pod Disruption Budgets (PDBs): controlling voluntary disruption

Pod disruption budgets (PDBs) are how you tell Kubernetes:

“During voluntary disruptions, keep at least N replicas available (or limit max unavailable).”

> [!NOTE] Pod disruption budgets protect against **voluntary evictions**, not involuntary failures, forced migrations, or node eviction.

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

### How NAP handles disruption

NAP honors Kubernetes-native concepts such as Pod Disruption Budgets when making disruption decisions.

NAP also has Karpenter-based concepts such as Consolidation, Drift, and Node Disruption Budgets. 

### The most common PDB pitfall
If you effectively set zero voluntary evictions (maxUnavailable: 0 or minAvailable: 100%), Kubernetes warns this can block node drains indefinitely for a node running one of those pods.

This common misconfiguration can cause scenarios such as:

-  Node / Cluster upgrades fail as nodes won't voluntarily scale down
-  Migration fails
-  NAP Consolidation never happens

#### Common pitfalls for NAP disruption

Behavior: NAP consolidates too often or voluntarily disrupts too many nodes at once
Cause: User has not set any guardrails on node disruption behavior.

  - Fix: Add PDBs that regulate disruption pace
  - Fix: Consider adding [Consolidation Policies](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption)
  - Fix: Configure [Node Disruption Budgets](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption#disruption-budgets) and/or enable a Maintenance Window using the [AKS Node OS Maintenance Schedule](https://learn.microsoft.com/azure/aks/node-auto-provisioning-upgrade-image#node-os-upgrade-maintenance-windows-for-nap)

Behavior: NAP node upgrades fail and/or NAP nodes will not scale down voluntarily
Cause: PDBs are set too strictly (ex. `maxUnavailable = 0` or `minAvailable: 100%`)

  - Fix: Ensure PDBs are not too strict; set maxUnavailable to a low (but not 0) number like 1.

_**Note:**_ This section is describing voluntary disruption, not to be confused with involuntary eviction (ex. spot VM evictions, node termination events, node stopping events)

**Practical guidance:**

- For critical workloads that you do not want to be disrupted at all, strictness of "zero eviction" may be intentional — but be deliberate. When you're ready to allow disruption to these workloads, you may have to change the PDBs in the workload deployment file.
- For general workloads that can tolerate minor disruption, prefer a small maxUnavailable (like 1) rather than “zero evictions.”
- Be clear on the tradeoff between zero tolerance (blocks upgrades, NAP consolidation, and scale down).

## Next steps

Ready to get started?

1. **Try NAP today:** Follow the [Enable Node Auto Provisioning steps](https://learn.microsoft.com/azure/aks/use-node-auto-provisioning).
1. **Learn more:** Visit our AKS [operator best-practices guidance](https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler)
1. **Share feedback:** Open issues or ideas in [AKS GitHub Issues](https://github.com/Azure/AKS/issues).
1. **Join the community:** Subscribe to the [AKS Community YouTube](https://www.youtube.com/@theakscommunity) and follow [@theakscommunity](https://x.com/theakscommunity) on X.
