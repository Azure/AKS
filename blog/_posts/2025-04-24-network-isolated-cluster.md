---
title: "Network Isolated Cluster"
description: "Use network isolated AKS clusters to restrict outbound traffic at a glance"
date: 2025-04-24
author: Charles Wu
categories: 
- security
---

## Network isolated Azure Kubernetes Service (AKS) cluster

You may have heard about [AKS network isolated cluster](https://learn.microsoft.com/azure/aks/concepts-network-isolated) during Microsoft last year. This feature allows you to bootstrap an AKS cluster without any outbound egress traffic at a glance. This feature is now Generally available. With this announcement, we want to share with you more details of this exciting offering. 

Previously, if a user wants to restrict outbound traffic for an AKS cluster, firewall is the common option to go with. However, this solution has some shortcomings: 
1. It could be cumbersome and complicated since you have to figure out the endpoints of the AKS cluster and your own application, which are required for outbound traffic and to create corresponding egress firewall rules. 
2. A cluster is not truly without outbound traffic due to the need for these endpoints. Said outbound traffic could still cause data exfiltration and leakage. 

Network isolated cluster now offers an easier and safer solution.

A ntework isolated cluster has these benefits:

- **Zero outbound egress:** A network isolated cluster doesn't require any egress traffic beyond the VNet throughout the cluster bootstrapping process. This is achieved through private endpoint connection to the associated private Azure Container Registry (ACR) instance; images and binaries required for AKS cluster creation and operation are pulled from Microsoft Artifact Registry (MAR). This proxy architecture helps eliminate all outbound requests during AKS cluster bootstrapping and maintenance.
- **Simplicity:** Instead of creating a tedious list of firewall rules, you can just create a network isolated cluster with AKS managed Azure Container Registry (ACR). That's all. With network isolated clusters, you no longer need to worry about the outbound traffic during cluster creation, operation, and upgrading.
- **Secure by default:**  A network isolated cluster reduces the risk of data exfiltration or unintentional exposure of the cluster's public endpoints. This is critical if you have strict security and compliance requirements to regulate egress (outbound) network traffic.

[Firewalls](https://learn.microsoft.com/azure/aks/limit-egress-traffic?tabs=aks-with-system-assigned-identities) still have their own unique value proposition. This is especially evident when you need outbound traffic from your applications or cluster elsewhere, or when you want to control, inspect, and secure cluster traffic, both egress and ingress, in a finer manner.

Network isolated cluster is now general available across all Azure public cloud. You can get started today by following the [how-to guide](https://learn.microsoft.com/en-us/azure/aks/network-isolated?pivots=aks-managed-acr) to create a network isolated cluster and secure your cluster environment.

We are far from finished. We have tons of planned experiences that will be shipping over the following months and would love to hear your [feedback and suggestions](https://github.com/Azure/AKS/issues/3319) on how to make network isolated clusters even better.


