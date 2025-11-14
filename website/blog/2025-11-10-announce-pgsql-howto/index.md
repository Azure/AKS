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

[CloudNativePG](https://cloudnative-pg.io/) now anchors our recommended pattern for running production-ready PostgreSQL on AKS. With the latest feedback from EnterpriseDB (EDB), the documentation aligns to the refreshed container image catalogs, safer operator rollouts, and updates to the [Barman backup tool](https://pgbarman.org/) that help teams meet availability targets from day one.

The updated set of articles walks through the journey end-to-end: an overview of the architecture, infrastructure setup with workload identity and storage RBAC, deployment with the new PostgreSQL 18 image, and day-two validation. You'll see how we folded in the CNPG controller tuning, the move toward self-managed PodMonitors, and guidance on planning for the Barman Cloud plugin as upstream support evolves.

We also expanded the operational coverage: monitoring with Prometheus and Grafana, exercising failover across availability zones, and validating backup and restore flows that rely on AKS workload identity. The how-tos keep the commands concise so you can get into the CLI quickly without losing sight of the bigger architectural decisions.

## CloudNativePG on AKS, with EDB

For production support for CloudNativePG on AKS, visit [EDB's Azure Marketplace offering](https://marketplace.microsoft.com/en-us/product/saas/enterprisedb-corp.edb-cnpg?tab=Overview). As maintainers of the operator, they provide services to keep clusters compliant, optimized, and ready for future releases.

Thanks again to the CloudNativePG team at EDB for their collaboration, reviews, and continued support as we bring the latest PostgreSQL best practices to AKS users. Dive in and see how quickly you can stand up a resilient PostgreSQL footprint on AKS.
