---
title: "Improving Cilium Performance with NodeLocal DNSCache and Cilium"
date: 2026-03-31
description: "Reduce cross-node DNS traffic and keep Service decisions on the fast path by combining Upstream NodeLocal DNSCache with Cilium Local Redirect Policy on AKS."
authors: [jonathan-wang]
draft: true
tags:
  - networking
  - cilium
  - dns
  - dns-performance
  - performance
---

DNS and service load-balancing sit on the hot path for almost every request in a Kubernetes cluster. This post explores how combining Upstream NodeLocal DNSCache with Cilium Local Redirect Policy can reduce cross-node DNS traffic and keep common network decisions on the fast path.

## Why this matters

When DNS resolution or Service load-balancing spills across nodes or bounces between user space and kernel space, the overhead is small per request—but it adds up quickly at scale: extra hops, more packets, more CPU time, and more variance.

Throughout this post, Upstream NodeLocal DNSCache refers to the general pattern of running a DNS cache close to workloads (typically on each node), and Cilium Local Redirect Policy refers to the general capability to redirect traffic to local endpoints when they exist. Azure LocalDNS does not support Cilium Local Redirect Policy as of today.

## Where the overhead comes from

In Kubernetes, name resolution is usually provided by a cluster DNS component (commonly CoreDNS). From a workload's perspective, a DNS query is just another network request that must be routed to an available DNS backend. Depending on how traffic is distributed, that backend might be running on the same node or somewhere else in the cluster.

When DNS resolution crosses nodes, it incurs extra hops and consumes shared network capacity. Each individual query is small, but DNS tends to be frequent-especially with microservice fan-out, short TTLs, and service discovery patterns-so the aggregate effect shows up as higher tail latency, more packet processing, and more variance under load.

Service load-balancing is the other ubiquitous step on the hot path. Clusters can implement Service translation and backend selection in different ways (for example, using rules that are evaluated as packets traverse the node, or using in-kernel programmable data paths). The more Services and backends you have, the more important it is that this decision remains efficient and predictable.

## Concept

### Localize DNS with Upstream NodeLocal DNSCache

**Upstream NodeLocal DNSCache** is the idea of placing a DNS cache close to where queries originate, so that repeated lookups can be answered locally. Instead of sending every query across the cluster to a shared DNS tier, workloads consult a nearby cache first. Cache hits are handled immediately; cache misses fall back to the cluster DNS backends.

The conceptual benefit is straightforward: **reduce how often DNS traffic needs to traverse the cluster network**. With a healthy cache hit rate, most lookups avoid cross-node routing, the shared DNS tier sees less bursty traffic, and applications experience more stable resolution latency during spikes.

### Keep Service decisions on the fast path with Cilium

**Cilium** uses eBPF to implement networking and security functions with a high-performance data path. Conceptually, this enables common decisions-such as how to translate a Service to a concrete backend-to be made efficiently as packets traverse the node, with minimal context switching and consistent behavior at scale.

**Local Redirect Policy (LRP)** adds a locality preference: if a suitable backend exists on the same node, traffic can be steered there rather than traversing the node-to-node network. This can be especially effective for per-node agents and caches (including DNS caches), where the goal is not global load distribution but minimizing hops for a latency-sensitive, high-rate traffic class. Azure LocalDNS does not support Cilium Local Redirect Policy as of today.

### Why the combination works well

These two ideas reinforce each other. A node-local DNS cache reduces the need for cross-node resolution, and locality-aware steering helps ensure that traffic meant for node-local backends actually stays on the node when it can. When combined with an efficient Service data path, the cluster does less work per request: fewer hops, fewer packets handled by intermediate layers, and less variance when the system is under pressure.

- **Workloads issue frequent DNS lookups** as part of service discovery and outbound calls.
- **A nearby DNS cache answers repeated queries**, reducing how often lookups traverse the cluster.
- When a lookup is not cached, it is resolved by the shared DNS backends, but at a lower and smoother request rate.
- **Service translation and backend selection happen efficiently** on the node's data path, minimizing per-packet overhead.
- **When local backends exist and locality is desired**, traffic is steered locally to avoid unnecessary node-to-node hops.

## Adoption approach

Adopting these concepts is typically a two-part change: introduce node-local DNS caching to reduce repeated cross-cluster lookups, and ensure your service handling and traffic steering can take advantage of locality where it makes sense. The key is to roll changes in a way that preserves correctness first, then validates performance and resiliency characteristics.

- **Establish a baseline** for DNS behavior, Service traffic patterns, and application tail latency.
- **Introduce node-local caching** and validate that resolution remains correct while cross-node DNS traffic decreases.
- **Enable locality-aware steering where appropriate**, focusing first on traffic that is naturally node-scoped (agents, caches, per-node listeners).
- **Validate tradeoffs**: ensure failure handling, distribution goals, and observability meet your operational requirements.
- **Expand gradually** once you can attribute improvements and confirm there are no regressions.

## Operational considerations

- **Cache dynamics and TTLs:** The value of caching depends on how repeatable your lookups are and how long records remain valid. Very short TTLs or highly dynamic names reduce hit rates and therefore benefits.
- **Correctness under failure:** Any locality optimization should degrade safely. Ensure the system continues to resolve names and route traffic correctly when local components are unavailable.
- **Locality vs. distribution:** Preferring local endpoints can improve latency but may change load distribution. Confirm this aligns with your resilience, scaling, and cost goals.
- **Visibility into the data path:** To trust the outcome, you need to confirm where traffic is flowing and why. Without adequate visibility, it's easy to misattribute performance changes.
- **Change management:** Roll out iteratively and compare behavior across similar workloads to separate true improvements from normal variability.

## How to enable Upstream NodeLocal DNSCache with Cilium Local Redirect Policy

This section describes a practical, implementation-oriented pattern: run the Kubernetes **Upstream NodeLocal DNSCache** DaemonSet so every node has a local DNS listener, then use **Cilium Local Redirect Policy (LRP)** to steer pod DNS queries to the node-local listener (instead of sending them to a remote CoreDNS endpoint) while preserving a safe fallback to the upstream cluster DNS service.

- **Prerequisites:** Cilium installed and running as your CNI; CoreDNS (or another cluster DNS backend) deployed; permission to apply cluster-scoped resources.
- **Know your DNS Service IP:** the ClusterIP of the kube-dns Service (often in kube-system). Upstream NodeLocal DNSCache typically binds to a link-local IP such as `169.254.20.10` (commonly called `__PILLAR__LOCAL__DNS__` in the manifest).

### Step 1: Deploy Upstream NodeLocal DNSCache

Deploy the upstream nodelocaldns DaemonSet (or your distro's equivalent). At a high level, it:

- Runs a DNS cache on every node and binds it to a node-local IP (for example `169.254.20.10`).
- Installs rules so that queries directed at the cluster DNS Service can be answered by the local cache, which in turn forwards cache misses to CoreDNS.
- Keeps resolution behavior consistent with standard Kubernetes DNS (search paths, stub domains, etc.).

**Note:** Depending on your cluster setup, you may also configure kubelet's clusterDNS to point to the node-local IP so that newly created pods use Upstream NodeLocal DNSCache directly. Even if you do that, LRP is still useful as a safety net (and for cases where DNS traffic is still sent to the Service IP).

### Step 2: Ensure Upstream NodeLocal DNSCache pods are selectable

Cilium LRP selects backends by labels. Confirm your Upstream NodeLocal DNSCache DaemonSet pods have stable labels you can match (for example, `k8s-app: node-local-dns`). If needed, add an extra label to the DaemonSet so the selector is explicit and unlikely to change.

### Step 3: Create a Cilium Local Redirect Policy for DNS

Create an LRP that matches DNS traffic (UDP/TCP 53) destined to the cluster DNS Service IP and redirects it to a **local** Upstream NodeLocal DNSCache pod on the same node when available.

**Example (adapt the Service IP, namespace, and labels):**

```yaml
apiVersion: cilium.io/v2
kind: CiliumLocalRedirectPolicy
metadata:
  name: dns-to-nodelocal
  namespace: kube-system
spec:
  redirectFrontend:
    addressMatcher:
      ip: 10.96.0.10 # kube-dns ClusterIP (example)
    toPorts:
      - ports:
          - port: "53"
            protocol: UDP
          - port: "53"
            protocol: TCP
  redirectBackend:
    localEndpointSelector:
      matchLabels:
        k8s-app: node-local-dns
    toPorts:
      - ports:
          - port: "53"
            protocol: UDP
          - port: "53"
            protocol: TCP
```

**Fallback behavior:** LRP is locality-aware: when a local backend exists (a Upstream NodeLocal DNSCache pod on the same node), traffic is redirected locally. If no local backend is available, traffic continues to the original destination (the kube-dns Service IP), so name resolution still works via CoreDNS.

### Step 4: Verify traffic is staying node-local

- From a test pod, run DNS queries and confirm they succeed (for example, resolve an in-cluster Service and an external name).
- Confirm Upstream NodeLocal DNSCache is receiving queries on each node (check logs/metrics of the node-local-dns pods).
- Use Cilium observability tooling to confirm redirection decisions for DNS flows (for example, verify that traffic to the kube-dns ClusterIP is redirected to a local endpoint when present).
- Validate failure handling by temporarily making the node-local-dns pod unavailable on one node and confirming pods on that node can still resolve via the upstream kube-dns Service.

## Conclusion

For performance-sensitive Kubernetes clusters, combining node-local DNS caching with locality-aware traffic steering is a pragmatic way to reduce cross-node DNS traffic and keep common Service decisions on the fast path. The result is often lower tail latency, lower node CPU overhead, and more predictable networking behavior. Benchmark before and after, validate that traffic stays local when intended, and expand the pattern where it clearly improves your SLOs.
