---
title: "Control plane metrics are GA: Keep your API server healthy"
date: 2026-10-15
description: "AKS control plane metrics are now generally available. Monitor API server and etcd health with Azure Monitor managed Prometheus, PromQL, and Grafana today."
authors: [reshmi-mangalore, david-kydd]
tags: [monitoring, observability, metrics, azure-monitor, grafana, troubleshooting]
keywords: ["AKS", "control plane metrics", "API server", "etcd", "Prometheus", "Azure Monitor", "APF"]
---

Control plane metrics collection for Azure Kubernetes Service (AKS) is now generally available. Powered by Azure Monitor managed service for Prometheus, the feature collects API server and etcd metrics by default. You can also enable kube-scheduler, kube-controller-manager, Cluster Autoscaler, and node auto-provisioning targets where they're available.

Clusters that enabled control plane metrics during preview keep collecting at GA with no action required. New clusters and clusters without preview enablement can follow the setup steps below.

This post covers how to enable collection, how to tune what you ingest, and which API server signals to watch first.

<!-- truncate -->

## Why control plane visibility matters

AKS manages control plane patching, high availability, and infrastructure health for you. Even so, a slow API server or an etcd database nearing its storage quota can show up in your environment as stalled deployments, request timeouts, or delayed autoscaling.

Without visibility into the control plane, investigating these symptoms often meant opening a support case. Control plane metrics make key signals queryable in your own Azure Monitor workspace, so you can do first-pass investigation yourself:

- **Faster investigation**: Determine whether control plane pressure might be contributing to slow deployments or timeouts.
- **Proactive monitoring**: Track sustained latency, errors, and throttling before they cause wider impact.
- **Self-serve diagnostics**: Use PromQL and Grafana dashboards to narrow down next steps.
- **Data-informed tuning**: Use request dimensions such as verb and resource to inform retry, polling, and admission webhook tuning.
- **No self-hosted stack**: Collection runs through the AKS and Azure Monitor integration, with no exporters or Prometheus servers to manage.

> **Note**: Metrics support investigation but don't identify individual clients or prove root cause on their own. Issues that require AKS backend investigation still need a support case.

## Enable control plane metrics

Control plane metrics use the Azure Monitor managed service for Prometheus (the Azure Monitor metrics add-on) and store data in an Azure Monitor workspace. Your cluster must use [managed identity](https://learn.microsoft.com/azure/aks/use-managed-identity).

For a new cluster, enable the add-on and control plane collection together:

```bash
az aks create \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-azure-monitor-metrics \
  --enable-control-plane-metrics
```

For an existing cluster that already has the managed Prometheus add-on:

```bash
az aks update \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-control-plane-metrics
```

If your cluster doesn't have the add-on yet, first [enable monitoring for your AKS cluster](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable). For full prerequisites, see [Monitor AKS control plane metrics](https://learn.microsoft.com/azure/aks/control-plane-metrics-monitor). Allow several minutes for metrics to appear in the workspace.

To visualize the data, [connect Azure Managed Grafana to your Azure Monitor workspace](https://learn.microsoft.com/azure/managed-grafana/how-to-connect-azure-monitor-workspace). The Grafana managed identity needs the **Monitoring Data Reader** role on the workspace. Then import the [API server dashboard (20331)](https://grafana.com/grafana/dashboards/20331) and optionally the [etcd dashboard (20330)](https://grafana.com/grafana/dashboards/20330). The feature doesn't provision these dashboards automatically.

## Tune targets and ingestion

The API server and etcd are enabled by default. Other targets are supported but off by default, and availability depends on your cluster configuration.

You customize collection with the `ama-metrics-settings-configmap` in the `kube-system` namespace. The ConfigMap might not exist by default, so start from the [current version on Microsoft Learn](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration). Here's the schema v2 control plane section:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ama-metrics-settings-configmap
  namespace: kube-system
data:
  schema-version: v2
  controlplane-metrics: |-
    default-targets-scrape-enabled: |-
      apiserver = true
      etcd = true
      kube-scheduler = false
      kube-controller-manager = false
      cluster-autoscaler = false
      node-auto-provisioning = false
    minimal-ingestion-profile: |-
      enabled = true
```

Keep these points in mind:

- **Keep the minimal ingestion profile on.** It's enabled by default and limits ingestion to the metrics used by default dashboards, recording rules, and alerts. Disabling it can significantly increase ingestion volume and cost.
- **Add metrics with keep lists.** When you need more metrics, add a target-specific keep list instead of disabling the profile.
- **Don't mix schema versions.** Schema v1 uses legacy key names. Don't combine v1 and v2 keys.
- **Verify after applying.** Validation is advisory, so invalid settings can still be applied. Confirm the expected targets and metrics appear in your workspace.

### Enable latency percentiles

The minimal ingestion profile retains only the `le="+Inf"` bucket of `apiserver_request_duration_seconds_bucket`. That's enough for average latency through `_sum` and `_count`, but not for percentiles. To calculate percentiles with `histogram_quantile`, merge this keep list into your ConfigMap and apply it:

```yaml
data:
  controlplane-metrics: |-
    default-targets-metrics-keep-list: |-
      apiserver = "apiserver_request_duration_seconds_bucket|apiserver_request_duration_seconds_sum|apiserver_request_duration_seconds_count"
```

```bash
kubectl apply -f configmap-controlplane.yaml
```

Then verify that finite bucket boundaries appear in your workspace. For the list of metrics collected by default, see [default Prometheus metrics configuration](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-default).

## Start with the API server

Every interaction with your cluster flows through the API server: `kubectl`, controllers and operators, CI/CD pipelines, autoscalers, and admission webhooks. When it's under pressure, deployments stall, scheduling slows, and controllers fall behind. The key question isn't whether the API server is running, but whether it's keeping up with demand.

| Signal | Example metric | What it tells you |
| --- | --- | --- |
| Request volume and mix | `apiserver_request_total` | Request rate and verb/resource mix |
| Errors and throttling | `apiserver_request_total{code="429"}`, `{code=~"5.."}` | Throttled and failed requests |
| Request latency | `apiserver_request_duration_seconds_*` | Average latency, or percentiles with full buckets |
| In-flight requests | `apiserver_current_inflight_requests` | Current concurrency |
| APF demand vs. capacity | `apiserver_flowcontrol_demand_seats_average`, `apiserver_flowcontrol_current_limit_seats` | Demand and seat limit by priority level |
| LIST fan-out | `apiserver_storage_list_fetched_objects_total`, `apiserver_storage_list_returned_objects_total` | Objects fetched vs. returned for LIST calls |
| Availability | `up{job="controlplane-apiserver"}` | Whether the API server target is reachable |

These are examples. A series appears only if the enabled target exposes it and your ingestion profile or keep list retains it. If multiple clusters share a workspace, keep the `cluster` label in your aggregations so baselines don't mix.

### Request volume and mix

```promql
sum by (cluster, verb) (rate(apiserver_request_total[5m]))
```

High volume alone isn't a problem. Large clusters legitimately generate significant traffic. Watch for volume growing alongside latency, APF pressure, or errors, especially when `LIST`, `WATCH`, `PATCH`, or `UPDATE` dominate the growth.

### Errors and throttling

Sustained 429 and 5xx responses are among the clearest signs of control plane pressure:

```promql
100 * sum by (cluster) (rate(apiserver_request_total{code="429"}[5m]))
    / sum by (cluster) (rate(apiserver_request_total[5m]))
```

- **Healthy**: 429 and 5xx responses are absent or isolated.
- **Warning**: Intermittent 429 responses during traffic bursts.
- **Investigate**: Sustained 429 responses, or 5xx responses with rising latency.

### Request latency

```promql
sum by (cluster) (rate(apiserver_request_duration_seconds_sum[5m]))
  / sum by (cluster) (rate(apiserver_request_duration_seconds_count[5m]))
```

Compare latency against a per-cluster baseline rather than a universal threshold. `LIST` operations can be much more expensive than `GET` or `UPDATE`.

### In-flight requests

```promql
sum by (cluster, request_kind) (apiserver_current_inflight_requests)
```

In-flight requests often move before latency or errors do. They should rise during bursts and return to baseline. Sustained elevation, especially with rising APF demand and latency, indicates ongoing pressure.

### API Priority and Fairness

[API Priority and Fairness (APF)](https://kubernetes.io/docs/concepts/cluster-administration/flow-control/) controls how concurrency is shared across classes of API traffic. Compare demand to available seats for each priority level:

```promql
sum by (cluster, priority_level) (apiserver_flowcontrol_demand_seats_average)
  / sum by (cluster, priority_level) (apiserver_flowcontrol_current_limit_seats)
```

A ratio that stays near 1 means a priority level is consistently near its limit. That doesn't prove requests were rejected, so correlate it with response codes and latency.

### LIST fan-out

```promql
sum by (cluster, resource) (rate(apiserver_storage_list_fetched_objects_total[5m]))
sum by (cluster, resource) (rate(apiserver_storage_list_returned_objects_total[5m]))
```

A large gap between fetched and returned objects means the API server read far more from storage than it returned. For large clusters, this is a useful clue, but it doesn't identify the client. Correlate with client-side telemetry before drawing conclusions.

### Availability

`up{job="controlplane-apiserver"}` confirms the API server is reachable, and `process_start_time_seconds` reveals restarts. Availability alone isn't enough, though: an overloaded API server can report as up while barely responding.

## A recommended investigation flow

When you suspect a control plane issue, work through the signals in this order:

1. **Availability**: Is the API server reachable and running steadily?
2. **Errors**: Are there sustained 429 or 5xx responses?
3. **Latency**: Is `LIST` or non-`LIST` latency drifting?
4. **In-flight requests**: Are requests draining normally?
5. **APF seats**: Which priority levels sit at their limits?
6. **LIST volume**: Is any resource showing unusual fan-out?
7. **Request rate by verb and resource**: Which dimensions drive the change?

Rising latency combined with APF pressure and 429 responses is a strong reason to review client-side telemetry, controller configuration, or APF settings. To alert on these signals, configure [Prometheus rule groups](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-rule-groups) and [Prometheus metric alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/prometheus-alerts). Treat the guidance above as a starting point and use a short persistence window to avoid paging on transient spikes.

## GA limitations

- Collection requires Azure Monitor managed service for Prometheus. Self-hosted or bring-your-own Prometheus isn't supported.
- Azure Private Link isn't supported for the control plane metrics ingestion path.
- The cluster must use managed identity.
- Only `ama-metrics-settings-configmap` in `kube-system` can customize control plane collection.

## Get started

1. Enable the Azure Monitor metrics add-on and control plane metrics on your cluster.
2. Connect Azure Managed Grafana and import the API server (20331) and etcd (20330) dashboards.
3. Establish a baseline for each production cluster.
4. Build and validate PromQL alert rules tuned to that baseline.

Next in this series, we'll take a deep dive into etcd metrics and how to interpret them. We'd love to hear what you learn about your clusters. Share feedback on the [AKS GitHub repository](https://github.com/Azure/AKS/issues).
