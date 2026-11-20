---
title: "When CoreDNS Looks Healthy but DNS Still Fails"
date: "2026-11-06"
description: "Learn why a few DNS queries fail during AKS upgrades and why one unreachable CoreDNS pod breaks DNS, and how LocalDNS and Cluster Health Monitor help."
authors: ["mitch-shao"]
tags:
  - dns
  - networking
  - troubleshooting
keywords: ["AKS", "Azure Kubernetes Service", "CoreDNS", "DNS", "conntrack", "kube-proxy", "LocalDNS", "Cluster Health Monitor"]
---

Your workloads depend on reliable DNS resolution, but DNS failures can be difficult to diagnose—even when CoreDNS appears healthy. This article walks you through two failure scenarios we often see on AKS, explains what causes them, and shows you how to mitigate them:

- **During cluster upgrades, a very small number of DNS queries fail or time out.** The cause is stale UDP conntrack entries left behind when CoreDNS pods are replaced.
- **One CoreDNS pod becomes unreachable because of an unstable node or network, and a share of DNS queries keeps failing until CoreDNS is restarted.**

<!-- truncate -->

## Scenario 1: A Small Number of DNS Queries Fail During Cluster Upgrades

During cluster upgrades, you may occasionally notice a small number of DNS queries fail or time out. These failures are intermittent and can be difficult to reproduce. We were able to reproduce them only under heavy DNS traffic with many concurrent queries.

In this scenario, the failures are caused by **stale entries in the conntrack table**, which tracks network flows. After a CoreDNS pod is replaced, some queries match an existing entry that still points to the old pod's IP address, so they are sent to a pod that no longer exists. The sections below explain how this happens.

### DNAT and Conntrack

A pod sends DNS queries to the kube-dns Service ClusterIP, for example `10.0.0.10:53/UDP`. kube-proxy then forwards each query to a CoreDNS pod:

1. The first packet goes through kube-proxy's iptables (or IPVS) rules. One CoreDNS pod is chosen, for example `10.244.1.5`, and the packet's destination is rewritten to it (DNAT).
2. The kernel's connection tracker, conntrack, records this decision:

   ```text
   original: 10.244.2.8:34567 -> 10.0.0.10:53      <- lookup key
   reply:    10.244.1.5:53 -> 10.244.2.8:34567     <- NAT result
   ```

3. Conntrack identifies the entry by its 5-tuple: protocol, source IP, source port, destination IP, and destination port. In this example, with PodA at `10.244.2.8`, the 5-tuple is:

   ```text
   (UDP, 10.244.2.8, 34567, 10.0.0.10, 53)
   ```

   Any later packet with exactly this 5-tuple reuses the entry and goes straight to `10.244.1.5`. **The NAT rules are not evaluated again.** Each matching packet also resets the entry's timeout. A packet from a different source port, such as `34568`, has a different 5-tuple and gets its own entry.

One detail matters for everything that follows: **conntrack looks entries up by the original 5-tuple, which contains the ClusterIP, not the pod IP.**

### UDP Creates a Large Number of conntrack Entries

With TCP, many requests share one long-lived connection, so the conntrack table holds few TCP entries.

UDP is different. It has no connections, so there is nothing to keep open and reuse. A typical DNS client opens a separate socket for each query, and each socket gets its own random source port. That means every DNS query has its own 5-tuple, and therefore **its own conntrack entry**. Because there's no connection, nothing ever closes these entries either: each one stays in the table until it times out, or until someone deletes it.

How long an entry stays is controlled by kernel parameters. A DNS query and its reply finish within milliseconds, so the entry gets the short timeout, `net.netfilter.nf_conntrack_udp_timeout`, which defaults to **30 seconds**. The longer `nf_conntrack_udp_timeout_stream` (120 seconds by default) applies only to flows that keep exchanging packets for more than two seconds.

With heavy DNS traffic, these per-query entries add up quickly: thousands of queries per second leave tens of thousands of UDP entries in the conntrack table, each one waiting to time out.

Each of these entries holds a DNAT decision: traffic from a specific source port goes to a specific CoreDNS pod. As long as the entry exists, the decision stands.

The problem comes from **reusing these entries**. When CoreDNS is restarted, for example during a rolling update, the old pod is deleted, but its conntrack entries stay in the table until kube-proxy removes them, usually a few seconds later (see the next section). If a query reuses the same source port before they're removed, it has the same 5-tuple and matches the old entry. The query is sent to the IP of a pod that no longer exists.

So what's the probability of this in practice? The gap before kube-proxy cleans up is only a few seconds, but because each entry lives for 30 seconds, a lot of entries pointing to the old pod have piled up by then. A quick calculation for a single pod:

1. **Available source ports:** the default ephemeral port range is 32768–60999, so there are 60999 − 32768 + 1 = **28,232 ports**.
2. **Entries pointing to the old pod:** each entry stays for 30 seconds, so a pod has about QPS × 30 entries. With N CoreDNS replicas, about 1/N of them point to the pod being replaced.
3. **Chance a new query hits one:** (QPS × 30 / N) / 28,232.

For example, a pod sending 200 DNS queries per second with 3 CoreDNS replicas has about 200 × 30 / 3 = 2,000 entries pointing to the old pod, so about 2,000 / 28,232 ≈ **7%** of its queries during the gap hit a stale entry. That's why only a small number of queries fail, and only when DNS traffic is heavy.

### Kubernetes Cleans Up When a Pod Is Deleted, but That Doesn't Fully Solve It

When a pod is deleted, kube-proxy does clear its UDP conntrack entries (see [`pkg/proxy/conntrack/cleanup.go`](https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/conntrack/cleanup.go)). But the cleanup isn't instant. After the CoreDNS process exits, the change still has to reach kube-proxy, and kube-proxy has to sync before it deletes the entries.

Clearing these entries earlier, during the pod's termination grace period, would close this gap. This was proposed upstream ([kubernetes/kubernetes#132635](https://github.com/kubernetes/kubernetes/issues/132635)), but kube-proxy doesn't work this way today.

This is a Kubernetes-wide behavior. Any UDP traffic that passes through a Service handled by kube-proxy is exposed to it.

> **Scope:** This section describes the kube-proxy dataplane (iptables or IPVS). Clusters that use Azure CNI powered by Cilium replace kube-proxy with eBPF socket load balancing, which behaves differently and isn't covered here.

### How LocalDNS Helps

We recommend enabling [LocalDNS](https://learn.microsoft.com/en-us/azure/aks/localdns-custom) on AKS. LocalDNS runs a DNS cache on every node, and pods send their queries to it instead of the kube-dns ClusterIP. The node cache answers most queries without going to CoreDNS at all. LocalDNS still forwards cache misses to CoreDNS through the ClusterIP, but it handles them differently:

- **Cluster names (`cluster.local`)** are forwarded over TCP by default, so they don't create the per-query UDP conntrack entries described above.
- **Other names** are forwarded over UDP by default, so a forwarded query can still hit a stale conntrack entry. The difference is in how it recovers. If a forwarded query times out, LocalDNS closes that socket and retries on a new one. The new socket gets a new source port, so in most cases the retry gets a new conntrack entry and is DNATed to a live CoreDNS pod. The failed attempt costs about 2 seconds, which is within the default 5-second timeout of the DNS resolver in your pods, so your application typically sees a slower answer instead of a failure.

Starting with Kubernetes 1.37, AKS enables LocalDNS automatically (`Preferred` mode) on node pools that pass its compatibility checks. One of these checks is easy to miss: on clusters that use Cilium or Calico, LocalDNS stays disabled if any network policies are present (other than the default `kube-system/konnectivity-agent` policy), even if they allow DNS traffic. On those clusters, review your policies and enable LocalDNS explicitly.

For more about LocalDNS, see:

- [Configure LocalDNS in Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/localdns-custom)
- [Accelerate DNS performance with LocalDNS](https://blog.aks.azure.com/2025/08/04/accelerate-dns-performance-with-localdns)

## Scenario 2: One CoreDNS Pod Becomes Unreachable, and a Share of DNS Queries Keeps Failing

Occasionally, you may see DNS failures that don't resolve on their own. A consistent share of queries, such as 20–30%, keeps failing or timing out for minutes or even hours. Restarting CoreDNS fixes it immediately.

### Why This Happens

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

### How Cluster Health Monitor Helps

[Cluster Health Monitor](https://learn.microsoft.com/en-us/azure/aks/cluster-health-monitor) (preview) closes this gap. It runs on a system node and sends DNS queries from there to each CoreDNS pod. For CoreDNS pods on other nodes, these are **cross-node** requests, which is exactly the path the kubelet's local probes never test. An unreachable pod shows up as a `PodTimeout` or `PodError` result.

With CoreDNS remediation, Cluster Health Monitor then deletes the unhealthy pod and Kubernetes recreates it with a new IP, which is the same fix you would apply manually. It does this only when all of the following are true:

- Exactly one CoreDNS pod has been continuously unhealthy for at least five minutes.
- At least one other CoreDNS pod is healthy.
- No CoreDNS remediation has run in the last hour.

The new pod isn't guaranteed to move to a different node. If it lands on the same faulty node, it can still be unreachable, and you need to repair or replace that node.

In the cases above, these checks detected the problem within minutes. With remediation enabled, an impact that lasted between one and several hours could have been reduced to minutes.
