---
title: "Accelerate DNS Performance with LocalDNS"
description: "Discover how LocalDNS transforms DNS performance in AKS clusters with 10x latency reduction and enhanced reliability"
date: 2025-08-02 # date is important. future dates will not be published
author: Vaibhav Arora # must match the authors.yml in the _data folder
categories: 
- general 
- networking
---

DNS performance issues can cripple production Kubernetes clusters, causing application timeouts and service outages. LocalDNS in AKS solves this by moving DNS resolution directly to each node, delivering 10x faster queries and improved reliability. In this post, we share the results from our internal tests showing exactly how much of an improvement LocalDNS can make and how it can benefit your cluster.

## Background: The Hidden Cost of DNS in Production Kubernetes

In Kubernetes clusters, DNS is the invisible backbone that enables service discovery and inter-pod communication, but its critical role often goes unnoticed until it becomes a bottleneck. DNS-related issues are among the most challenging operational problems. What begins as minor performance degradation can quickly escalate into customer-impacting incidents and even full-scale outages. As cluster size grows, the complexity of DNS management increases exponentially. A configuration that works for a small development environment may prove completely inadequate at production scale, exposing fundamental architectural limitations that can threaten the reliability and scalability of the entire system.

### Why Centralized CoreDNS Becomes a Bottleneck in Kubernetes Clusters

Traditional DNS was built for static, predictable environments with long-lived hosts and low query volumes. Kubernetes, however, is dynamic and high-churn:

- **Ephemeral workloads**: Pods are rapidly created and destroyed, each needing immediate DNS resolution
- **High query volume**: Service meshes, health checks, and inter-service calls generate thousands of DNS queries per second
- **Dynamic endpoints**: Services and pods frequently change IPs, requiring constant DNS updates and cache invalidation
- **Complex networking**: Multiple network layers (pod, service, ingress) add latency and increase DNS infrastructure load

These differences turn DNS from a background service into a critical bottleneck as clusters grow. Relying on a handful of centralized CoreDNS pods exposes architectural weaknesses: all DNS queries are funneled through these pods, creating a single point of contention and introducing network overhead with every lookup. High query volumes can overwhelm conntrack tables, and centralized caching misses the benefits of local cache hits—forcing even repeated queries to traverse the network.

The result? Application timeouts, resource exhaustion, cascading failures, and increased operational burden. Without rethinking DNS architecture, teams face increased latency, reliability issues, and operational headaches at scale. LocalDNS addresses these challenges by decentralizing DNS resolution—moving the cache and resolver directly onto each node, closer to every workload.

## Introducing LocalDNS for Faster, More Reliable DNS Resolution

To address these fundamental architectural challenges, AKS introduces LocalDNS—a node-level DNS proxy that transforms how DNS resolution works in Kubernetes clusters. LocalDNS represents a shift from centralized DNS resolution to a distributed, resilient architecture that brings DNS responses closer to the workloads that need them. By deploying a DNS proxy directly on each node as a systemd service, LocalDNS eliminates the network hop to centralized DNS pods, dramatically reducing latency while improving overall cluster resilience.

## How We Tested LocalDNS

To evaluate the impact of LocalDNS, we conducted parallel tests across two AKS clusters: one with LocalDNS enabled on all nodes and another using only centralized CoreDNS. In both environments, we generated a sustained load of 10,000 DNS queries per second (QPS) using industry-standard tools like `dnsperf` and `resperf`. This allowed us to observe query distribution across CoreDNS pods, measure resolution success rates, and compare end-to-end DNS lookup latencies.

## The Results

### 1. Improved DNS Query Resolution Times

The graphs below demonstrate a substantial reduction in DNS query resolution times across all percentiles (P50, P95, P99) when LocalDNS is enabled. LocalDNS consistently delivers faster responses, with >10x lower latency and significant tail latency reduction at the P99 scale. These improvements apply to both internal cluster traffic and external domain resolution. 

#### Resolution Time for Cluster Traffic (cluster.local)

![DNS resolution times for internal cluster traffic showing LocalDNS performance improvements](/assets/images/accelerate-dns-performance-with-localdns/inclustertraffic.png)

#### Resolution Time for External Domain Traffic

![DNS resolution times for external domain traffic showing LocalDNS performance improvements](/assets/images/accelerate-dns-performance-with-localdns/externaltraffic.png)

### 2. Better Distribution of Requests Across CoreDNS Pods

The pie charts below show the dramatic improvement in traffic distribution across CoreDNS pods when LocalDNS is enabled. In the centralized setup, nearly all DNS traffic (99.9%) is handled by a single CoreDNS pod (because of the use of UDP protocol), creating a significant bottleneck. With LocalDNS, the split shifts to a much healthier 40%/59.9% distribution, demonstrating balanced load and improved scalability.

![Traffic distribution comparison showing improved load balancing across CoreDNS pods with LocalDNS](/assets/images/accelerate-dns-performance-with-localdns/trafficdistribution.png)

### 3. Additional Operational Improvements

Beyond performance gains, LocalDNS provides critical operational benefits that improve cluster reliability and reduce maintenance overhead:

- **Stale cache serving during upstream DNS outages**: LocalDNS can serve DNS responses from its local cache even if the upstream CoreDNS or external DNS servers become temporarily unavailable. This ensures that workloads continue to resolve frequently used names without interruption, improving resilience during intermittent DNS outages.

- **No conntrack table entries created for each connection**: With LocalDNS running as a node-level service, DNS queries from pods are resolved locally, eliminating the need for each DNS request to traverse the node’s network stack and create conntrack entries. This reduces pressure on the node’s conntrack table, lowering the risk of resource exhaustion and related networking issues.

- **Fewer DNS queries reaching CoreDNS**: By caching responses at the node level, LocalDNS dramatically reduces the number of queries that need to be forwarded to the centralized CoreDNS pods. This offloads traffic from CoreDNS, decreases overall DNS infrastructure load, and further improves cluster scalability and reliability.

## Conclusion

LocalDNS transforms DNS delivery in AKS clusters by providing faster resolution, greater reliability, and streamlined operations for production workloads. By decentralizing DNS and placing resolution closer to each node, LocalDNS eliminates common bottlenecks and empowers teams to scale with confidence.

We invite you to enable LocalDNS in your AKS clusters and experience the benefits firsthand. Your feedback helps us evolve this feature—please share your insights, report issues, or suggest enhancements by opening a [GitHub issue](https://github.com/Azure/AKS/issues).

For a deeper dive into LocalDNS architecture and step-by-step guidance on activation, visit our [official documentation](https://aka.ms/aks-localdns).