---
title: "Postgres on AKS: The Cloud Native Way"
description: "Sample - Add your description"
date: 2024-08-23
author: Kenneth Kilty
categories: general
---

## Introduction

[PostgreSQL](https://www.postgresql.org/) is the most popular relational database management system (RDBMS) as [reported](https://survey.stackoverflow.co/2024/technology/#1-databases) by developers. In this first blog post of our new series on stateful open source workloads on Azure Kubernetes Services (AKS), we'll guide you through deploying a highly available PostgreSQL database on (AKS) using the [CloudNativePG](https://cloudnative-pg.io/) operator.

Be sure to check this blog regularly for the latest updates and new guides on running stateful workloads on AKS.

## What’s in the guide?

Based on best practices from the CloudNativePG team, this guide shows you how to set up a multi-zone Postgres cluster with multiple replicas on AKS using zone redundant storage (ZRS). 'Day 2' operation guidance is also included along with simulations of planned and unplanned Postgres cluster failovers.

Highlights from the guide:

1. Infrastructure Setup: Learn how to configure AKS and deploy PostgreSQL using the CNPG Operator and expose read-write and read-only endpoints using an Azure Load Balancer.

2. Monitoring and Metrics: Discover how to use [Azure Monitor managed service for Prometheus](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/prometheus-metrics-overview) and [Azure Managed Grafana](https://learn.microsoft.com/en-us/azure/managed-grafana/overview) to monitor your PostgreSQL cluster and visualize metrics.

3. Backup and Restore: Understand the steps to back up your PostgreSQL data to [Azure Blob Storage](https://azure.microsoft.com/en-us/products/storage/blobs/) and restore it in the event of a failure or service interruption. Backup is configured to not require storage of secrets leveraging [Entra Workload ID for AKS](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet).

4. High Availability: PostgreSQL instances are spread across multiple availability zones for higher availability backed by zone redundant storage.

We hope you give this guide a try and explore running your multi-cloud RDBMS workloads on AKS.

Don’t forget to subscribe to our [Really Simple Syndication (RSS) feed](https://azure.github.io/AKS/feed.xml) to stay tuned for upcoming posts in the series!

Until next time ✌️
