---
title: "What's New?! Guidance Updates for Stateful Workloads on AKS"
description: "Learn how to set up an AKS cluster, deploy Kafka, integrate Azure Container Storage and explore the other stateful workloads running on AKS with Terraform or AzCLI."
date: 2025-06-05
author: Colin Mixon
categories: general
---
## Helping you deploy on AKS
Building on our initial announcement for [Deploying Open Source Software on Azure](https://techcommunity.microsoft.com/blog/linuxandopensourceblog/deploying-open-source-software-on-azure-new-guides-for-aks-and-vms/4264602) Azure is excited to announce we have expanded our library of technical best practice deployment guides for stateful workloads on AKS. We have developed a comprehensive guide for deploying Kafka on AKS, and updated our Postgres guidance with additional storage considerations for data resiliency, performance and cost. We have also added Terraform templates to our Mongo DB and Valkey guides for automated deployments. 

These guides are designed to help you accelerate the integration of some of the most critical and heavily adopted open source projects onto Azure, utilizing best practices and optimizations for AKS. Jump to our [collection of Stateful and AI guides below](#deploy-stateful-and-ai-workloads-on-azure-kubernetes-service). 

## Introducing Guidance for Deploying Apache Kafka on AKS with the Strimzi Operator

Apache Kafka is an open source distributed event streaming platform designed to handle high-volume, high-throughput, and real-time streaming data. It is widely used by thousands of companies for mission-critical applications but managing and scaling Kafka clusters on Kubernetes can be challenging. [Strimzi](https://github.com/strimzi/strimzi-kafka-operator) simplifies the deployment and management of Kafka on Kubernetes by providing a set of Kubernetes Operators and container images that automate complex Kafka operational tasks. 

The [Kafka on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/kafka-infrastructure?pivots=azure-cli) guide covers essential storage and compute considerations, ensuring you Kafka deployment meets your needs. Additionally, we provide guidance for tuning the Java Virtual Machine (JVM), which is critical for optimal Kafka broker and controller performance.

On top of basic installation steps, the Kafka guide provides best practice recommendations for configuring networking, monitoring, and  managed identity.

## Updates to our current Guidance 

Aside from writing new guidance, we have also reviewed our existing portfolio of guides to ensure they are accurate and up to date. As new services and features have been developed, we have provided guidance to help you seamlessly integrate them with your stateful applications. 

## Azure Container Storage integration 

[Azure Container Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction) is a volume management, deployment, and orchestration service built for Kubernetes and based on [OpenEBS](https://openebs.io/). Azure Container Storage offers your clusters a significant advantage by effortlessly provisioning high-performance persistent volumes on ephemeral local NVMe drives, surpassing typical CSI drivers. 

We have revised our [PostgreSQL guidance](https://learn.microsoft.com/en-us/azure/aks/create-postgresql-ha?tabs=acstor%2Chelm) and [Kafka guidance](https://learn.microsoft.com/en-us/azure/aks/kafka-overview) to include Azure Container Storage alongside other storage configuration options, so you can make an informed choice on what best suits your objectives. 
- For the most durable data resiliency, you can use the Azure Disks CSI driver with Premium SSD disks which provide [zone-redundant storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy#redundancy-in-the-primary-region) resiliency to your PostgreSQL deployment. 
- For the best cost savings at scale, you can use [Premium SSD v2 disks](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-deploy-premium-v2?tabs=azure-cli) which can let you set disk capacity independently from performance settings. 
- For maximum performance, Azure Container Storage and ephemeral disks can provide the extremely low sub-millisecond latency and high input/output operations per second (IOPS) that transactional database workloads benefit from.  

## Automate Deployment Guides with Terraform templates 
We also listened to your requests for adding Terraform templates alongside the AzCli guidance so that you can use Infrastructure as Code for your deployments. 

We have updated both MongoDB and Valkey guides with Terraform. Additionally, we have developed an Azure Verified Module for deploying a production-grade AKS Cluster. 

- [Terraform Module for Production Standard AKS Cluster](https://github.com/Azure/terraform-azurerm-avm-ptn-aks-production)
- [Create the infrastructure for running a MongoDB cluster on Aks using Terraform](https://learn.microsoft.com/en-us/azure/aks/create-mongodb-infrastructure?pivots=terraform)
- [Create the infrastructure for running a Valkey cluster on AKS using Terraform](https://learn.microsoft.com/en-us/azure/aks/create-valkey-infrastructure?pivots=terraform)

## Deploy Stateful and AI workloads on Azure Kubernetes Service 
* Postgres - [Create infrastructure for deploying a highly available PostgreSQL database on AKS](https://learn.microsoft.com/en-us/azure/aks/create-postgresql-ha?tabs=pv1%2Chelm)
* Apache Airflow - [Create the infrastructure for deploying Apache Airflow on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/airflow-create-infrastructure)
* Apache Kafka - [Prepare the infrastructure for deploying Kafka on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/kafka-infrastructure?pivots=terraform)
* Ray - [Deploy a Ray cluster on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/deploy-ray)
* Valkey - [Create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/create-valkey-infrastructure?pivots=terraform)
* Mongo DB - [Create the infrastructure for running a MongoDB cluster on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/create-mongodb-infrastructure?pivots=terraform)
* Kubernetes AI Toolchain Operator (KAITO) - [Deploy KAITO on AKS using Terraform](https://github.com/kaito-project/kaito/blob/main/terraform/README.md#deploy-kaito-on-aks-using-terraform)

## What's next?
We will continue expanding our library of technical best practice guidance and update the remaining guides to also include Terraform templates. Soon, we will develop more guides for databases like Cassandra DB, which will also include AcStor integration guidance, helping you choose the best storage option for your needs.
