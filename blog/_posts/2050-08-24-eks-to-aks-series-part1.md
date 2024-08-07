---
title: "New Documentation Series for Moving Workloads from EKS to AKS"
description: "This article guides you through replicating an Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) event-driven workflow (EDW) workload using KEDA and Karpenter in Azure Kubernetes Service (AKS)."
date: 2050-08-24
author: Kenneth Kilty
categories: general # general, operations, networking, security, developer topics, add-ons
---

## Introduction

Many Azure customers often operate their workloads across multiple cloud providers, especially with SaaS workloads. SaaS providers need to be able to accommodate the cloud preferences of their customers. Kubernetes plays a central role in multi-cloud workloads due to its ability to provide a consistent and portable environment across different cloud providers.

We’re excited to announce the first in a new documentation series designed specifically for customers already using Amazon EKS, to help them replicate their workloads to AKS: [Replicate an AWS event-driven workflow (EDW) workload with KEDA and Karpenter in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/eks-edw-overview)

Moving a workload from another managed Kubernetes offering to AKS can be challenging. This series aims to provide a holistic, end-to-end experience by example to help ease that process. The samples in this series begin with infrastructure and code on EKS and end with equivalently functional code on AKS, with an emphasis on explaining the conceptual differences between AWS and Azure throughout.

## An EKS to AKS Replication Scenario

This new article guides you through replicating an Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) event-driven workflow (EDW) workload using [KEDA](https://keda.sh/) and [Karpenter](https://karpenter.sh/) in Azure Kubernetes Service (AKS). In the spirit keeping the workload as multi-cloud as possible, this guide prioritizes minimizing the changes needed to get the workload running on Azure.

In this first article, the workload implements the competing consumers pattern with a producer/consumer app, facilitating efficient data processing by separating data production from data consumption. KEDA is used to scale pods running consumer processing, while AKS managed Karpenter autoscale Kubernetes nodes through the new AKS [Node Autoprovisioning (NAP)](https://learn.microsoft.com/en-gb/azure/aks/node-autoprovision) feature currently available in preview.

You can either clone the AWS EKS sample and follow along with the guide, or read the guide to understand the necessary changes and the reasons behind them as outlined below.

1. Understand Platform Differences: Review the differences between EKS and AKS in terms of services, architecture, and deployment for this workload.
2. Re-architect the Workload: Analyze the existing EKS workload architecture and identify components that need changes to fit AKS.
3. Update Application Code: Refactor elements of the code to make the app compatible with Azure APIs, services, and authentication models.
4. Prepare for Deployment: Modify the EKS deployment process to use the Azure CLI.
5. Deploy the Workload: Deploy the replicated EKS workload in AKS and test to ensure it functions as expected.

## Summary

We hope this new series is helpful for customers coming to AKS from EKS, and we'd love your feedback and ideas for additional guides and scenarios that you encounter. Stay tuned for future posts where we will dive into additional scenarios for other common cloud native workloads.
