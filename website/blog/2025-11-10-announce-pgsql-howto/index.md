---
title: "PostgreSQL + CloudNativePG guidance for AKS"
date: "2025-11-10"
description: "Learn how to set up an AKS cluster, deploy PostgreSQL, and explore CloudNativePG running on AKS."
authors: ["eric-cheng"]
tags:
  - general
  - developer
  - storage
  - databases
---

We're pleased to share the [newly updated guidance](https://learn.microsoft.com/azure/aks/postgresql-ha-overview) on deploying PostgreSQL with CloudNativePG on Azure Kubernetes Service (AKS).

<!-- truncate -->

[CloudNativePG](https://cloudnative-pg.io/) now anchors our recommended pattern for running production-ready PostgreSQL on AKS. With EnterpriseDB's latest feedback, the documentation aligns to the refreshed container image catalogs, safer operator rollouts, and updates to the [Barman backup tool](https://pgbarman.org/) that help teams meet availability targets from day one.

The updated series walks through the journey end-to-end: an overview of the architecture, infrastructure setup with workload identity and storage RBAC, deployment with the new PostgreSQL 18 image, and day-two validation. You'll see how we folded in the CNPG controller tuning, the move toward self-managed PodMonitors, and guidance on planning for the Barman Cloud plugin as upstream support evolves.

We also expanded the operational coverage: monitoring with Prometheus and Grafana, exercising failover across availability zones, and validating backup and restore flows that rely on AKS workload identity. The how-tos keep the commands concise so you can get into the CLI quickly without losing sight of the bigger architectural decisions.

## CloudNativePG on AKS, with EDB

If you need production support for CloudNativePG on AKS, reach out to [EnterpriseDB](https://www.enterprisedb.com/) or their offering on [Azure Marketplace](https://marketplace.microsoft.com/en-us/product/saas/enterprisedb-corp.biganimal-prod-v1?tab=Overview). As the stewards of the operator, they offer services and subscriptions that pair well with the deployment guidance so you can keep your clusters compliant, tuned, and ready for future CNPG releases.

Thanks again to the CloudNativePG team at EnterpriseDB for their collaboration, reviews, and continued support as we bring the latest PostgreSQL best practices to AKS users. Dive in and see how quickly you can stand up a resilient PostgreSQL footprint on AKS.
