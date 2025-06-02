---
title: "Native Grafana Dashboards in Azure Portal"
description: "Explore the new Grafana dashboards built directly into Azure Monitor and learn how they empower observability and when to reach for Azure Managed Grafana."
date: 2025-05-29
author: aritraghosh, kayodeprince
categories: 
- operations
---

## High-Level Overview and Blog Structure

### Introduction

Azure Kubernetes Service (AKS) now offers native Grafana dashboards within the Azure portal at no additional cost. This integration enables users to access Grafana’s powerful visualization capabilities directly from the AKS resource blade, without the need to deploy or manage a separate Grafana instance. Metrics from Container Insights, the Kubernetes metrics server, and any configured Azure Managed Prometheus endpoints are available out-of-the-box, providing comprehensive cluster observability.

To get started, navigate to your AKS cluster in the Azure portal and select **Monitoring** > **Dashboards with Grafana (preview)**. You will be presented with prebuilt dashboards for cluster health, node utilization, and pod performance. From there, you may edit and ad  panels, configure template variables scoped to namespaces or node pools, and save custom dashboards - all within the familiar AKS management experience. By eliminating additional infrastructure overhead, this feature streamlines troubleshooting workflows and delivers actionable insights to SRE and DevOps teams with minimal effort.

### Why Grafana in Azure Monitor?

Grafana is celebrated for its rich panel types, templating engine, and client-side data transformations. Embedding it natively in Azure Monitor offers:

- Unified experience: No extra authentication or network configuration—just use your Azure login.
- Single-pane observability: Combine Azure Metrics, Logs, and Application Insights data alongside and other Azure data sources supported by Grafana.
- Rapid onboarding: Spin up dashboards in minutes using familiar Azure workflows and templates.

These capabilities mean faster troubleshooting, deeper insights, and a more consistent observability platform for Azure-centric workloads.

### When to upgrade to Azure Managed Grafana?

While Dashboards with Grafana in the Azure portal cover most common visualization scenarios, Azure Managed Grafana remains the right choice for advanced use cases, including:

- Extended plugin support (including open-source and community plugins).
- Advanced authentication, provisioning APIs, and fine-grained access control.
- Multi-cloud and hybrid data source connectivity.

Find a detailed comparison of the experiences [here](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/visualize-grafana-overview#solution-comparison)

**When to choose native dashboards:** Quick visibility into your Azure telemetry, minimal setup, with no additional costs.  
**When to choose Azure Managed Grafana:** Large teams with complex governance, open-source or Enterprise, or multi-cloud data sources.

### Customization and Advanced Features

The native Grafana experience in Azure Monitor includes many of the customization features you expect:

- **Variables & Templating:** Define dashboard variables for dynamic filtering across subscriptions, resource groups, or services.
- **Themes & Layouts:**  Automatically switches theme based on the Azure portal's theme, resize panels, and arrange layouts with drag-and-drop.
- **Cross-workspace & cross-source queries:** Query data from multiple Log Analytics workspaces, metrics namespaces.
- **Alerts & Annotations:**  View Azure alerts state and history in Grafana dashboards.

### Getting Started

1. In the Azure portal, go to **Azure Monitor** > **Dashboards with Grafana**.
2. Click **+ New** and select **New  Dashboard**.
3. Provide a title for the dashboard and the subscription, resource group for the dashboard. Click on Create.
Once the dashboard is created, select **+ Add** and chose ** Add Visualization **
4. Choose data sources (Log Analytics, Metrics, Prometheus, Azure Resource Graph) and start adding panels.

No separate Grafana deployment is required—this feature is enabled by default in supported regions. For region availability, quotas, and limitations, refer to the [Learn documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/visualize-use-grafana-dashboards).

### Real-world Use Cases

- **Kubernetes monitoring:** Combine Prometheus-style queries with AKS metrics and container logs to track pod health and resource utilization.  
- **Application performance dashboards:** Merge Application Insights traces with custom metrics to identify slow operations and error hotspots.  
- **Custom dashboards: ** Create individualized dashboards to track health of multiple Azure resources across resource typeswith custom health indicators

### Conclusion and Next Steps

Azure Monitor dashboards with Grafana in Azure Monitor simplify observability by bringing Grafana’s power into the Azure portal. Get started today to build rich, interactive dashboards without extra infrastructure. For deeper customization or hybrid scenarios, explore Azure Managed Grafana.

- Press release: https://grafana.com/about/press/2025/05/19/grafana-dashboards-coming-to-microsofts-azure-monitor/  
- Learn article: https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/visualize-use-grafana-dashboards