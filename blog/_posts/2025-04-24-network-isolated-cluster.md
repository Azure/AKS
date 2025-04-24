---
title: "Network Isolated Cluster"
description: "Use network isolated AKS cluster to restrict outbound traffic at glance"
date: 2025-04-24
author: Charles Wu
categories: security
---

## Network isolated Azure Kubernetes Service (AKS) cluster

You may have heard about [AKS network isolated cluster](https://learn.microsoft.com/azure/aks/concepts-network-isolated) in the Build last year. This feature allows you to boostrap an AKS cluster without any outbound egress traffic at glance. This feature is now general available. With this announcement, we want to share with you more details of this exciting offering. 

Previously, if you want to restrict outbound traffic for an AKS cluster, firewall is the common option to go with. However, this solution are not perfect for 1. It could be cumbersome and complicated since you have to figure out the endpoints the AKS cluster and your own application require for outbound traffic and to create corresponding egress firewall rules. 2. It is not truly build a cluster without any outbound traffic due to those endpoints a normal AKS cluster requires, these outbound traffic could still cause data exfiltration and leakage. Is there an easier and even safer solution? Gladly, you have network isolated cluster now.

Network isolated clusters have these benefits:

- **Zero outbound egress:** A network isolated cluster doesn't require any egress traffic beyond the VNet throughout the cluster bootstrapping process. This is achieved through private endpoint connection to the associated private Azure Container Registry (ACR) instance. Where the later one pulls images and binaries required for AKS cluster creation and operation from the the Microsoft Artifact Registry (MAR). This proxy architecture helps eliminate all outbound requests for AKS cluster bootstrapping and maintenance.
- **Simplicity:** Insteading creating a tedious list of firewall rules. You just need to create a network isolated cluster. That's all. Then, you no longer need to worry about the outbound traffic for the cluster creation, operation and upgrading.
- **Secure by default:**  A network isolated cluster reduces the risk of data exfiltration or unintentional exposure of cluster's public endpoints, this is critical if you have strict security and compliance requirements to regulate egress (outbound) network traffic.

With above being said, firewall still has its own unique value. Especially when you need outbound traffic anyway from your applications or cluster elsewhere and when you want to control, inspect and secure cluster traffic, not only egress but aslo ingress, at fine grid.

Network isolated cluster is now general available across all Azure public cloud. You can get started today by following the [how-to guide](https://learn.microsoft.com/en-us/azure/aks/network-isolated?pivots=aks-managed-acr) to create a network isolated cluster and secure your cluster evironment by default.

We are far from the ending, we have a ton of planned experiences that will be shipping over the following months and we'd love to hear your [feedback and suggestions](https://github.com/Azure/AKS/issues/3319) on how to make the network isolated clusters even better.

