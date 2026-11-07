---
title: "Two Less Common DNS Issues on AKS, and How to Address Them"
date: "2026-11-06"
description: "Learn why a few DNS queries fail during AKS upgrades and why one unreachable CoreDNS pod breaks DNS, and how LocalDNS and Cluster Health Monitor help."
authors: ["mitch-shao"]
tags:
  - dns
  - networking
  - troubleshooting
keywords: ["AKS", "Azure Kubernetes Service", "CoreDNS", "DNS", "conntrack", "kube-proxy", "LocalDNS", "Cluster Health Monitor"]
---

CoreDNS availability is critical for workloads running on Kubernetes. This article shares two issues that affect CoreDNS availability. We run into them often, but they are not easy to diagnose. For each one, we explain the cause and how to address it:

- **During cluster upgrades, a very small number of DNS queries fail or time out.** The cause is stale UDP conntrack entries left behind when CoreDNS pods are replaced.
- **One CoreDNS pod becomes unreachable because of an unstable node or network, and a share of DNS queries keeps failing until CoreDNS is restarted.**

<!-- truncate -->

## A Small Number of DNS Queries Fail During Cluster Upgrades

Some customers have reported that a small number of DNS queries fail or time out, especially during cluster upgrades. It doesn't happen every time. We were able to reproduce it only when DNS traffic was heavy, with a high number of concurrent queries.

In short, we found that these failures are caused by **reused entries in the conntrack table**: after a CoreDNS pod is replaced, some queries match an old entry and are still sent to the old pod's IP. The sections below explain how this happens.

### DNAT and Conntrack

A pod sends DNS queries to the kube-dns Service ClusterIP, for example `10.0.0.10:53/UDP`. kube-proxy then forwards each query to a CoreDNS pod:

1. The first packet goes through kube-proxy's iptables (or IPVS) rules. One CoreDNS pod is chosen, for example `10.244.1.5`, and the packet's destination is rewritten to it (DNAT).
2. The kernel's connection tracker, conntrack, records this decision:

   ```text
   original: PodA:34567 -> 10.0.0.10:53      <- lookup key
   reply:    10.244.1.5:53 -> PodA:34567     <- NAT result
   ```

3. Later packets that match the same 5-tuple (protocol, source IP, source port, destination IP, destination port) reuse this entry. **The NAT rules are not evaluated again.** Each matching packet also resets the entry's timeout.

One detail matters for everything that follows: **conntrack looks entries up by the original 5-tuple, which contains the ClusterIP, not the pod IP.**

### UDP Creates a Large Number of conntrack Entries

TCP has connections. Once a connection is established, it stays open, and all communication between the two sides goes over it. HTTP itself has no notion of a connection, but with keep-alive it can reuse the same TCP connection for many requests. As a result, TCP traffic usually doesn't create many connections, and the conntrack table doesn't hold many TCP entries.

UDP is different. It has no connections, so there is nothing to keep open and reuse. A typical DNS client opens a separate socket for each query, and each socket gets its own random source port. That means every DNS query has its own 5-tuple, and therefore **its own conntrack entry**. Because there's no connection, nothing ever closes these entries either: each one stays in the table until it times out, or until someone deletes it.

How long an entry stays is controlled by the kernel parameter `net.netfilter.nf_conntrack_udp_timeout_stream`. On AKS nodes, the default value is **120 seconds**.

With heavy DNS traffic, these per-query entries add up quickly: thousands of queries per second leave tens of thousands of UDP entries in the conntrack table, each one waiting to time out.

Each of these entries holds a DNAT decision: "traffic from this source port goes to this CoreDNS pod." As long as the entry exists, the decision stands.

The problem comes from **reusing these entries**. When CoreDNS is restarted, for example during a rolling update, the old pod is deleted, but its conntrack entries stay in the table until kube-proxy removes them, usually a few seconds later (see the next section). If a query reuses the same source port before they're removed, it has the same 5-tuple and matches the old entry. The query is sent to the IP of a pod that no longer exists.

How likely is that? The gap before kube-proxy cleans up is only a few seconds, but because each entry lives for 120 seconds, a lot of entries pointing to the old pod have piled up by then. A quick calculation for a single pod:

1. **Available source ports:** the default ephemeral port range is 32768–60999, so there are 60999 − 32768 + 1 = **28,232 ports**.
2. **Entries pointing to the old pod:** each entry stays for 120 seconds, so a pod has about QPS × 120 entries. With N CoreDNS replicas, about 1/N of them point to the pod being replaced.
3. **Chance a new query hits one:** (QPS × 120 / N) / 28,232.

For example, a pod sending 200 DNS queries per second with 3 CoreDNS replicas has about 200 × 120 / 3 = 8,000 entries pointing to the old pod, so about 8,000 / 28,232 ≈ **28%** of its queries during the gap hit a stale entry. That's why only a small number of queries fail, and only when DNS traffic is heavy.

### Kubernetes Cleans Up When a Pod Is Deleted, but That Doesn't Fully Solve It

When a pod is deleted, kube-proxy does clear its UDP conntrack entries (see [`pkg/proxy/conntrack/cleanup.go`](https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/conntrack/cleanup.go)). But the cleanup isn't instant. After the CoreDNS process exits, the change still has to reach kube-proxy, and kube-proxy has to sync before it deletes the entries. During that gap, the old pod is gone but its entries are still in the table, so any query that reuses one of them is sent to a pod that no longer exists.

I suggested to the Kubernetes community that kube-proxy clear these entries during the pod's grace period instead ([kubernetes/kubernetes#132635](https://github.com/kubernetes/kubernetes/issues/132635)). During the grace period, the terminating pod has already been removed from kube-proxy's DNAT rules, so no new queries are sent to it, but it can still answer queries. If kube-proxy cleared the pod's conntrack entries at that point, the old flows would be drained: reused queries would go through the DNAT rules again and reach a live pod, while any queries already on their way to the old pod would still get an answer. The proposal was pushed back for various reasons.

In short, this is a Kubernetes-wide issue, not specific to AKS, and it won't be fixed upstream any time soon. Any UDP traffic through a Service that kube-proxy handles is exposed to it.

> **Scope:** This section describes the kube-proxy dataplane (iptables or IPVS). Clusters that use Azure CNI powered by Cilium replace kube-proxy with eBPF socket load balancing, which behaves differently and isn't covered here.

### How to Avoid It: Use LocalDNS

We recommend enabling [LocalDNS](https://learn.microsoft.com/en-us/azure/aks/localdns-custom) on AKS. LocalDNS runs a DNS cache on every node, and pods send their queries to it instead of the kube-dns ClusterIP. LocalDNS still forwards cache misses to CoreDNS through the ClusterIP, so its own queries can still hit a stale conntrack entry. The difference is how it recovers. If a forwarded query times out, LocalDNS closes that socket and retries on a new one. The new socket gets a new source port, so the retry gets a new conntrack entry and is DNATed to a live CoreDNS pod. The failed attempt costs about one read timeout, well within the client's 5-second timeout, so the application sees a slightly slower answer instead of a failure. The node cache also answers most queries without going to CoreDNS at all.

Note that LocalDNS isn't enabled automatically (Preferred mode) on clusters that use Cilium, Calico, or NetworkPolicy. On those clusters, you need to check whether LocalDNS is supported for your configuration and enable it explicitly.

For more about LocalDNS, see:

- [Configure LocalDNS in Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/localdns-custom)
- [Accelerate DNS performance with LocalDNS](https://blog.aks.azure.com/2025/08/04/accelerate-dns-performance-with-localdns)

## One CoreDNS Pod Becomes Unreachable, and a Share of DNS Queries Keeps Failing

Some customers have reported DNS failures that don't go away on their own: a fixed share of DNS queries, for example 20–30%, keeps failing or timing out for minutes or even hours. Restarting CoreDNS fixes it immediately.

### What Happens

The cause isn't CoreDNS itself. It's the node or the network underneath one CoreDNS pod. We have seen several different root causes, for example:

- **Unstable networking on the physical host.** Memory spiked on the Azure physical host that runs the node's VM and starved the host's virtual switch, so the VM lost its data path. The CoreDNS pod on that node became unreachable until the physical host was rebooted.
- **A stale network mapping after a node upgrade.** During a node image upgrade, the physical host under the VM missed the cleanup of an old container. A new container got the same IP, and the stale cleanup removed its mapping. The CoreDNS pod using that IP lost its data path.
- **An OS or infrastructure issue on the physical host under a single node.**

The causes differ, but the result is the same: **one CoreDNS pod is unreachable, while Kubernetes still thinks it is healthy.**

### Why Kubernetes Doesn't Fix It

The CoreDNS pod is still `Running` and `Ready`, and its liveness and readiness probes keep passing. That's because **the probes are sent locally**: the kubelet on the same node checks the pod, and that path never leaves the node. Requests from other nodes have to cross the network, and those are the ones that fail. The node itself also stays `Ready`, because the kubelet can still reach the API server and keeps sending heartbeats. So from Kubernetes' point of view both the node and the pod are perfectly healthy, while pods on other nodes can't reach the CoreDNS pod. As a result:

- The pod stays in the kube-dns Service endpoints.
- kube-proxy keeps load-balancing a share of DNS queries to it. With 3 replicas, roughly a third of new queries go to the broken pod.
- Nothing restarts or reschedules the pod, so the failures last until a person notices and restarts CoreDNS, or until the underlying node is repaired.

### How to Avoid It: Use Cluster Health Monitor

[Cluster Health Monitor](https://learn.microsoft.com/en-us/azure/aks/cluster-health-monitor) closes exactly this gap. It runs on a system node and sends DNS queries from there to each CoreDNS pod. For CoreDNS pods on other nodes, these are **cross-node** requests, which is exactly the path the kubelet's local probes never test. When a CoreDNS pod is repeatedly unreachable (`CoreDNSUnreachable`), its CoreDNS remediation restarts that pod. The new pod gets a new IP, usually on a healthy node, which is the same fix a person would apply manually.

In the cases above, these checks detected the problem within minutes. With remediation enabled, an impact that lasted between one and several hours would have been reduced to minutes.
