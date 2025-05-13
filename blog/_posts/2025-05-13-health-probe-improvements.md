---
title: "Smarter Load‑Balancer Health Probes for AKS"
description: "We’re redesigning the default Azure Load Balancer probe for externalTrafficPolicy: Cluster services so your apps stay healthy, troubleshooting gets simpler, and you can finally turn off those extra NodePorts."
date: 2025-05-13
author: Chase Wilson
categories:
- networking
---

## Background

AKS relies on Azure Load Balancer (SLB) to expose `Service` objects of type `LoadBalancer`.  
Until now, SLB’s health probes pointed *past* the node straight at the application’s `nodePort`. For `externalTrafficPolicy: Cluster`, that indirection created a **load‑balancer‑of‑load‑balancers** effect:

1. SLB probes the app on every node.  
2. kube‑proxy juggles the request to any ready Pod.  
3. SLB decides whether the **node** is healthy based on the **app** response.

That design worked, but it came with real pain:

- You had to duplicate health‑probe logic in two places (Pod `readinessProbe` *and* SLB annotations).
- kube‑proxy drift, network‑policy drops, or a single scaled‑to‑zero deployment could quietly take nodes out of rotation.  
- Large clusters burned SNAT ports and SLB body size on thousands of probes.  
- Because probes hit `nodePort`, you couldn’t set `allocateLoadBalancerNodePorts: false` for a performance win.

## What we’re changing

We’re flipping the probe around:

- **New default** for `externalTrafficPolicy: Cluster` – SLB sends a single shared **HTTP** probe to `http://<nodeIP>:10256/healthz`.  
  - A lightweight AKS sidecar handles PROXY‑protocol edge cases so Private Link Service scenarios keep working.
  - That endpoint is kube‑proxy’s own health check.  

- **Unchanged** – Services using `externalTrafficPolicy: Local` keep their per‑Service `healthCheckNodePort` behavior.

### Why this is better

| Challenge                      | Old behavior                 | New behavior                   |
|--------------------------------|------------------------------|--------------------------------|
| Probe reflects **node** health | ❌ Indirect (app‑level)       | ✅ Direct (kube‑proxy)          |
| Duplicate configuration        | ❌ Yes                        | ✅ No                           |
| Diagnose kube‑proxy drift      | ❌ Hard                       | ✅ SLB shows DIP failures       |
| Node drain / autoscaler grace  | ❌ Black‑holes possible       | ✅ “Admin‑down” future‑proofing |
| SLB probe bloat                | ❌ Every Service × every node | ✅ One probe per node           |
| Disable extra NodePorts        | ❌ Blocked                    | ✅ Unblocked                    |

## How it works under the hood

1. **Shared probe** – Cloud‑provider config switches to *node health check* mode.  
2. **Sidecar** – AKS deploys `node-health-proxy` alongside kube‑proxy:  
   - Listens on a new port (defaults to `29999`).  
   - Strips or parses the PROXY PDU so kube‑proxy doesn’t choke.  
   - Forwards `/healthz` to localhost `10256`.

## What this means for you

- **Cleaner upgrades** – You no longer have to remember arcane SLB annotations when you migrate an ingress controller.  
- **Observability you can trust** – A red DIP now really means “this node is unhealthy,” not “one of my pods failed HTTP on `/ready`.”  
- **Fewer moving parts** – Turn off unneeded NodePorts, reduce SNAT churn, and shrink SLB config size.  

## Getting started

For more information on how to use the new health probe, check out the [AKS documentation](https://learn.microsoft.com/azure/aks/load-balancer-standard).

## Summary

By pointing SLB’s probe at the node instead of every app, AKS:

- Removes a whole class of misconfigured probes.
- Surfaces node health faster and more accurately.
- Cuts probe traffic and SNAT pressure.
- Opens the door to cleaner node drains and autoscaler events.

Try it out today and let us know how it works in your environment!
