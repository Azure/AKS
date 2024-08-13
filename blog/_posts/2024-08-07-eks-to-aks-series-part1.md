---
title: "Mastering the Move: EKS to AKS by Example"
description: "Learn how to migrate Amazon EKS workloads to Azure AKS using KEDA and Karpenter in this comprehensive guide."
date: 2050-08-24
author: Kenneth Kilty
categories: general
---

## Introduction

Many companies use multiple clouds for their workloads. These companies need to accommodate the cloud preferences of their customers. Kubernetes plays a central role in multi-cloud workloads due to its ability to provide a consistent and portable environment across different cloud providers.

We would like to share the first in a new documentation series designed specifically for customers already using Amazon EKS, to help them replicate or migrate their workloads to AKS: [Replicate an AWS event-driven workflow (EDW) workload with KEDA and Karpenter in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/eks-edw-overview)

Even with Kubernetes’ portable API, moving between clouds can be challenging. Each cloud has its own unique concepts, behaviors, and quirks that will seem unfamiliar when you’re accustomed to another cloud’s approach. This is not unlike the experience of learning a new language or visiting a new country for the first time. This series will be local guide to the world of Azure. The samples in this series begin with infrastructure and code on EKS and end with equivalently functional infrastructure and code on AKS, while explaining the conceptual differences between AWS and Azure throughout.

## EKS to AKS - Event Driven Workflow Scenario

This new [article](https://learn.microsoft.com/en-us/azure/aks/eks-edw-overview) guides you through replicating an Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) event-driven workflow (EDW) workload using [KEDA](https://keda.sh/) and [Karpenter](https://karpenter.sh/) in Azure Kubernetes Service (AKS). In the spirit keeping the workload as portable as possible, this guide prioritizes minimizing the changes needed to get the workload running on Azure.

In this first article, the workload implements the competing consumers pattern with a producer/consumer app, facilitating efficient data processing by separating data production from data consumption. KEDA is used to scale pods running consumer processing, while AKS managed Karpenter autoscale Kubernetes nodes through the new AKS [Node Autoprovisioning (NAP)](https://learn.microsoft.com/en-gb/azure/aks/node-autoprovision) feature currently available in preview.

You can either clone the AWS EKS sample and follow along with the guide, or read the guide to understand the necessary changes and the reasons behind them as outlined below.

1. Understand Platform Differences: Review the differences between EKS and AKS in terms of services, architecture, and deployment for this workload.
2. Re-architect the Workload: Analyze the existing EKS workload architecture and identify components that need changes to fit AKS.
3. Update Application Code: Refactor elements of the code to make the app compatible with Azure APIs, services, and authentication models.
4. Prepare for Deployment: Modify the EKS deployment process to use the Azure CLI.
5. Deploy the Workload: Deploy the replicated EKS workload in AKS and test to ensure it functions as expected.

## Summary

Learn how to migrate Amazon EKS workloads to Azure AKS using KEDA and Karpenter in this comprehensive guide. Gain insights into the platform differences, re-architect the workload, update application code, prepare for deployment, and deploy the workload in AKS.
