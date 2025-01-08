---
title: "Mastering the Move: EKS to AKS by Example - Part 2"
description: "Learn how to replicate an Amazon Elastic Kubernetes Service (EKS) web application with AWS Web Application Firewall (WAF) using Azure Web Application Firewall (WAF) and Azure Application Gateway in Azure Kubernetes Service (AKS)"
date: 2025-01-06
author: Kenneth Kilty
categories: general
---

## Introduction

Welcome back to our series on migrating Amazon EKS workloads to Azure Kubernetes Service (AKS). In [Part 1](https://azure.github.io/AKS/2024/08/01/eks-to-aks-series-part1) we explored migrating and Event Driven Workload using Karpenter and KEDA from EKS to AKS. Next, we look into a more complex migration scenario with a common Kubernetes workload the [n-tier web application](https://learn.microsoft.com/azure/architecture/guide/architecture-styles/n-tier).

## EKS to AKS - Web Application Scenario

This new [article](https://learn.microsoft.com/azure/aks/eks-web-overview) guides you through replicating an Amazon Elastic Kubernetes Service (EKS) web application with AWS Web Application Firewall (WAF) using Azure Web Application Firewall (WAF) and Azure Application Gateway in Azure Kubernetes Service (AKS). This sample uses a WAF to protect a [Yelb](https://github.com/mreferre/yelb/) web-based application running in a Kubernetes cluster.

In this guide, we explore the deployment process, starting with understanding the conceptual differences between EKS and AKS for the web application workload infrastructure. We then move on to architecting the workload for Azure, updating the app code for compatibility with Azure APIs, and preparing for deployment using the Azure CLI. Finally, we deploy the replicated workload in AKS and test it to ensure it functions as expected.

The guide also include detailed AWS service by Azure service discussion and details alternative solutions for managing ingress including [Application Gateway Ingress Controller (AGIC)](https://learn.microsoft.com/azure/application-gateway/ingress-controller-overview), [Azure Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers/overview), [Azure Front Door (AFD)](https://learn.microsoft.com/azure/frontdoor/front-door-overview), and a [NGINX ingress controller](https://github.com/kubernetes/ingress-nginx) with end-to-end TLS configured using [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/basic-concepts).

## Looking Forward

Our next article will explore migrating an EKS AI/ML workload to AKS. We'll look at migration challenges common with AI/ML workloads like cost optimization, efficient scaling, and GPU usage.

As always, we are interested to hear about the migration challenges and scenarios you encounter, so we can continue to enhance the features and documentation for AKS to ease the transition from on-premises or other clouds to Azure. Please share your ideas using one of the contact methods below.
