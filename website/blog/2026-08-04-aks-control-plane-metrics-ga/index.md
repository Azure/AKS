---
title: "AKS Control Plane Metrics Now GA with Managed Prometheus"
date: "2026-08-04"
description: "Control plane metrics for AKS components like the API server and etcd are now GA via Azure Monitor managed Prometheus. Here are five metrics to monitor first."
authors: ["reshmi-mangalore", "david-kydd", "sunayana-singh"]
tags:
  - metrics
  - monitoring
  - azure-monitor
  - observability
---

We're excited to announce that **control plane metrics collection for Azure Kubernetes Service (AKS)**, powered by **Azure Monitor managed service for Prometheus**, is now **generally available**. AKS clusters that were previously enabled for control plane metrics during preview are automatically enabled and continue to collect control plane metrics after general availability, so no action is required from existing preview customers.

<!-- truncate -->

![Example AKS control plane metrics dashboard in Grafana](./ControlPlaneMetrics.png)

This capability gives AKS customers native observability into key managed control plane components, including the **API server**, **etcd**, **kube-scheduler**, **kube-controller-manager**, **Cluster Autoscaler**, and **node auto-provisioning**. With these metrics, platform teams can better understand how workloads, controllers, automation, and scaling activity interact with the AKS control plane over time.

AKS manages the control plane's patching, high availability, and infrastructure-level health on your behalf. But a slow API server or an etcd database nearing its storage quota still shows up to *you* as stalled deployments, timeouts, or delayed autoscaling. Without visibility into control plane behavior, teams typically only discover these issues after workloads are already impacted, and diagnosing them usually means opening a support case and waiting on backend telemetry. Control plane metrics close that gap by giving you the same signals directly, in near real time.

With control plane metrics now generally available, customers can collect this data through Azure Monitor managed service for Prometheus and visualize it in Grafana without deploying or managing additional control plane monitoring infrastructure.

**Key Benefits:**

- **Faster root-cause analysis**: With control plane metrics flowing into Azure Monitor managed service for Prometheus, you can quickly determine whether slow deployments or request timeouts originate from client-side behavior, API server load, or etcd health—so your team spends less time hypothesizing and more time resolving
- **Proactive incident prevention**: Set alerts on API Priority and Fairness throttling, request latency, watch-cache lag, and etcd quota pressure to catch emerging issues early—before they cascade into cluster-wide impact.
- **Self-serve diagnostics**: Investigate performance concerns directly in Azure Managed Grafana using out-of-the-box dashboards and PromQL, reducing the need to open a support case for every slowdown and giving your platform teams a clear, shared view of cluster health.
- **Inform architectural decisions**:  Gain visibility into real-world API traffic patterns from your controllers, CI/CD pipelines, and automation. Use those insights to right-size retries, polling intervals, and admission webhooks as your workloads grow.
- **Zero infrastructure to manage**:  Azure Monitor managed service for Prometheus is built into AKS, so there are no separate exporters to deploy, scrape configurations to maintain, or additional monitoring stacks to operate. Enable it once and start monitoring right away.

This post explains how to enable control plane metrics collection and highlights **five high-signal metrics** every AKS customer should monitor first.

## Why start with the API server and etcd?

When it comes to understanding the health and responsiveness of your AKS cluster, the API server and etcd are the two components that matter most.

The API server is the front door to Kubernetes. Every interaction whether from kubectl, your controllers and operators, CI/CD pipelines, autoscalers, admission webhooks, or in-cluster automation flows through it. etcd serves as the highly consistent, distributed key-value store that persists the state of every object in your cluster.

If either component is under pressure, the impact is felt across the entire cluster. Deployments can stall, pod scheduling slows, controllers fall behind on reconciliation, and everyday operations begin to feel sluggish. That's why API server and etcd metrics are the right foundation for AKS control plane observability and the best place to begin as you build out a monitoring strategy for your platform.

## Enable control plane metrics collection

Control plane metrics can be enabled using the Azure CLI or the Azure portal. For complete setup instructions, see [Monitor AKS control plane metrics](https://learn.microsoft.com/azure/aks/control-plane-metrics-monitor).

When enabled, AKS control plane metrics can be collected by Azure Monitor managed service for Prometheus and queried from Grafana using PromQL.

Collection can be customized through the Azure Monitor metrics configuration. Two settings are especially important when getting started:

| Setting | Purpose |
|---|---|
| `controlplane-metrics.default-targets-scrape-enabled` | Controls which control plane targets are scraped |
| `controlplane-metrics.minimal-ingestion-profile` | Restricts collection to a curated metric set to help manage ingestion volume and cost |

Supported control plane scrape targets include:

- `apiserver`
- `etcd`
- `kube-scheduler`
- `kube-controller-manager`
- `cluster-autoscaler`
- `node-auto-provisioning`

We recommend starting with the default API server and etcd metrics, then enabling additional targets based on the scenarios you need to diagnose, such as scheduling latency or autoscaler behavior. You can set [controlplane-metrics.minimal-ingestion-profile to false](https://learn.microsoft.com/en-us/azure/aks/control-plane-metrics-monitor#ingest-all-metrics-from-all-targets) to ingest all metrics from all targets.

## The 5 metrics to monitor first

The following five metrics provide a practical starting point for AKS control plane monitoring. They help identify API server throttling, expensive requests, server-side failures, etcd storage pressure, and etcd disk latency.

### 1. API server request throttling: 429 responses

A 429 response means the API server rejected or delayed a request due to throttling or fairness controls. This is often the earliest signal that a client, controller, script, or CI/CD pipeline is generating excessive API load.

**PromQL**

```promql
sum by (client, verb, resource) (
  rate(apiserver_request_total{code="429"}[5m])
)
```

**Recommended alert:** Alert when the 429 rate for a client is sustained above zero for 5 minutes.

**Why it matters:** Frequent 429s usually indicate that a client needs rate limiting, pagination, reduced polling, or retry-with-backoff behavior.

**Find the top offending clients**

```promql
topk(5,
  sum by (client) (
    rate(apiserver_request_total{code="429"}[15m])
  )
)
```

### 2. LIST request latency

A LIST request retrieves all objects of a given resource type. LIST calls are more expensive than targeted GET calls, especially for high-cardinality resources such as Pods, Events, Secrets, ConfigMaps, or custom resources.

**PromQL**

```promql
histogram_quantile(
  0.99,
  sum by (le, resource) (
    rate(apiserver_request_duration_seconds_bucket{verb="LIST"}[5m])
  )
)
```

**Recommended alert:** Alert when p99 LIST latency for any resource exceeds 1 second for 5 minutes.

**Why it matters:** High LIST latency often points to controllers or jobs issuing expensive unpaginated queries. This can create broad API server pressure and affect unrelated workloads.

**Find clients issuing LIST calls**

```promql
topk(5,
  sum by (client, resource) (
    rate(apiserver_request_total{verb="LIST"}[15m])
  )
)
```

### 3. API server 5xx error rate

A 429 response indicates throttling or backpressure. A 5xx response indicates that the API server attempted to process a request and failed.

**PromQL**

```promql
sum(rate(apiserver_request_total{code=~"5.."}[5m]))
/
sum(rate(apiserver_request_total[5m]))
```

**Recommended alert:** Alert when the 5xx error rate exceeds 5% for 5 minutes.

**Why it matters:** A sustained 5xx rate can indicate an underlying control plane issue, etcd health problem, timeout, or dependency failure. When this alert fires, etcd health should be reviewed next.

**Break down by verb and resource**

```promql
sum by (verb, resource) (
  rate(apiserver_request_total{code=~"5.."}[5m])
)
```

### 4. etcd database size relative to quota

etcd enforces a backend storage quota. If the database approaches the quota, write availability can be affected until space is reclaimed.

**PromQL**

```promql
max(etcd_mvcc_db_total_size_in_bytes)
/
max(etcd_server_quota_backend_bytes)
```

**Recommended alert:** Alert when the ratio exceeds 80% for 10 minutes.

**Why it matters:** etcd growth is often caused by accumulated completed Jobs, retained ReplicaSets, excessive Events, or high object churn. Customers should review object retention patterns and cleanup policies before the database approaches quota.

**Track growth rate**

```promql
rate(etcd_mvcc_db_total_size_in_bytes[1h])
```

### 5. etcd disk WAL fsync latency

Every etcd write must be durably flushed to the write-ahead log before it is acknowledged. Disk latency here directly affects write performance for cluster state changes.

**PromQL**

```promql
histogram_quantile(
  0.99,
  sum by (le) (
    rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])
  )
)
```

**Recommended alert:** Alert when p99 WAL fsync latency exceeds 100 ms for 5 minutes.

**Why it matters:** Healthy clusters typically maintain low fsync latency. Elevated latency can cause slower writes, delayed controller progress, and broader API responsiveness issues.

**Check leader stability**

```promql
(etcd_server_has_leader == 0)
or
(increase(etcd_server_leader_changes_seen_total[15m]) > 3)
```

## Recommended next steps

1. Enable Azure Monitor managed service for Prometheus for your AKS cluster.
2. Turn on AKS control plane metrics collection and start with API server and etcd metrics.
3. Keep the minimal ingestion profile enabled unless you need additional diagnostic coverage.
4. Start from the out-of-the-box Grafana dashboards available for monitoring AKS etcd and API server metrics, as shown in the example dashboard above or build a custom Grafana dashboard. 
5. [Configure alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-metric-alerts?tabs=portal) for throttling, LIST latency, 5xx rate, etcd quota usage, and etcd WAL fsync latency — so you can catch these issues before they affect production.
6. Review trends after 30 days to understand your normal control plane behavior and identify recurring pressure patterns.

If you consistently observe throttling, high LIST latency, or elevated request volume during normal operations, review the clients and controllers generating API traffic. Common improvements include adding client-side rate limiting, reducing polling frequency, using watches instead of repeated LIST calls, enabling pagination, and cleaning up high-cardinality objects such as completed Jobs and Events. 

## Learn more

- [Monitor AKS control plane metrics](https://learn.microsoft.com/azure/aks/control-plane-metrics-monitor)
- [Minimal ingestion profile for control plane metrics](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration-minimal)
- [Troubleshoot common issues with API server and etcd](https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/create-upgrade-delete/troubleshoot-apiserver-etcd?tabs=resource-specific)
- [Best practices for performance and scaling for large workloads in Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/best-practices-performance-scale-large#aks-and-kubernetes-control-plane-scalability)

If you have configured these alerts and continue to experience unresolved control plane issues, open an Azure support case and attach the relevant Grafana dashboards or PromQL query results. This helps accelerate investigation by providing the API server and etcd signals needed to identify the likely bottleneck.

## Looking ahead

Control plane observability is an ongoing investment for AKS, and general availability of these metrics is just one step. We'll continue expanding the set of high-signal metrics, refining default alert guidance, and improving the out-of-the-box Grafana dashboards based on what we learn from customers running at scale.

We would love to hear from you. If you have feedback, run into issues, or want to request additional control plane metrics or dashboards, please share it by opening an issue on our [GitHub project](https://github.com/Azure/AKS).
