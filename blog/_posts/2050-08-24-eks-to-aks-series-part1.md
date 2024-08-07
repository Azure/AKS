---
title: "New Documentation Series for Moving Workloads from EKS to AKS"
description: "This article guides you through replicating an Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) event-driven workflow (EDW) workload using KEDA and Karpenter in Azure Kubernetes Service (AKS)."
date: 2050-08-24
author: Kenneth Kilty
categories: general # general, operations, networking, security, developer topics, add-ons
---

## Introduction

Our Azure customers often operate their workloads simultaneously across multiple cloud providers. We often observe this with Software-as-a-Service (SaaS) workloads, where SaaS providers need to accommodate the cloud preferences of their customers. These kinds of workloads are often vendor-neutral meaning they minimize dependencies on their initial cloud provider to enhance portability and reduce engineering and support costs as they expand across multiple cloud providers. Kubernetes is typically at the heart of such workloads.

We’re excited to announce the first in a new documentation series to help new AKS customers replicate their workloads from Amazon EKS to AKS: [Replicate an AWS event-driven workflow (EDW) workload with KEDA and Karpenter in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/eks-edw-overview)

Transitioning from another managed Kubernetes offering to AKS can be challenging, and the goal of this series focuses on providing a holistic, end-to-end experience to help ease that process through learning by example. We acknowledge that the replication experience is not always a simple lift and shift but rather requires elements of re-architecture and translation, especially with identity and access management from an external managed Kubernetes offering to AKS and Azure at large.

## An EKS to AKS Replication Scenario

This new article guides you through replicating an Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) event-driven workflow (EDW) workload using [KEDA](https://keda.sh/) and [Karpenter](https://karpenter.sh/) in Azure Kubernetes Service (AKS). In the spirit of multi-cloud, this guide works to make the absolute minimum number of changes to the workload in order for it to run on AKS.

In this first article, the workload implements the competing consumers pattern with a producer/consumer app, facilitating efficient data processing by separating data production from data consumption. KEDA is used to scale pods running consumer processing, while AKS managed Karpenter autoscale Kubernetes nodes through the new AKS [Node Autoprovisioning (NAP)](https://learn.microsoft.com/en-gb/azure/aks/node-autoprovision) feature currently available in preview.

You can either clone the AWS EKS sample and follow along with the guide, or read the guide to understand the necessary changes and the reasons behind them as outlined below.

1. Understand Platform Differences: Review the differences between EKS and AKS in terms of services, architecture, and deployment for this workload.
2. Re-architect the Workload: Analyze the existing EKS workload architecture and identify components that need changes to fit AKS.
3. Update Application Code: Refactor elements of the code to make the app compatible with Azure APIs, services, and authentication models.
4. Prepare for Deployment: Modify the EKS deployment process to use the Azure CLI.
5. Deploy the Workload: Deploy the replicated EKS workload in AKS and test to ensure it functions as expected.

## Summary

We hope this new series is helpful for customers coming to AKS from EKS, and we'd love your feedback and ideas for additional guides and scenarios that you encounter. Stay tuned for future posts where we will dive into additional scenarios for other common cloud native workloads.
