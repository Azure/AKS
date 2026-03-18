---
title: "Controlling Node Provisioning Outcomes on AKS: PDBs, Affinity, and Topology Spread (and what NAP does with them)"
description: "Learn how Node auto provisioning and virtual machine node pools can address common capacity constraints when scaling an AKS cluster. Also learn best practices for compute scaling in AKS."
date: 2026-03-20
authors: ["wilson-darko"]
tags:
  - node-auto-provisioning
---


When customers adopt Kubernetes at scale, the hardest operational questions often aren’t “How do I scale?” — they’re:

- Where will my replicas land (zones / nodes)?
- How do I keep critical workloads stable during disruption (drain, consolidation, upgrades)?
- How do I express node preferences without accidentally blocking scheduling?
- If I’m using Node Auto-Provisioning (NAP), how does it interpret the rules I set?

This post is a practical guide to the three most important workload-level tools for shaping node provisioning outcomes on AKS:

1. **Pod Disruption Budgets (PDBs)** – control voluntary disruption
2. **(Anti-)Affinity** – control where workloads can (or should not) run
3. **Topology Spread Constraints** – control replica distribution across failure domains

Then we’ll connect the dots to explain what AKS Node Auto-Provisioning (NAP) does with those signals.

If you’re new to these features, this post will give you “safe defaults.” If you’re already deep into scheduling, treat it as a checklist for the behaviors customers most commonly ask about.


## Part 1 — The mental model: scheduling rules are “workload intent”

Kubernetes scheduling is a negotiation between:

Workload intent (what your pod spec asks for), and
Available capacity (what nodes exist, and what the platform can create)

On AKS, you can express intent using:

- nodeSelector / nodeAffinity / podAffinity / podAntiAffinity
- taints & tolerations
- topologySpreadConstraints
- Pod Disruption Budgets (which don’t pick nodes, but do constrain eviction/drain behavior)

AKS also publishes best-practices guidance for these scheduler features, including taints/tolerations and affinity. [learn.microsoft.com]

## Part 2 — Topology Spread Constraints: the #1 tool for zone-aware replicas

**Topology Spread Constraints** let you tell the scheduler: “Keep these replicas balanced across domains like zones or nodes.” The Kubernetes docs describe it as a way to spread pods across failure domains such as regions, zones, nodes, and custom topology keys. [kubernetes.io]

### A good default: spread across Availability Zones

Here’s a typical “3-zone spread” pattern for a Deployment:

```YAML
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

- topologyKey: topology.kubernetes.io/zone → spread across zones (not just nodes). [kubernetes.io]
- maxSkew: 1 → keep zone counts close (difference between most/least loaded domains can’t exceed 1 when DoNotSchedule). [kubernetes.io]
- minDomains: 3 (only valid with DoNotSchedule) → treat it as a requirement that at least 3 eligible domains participate; if fewer than minDomains are eligible, Kubernetes treats the “global minimum” as 0, affecting skew calculation. [kubernetes.io]
- whenUnsatisfiable: DoNotSchedule → enforce the rule strictly; if it can’t be met, pods stay Pending. [kubernetes.io]

### “Hard” vs “soft” topology spreading

Kubernetes gives you two behaviors:

- _DoNotSchedule_: strict; better for HA-critical workloads, but can stall rollouts if capacity is constrained. [kubernetes.io]
- _ScheduleAnyway_: best-effort; scheduler still places pods but prioritizes choices that reduce skew. [kubernetes.io]

**Practical guidance:**

Start with `DoNotSchedule` for Tier-0 services where availability > speed.
Use `ScheduleAnyway` if you’d rather progress than block during partial zone pressure.

## Part 3 — Node Affinity / Anti-Affinity: shaping which nodes are eligible

Node affinity is the evolution of nodeSelector: it’s more expressive and lets you define hard requirements vs soft preferences.

AKS best-practices guidance calls out node selectors and affinity as core tools to “give preference to pods to run on certain nodes.” [learn.microsoft.com]

Common use cases:
1) “Only run on GPU nodes”
You typically implement this with node labels + nodeSelector / nodeAffinity (and often taints/tolerations if you want strong isolation).
Example (conceptual):

```YAML
spec:
  template:
    spec:
      nodeSelector:
        accelerator: gpu
```

2) “Prefer this node type, but don’t block if it’s unavailable”
Use preferredDuringSchedulingIgnoredDuringExecution (soft preference).

```YAML
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

```YAML
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

[!Note] Pod disruption budgets protect against **voluntary evictions**, not involuntary failures, forced migrations, or node eviction.

A starting point to consider (stateless deployments):

```YAML
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

Kubernetes describes minAvailable / maxUnavailable as the two key availability knobs, and notes you can only specify one per PDB. [kubernetes.io]

### The most common PDB pitfall
If you effectively set zero voluntary evictions (maxUnavailable: 0 or minAvailable: 100%), Kubernetes warns this can block node drains indefinitely for a node running one of those pods.

This common misconfiguration can cause scenarios such as:

-  Node / Cluster upgrades fail as nodes won't voluntarily scale down
-  Migration fails
-  NAP Consolidation never happens

Practical guidance:

- For critical stateful quorum workloads, that strictness may be intentional — but be deliberate.
- For stateless services, prefer a small maxUnavailable (like 1) rather than “zero evictions.”
- Be clear on the tradeoff between zero tolerance (blocks upgrades, 

## How NAP uses these signals (and how to think about it)

Now let’s connect workload intent to AKS Node Auto-Provisioning (NAP).

### NAP Overview

Node auto-provisioning provisions, scales, and manages nodes in response to pending pod pressure

NAP uses key components including:

- NodePool CRD (policies / constraints) - Node settings like (SKU selection, capacity type, zones, architecture
- AKSNodeClass CRD (policies / constraints) - Azure-specific node settings like subnet behavior, image/OS disk/kubelet configuration, etc
- NodeClaims - details state of provisioned/provisioning nodes
- Workload resource requirements (from workload deployment file)

A simple way to look at this sequence of :

- Workload spec expresses “where and how this pod should run.”
- NodePool / AKSNodeClass expresses “what nodes are allowed to exist for this class of workloads.”
- NodeClaims track what nodes are being scheduled (or currently running)

You can think of the NodePool/AKSNodeClass as as your “node policy envelope,” your workload intent has to fit inside it.

NAP senses pending pod pressure, chooses/provisions nodes that satisfy workload specs and NodePool allowed options — and then schedules pods onto them.

### NAP Disruption with PDBs

### How NAP handles Topology Spread

NAP honors workload [topologyspreadconstraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#topologyspreadconstraints-field)

- NAP (without pod-level `topologyspreadconstraints` defined) will provision wherever there is availability for the preferred VM SKU. This can look like NAP provisioning all preferred nodes in zone 1 and none in zone 2 and zone 3.
- NAP (with pod-level `topologyspreadconstraints` defined) to ensure topology spread, NAP will honor any pod-level constraints  (# of replicas, topology spread
behavior) in the workload deployment file. See the Kubernetes docs on topology spread for other examples also.

While you can list the allowed zones in the NodePool CRD, NAP will provision 
