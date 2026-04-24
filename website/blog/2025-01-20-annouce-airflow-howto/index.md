---
title: "Apache Airflow Guidance for AKS"
date: "2025-01-20"
description: "Learn how to set up an AKS cluster, deploy Airflow, and explore the Airflow UI running on AKS."
authors: ["kenneth-kilty"]
tags: ["general", "operations", "airflow"]
---

We're pleased to share [new guidance](https://learn.microsoft.com/azure/aks/airflow-overview) on deploying open-source Apache Airflow on Azure Kubernetes Service (AKS).

<!-- truncate -->

Apache Airflow is an open-source platform for orchestrating complex workflows and data pipelines. It allows users to define, schedule, and monitor workflows using Python. Airflow supports numerous integrations such as Azure Blob Storage or Azure Postgres SQL and can scale to handle large data volumes. The web-based Airflow UI provides a visual representation of your workflows, making it easier to track progress and troubleshoot issues. Airflow is widely used for ETL processes, data engineering, and managing machine learning pipelines.

This [new AKS how-to guide](https://learn.microsoft.com/azure/aks/airflow-overview) will walk you through the entire process, from setting up your AKS cluster with Airflow secretes in Azure Key Vault and DAG logs in Azure Blog Storage installing Apache Airflow using Helm. Considerations for Airflow distributed architecture for production are included within the guide.

You will also explore the Apache Airflow UI, where you can monitor and manage your workflows in Airflow running on AKS. Whether you're new to Airflow or looking to deploy your existing setup on AKS, this guide has something for everyone.

## Apache Airflow on Astro, Powered on Azure by AKS

For customers needing commercial support for Airflow on AKS, look to our partner [Astro](https://learn.microsoft.com/azure/partner-solutions/astronomer/overview) available today as an [Azure Native ISV Service](https://learn.microsoft.com/azure/partner-solutions/) powered on Azure by AKS!

Astro by [Astronomer.io](https://www.astronomer.io/) is an industry-leading DataOps platform. Powered by Apache Airflow, Astro dramatically reduces costs, increases productivity, and reliably powers customers most critical data pipelines. Astronomer also drives all Apache Airflow releases and has contributed over 55% of Apache Airflow open source code. Astronomer also maintains learning material for Airflow connectors to Azure from Astro such as [Azure Blob Storage](https://www.astronomer.io/docs/learn/connections/azure-blob-storage/).

You can find Apache Airflow on Astro – An Azure Native ISV Service in the [Azure portal](https://portal.azure.com/#view/Microsoft_Azure_Marketplace/GalleryItemDetailsBladeNopdl/id/astronomer1591719760654.astro) or get it on [Azure Marketplace](https://azuremarketplace.microsoft.com/marketplace/apps/astronomer1591719760654.astronomer?tab=Overview0)

Go ahead and dive in and unlock the full potential of Apache Airflow on AKS!
