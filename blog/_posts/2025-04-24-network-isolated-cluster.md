---
title: "Network Isolated Cluster"
description: "Use network isolated AKS clusters to restrict outbound traffic at a glance"
date: 2025-04-24
author: Charles Wu
categories: 
- security
---

# Network isolated Azure Kubernetes Service (AKS) cluster

By default, standard SKU Azure Kubernetes Service (AKS) clusters have unrestricted outbound internet access. This level of network access allows nodes and services you run to access external resources as needed. For those organizations who have strict security and compliance requirements, to regulate and control egress (outbound) network traffic from a cluster is a must have for the purpose of eliminating data exfiltration.

Previously, if a user wants to restrict outbound traffic for an AKS cluster, firewall is the common option to go with. However, this solution has some shortcomings: 
1. It could be cumbersome and complicated since you have to figure out the endpoints of the AKS cluster and your own application, which are required for outbound traffic and to create corresponding egress firewall rules. 
2. A cluster is not truly without outbound traffic due to the need for these endpoints. Said outbound traffic could still cause data exfiltration and leakage. 

Is there an easier way? You may have heard about [AKS network isolated cluster](https://learn.microsoft.com/azure/aks/concepts-network-isolated) during the Microsoft Build last year. This feature allows you to bootstrap an AKS cluster without any outbound egress traffic at a glance. This feature is now generally available (GA). With this announcement, we want to share with you more details of this exciting offering. 

## How a network isolated cluster works

The following diagram shows the network communication between dependencies for a network isolated cluster.

![Traffic diagram of network isolated AKS cluster](blog/assets/images/network-isolated-cluster-diagram.png)

AKS clusters fetch artifacts required for the cluster and its features or add-ons from the Microsoft Artifact Registry (MAR). This image pull allows AKS to provide newer versions of the cluster components and to also address critical security vulnerabilities. A network isolated cluster attempts to pull those images and binaries from a private Azure Container Registry (ACR) instance connected to the cluster instead of pulling from MAR. If the images aren't present, the private ACR pulls them from MAR and serves them via its private endpoint, eliminating the need to enable egress from the cluster to the public MAR endpoint.

## Benefits of using network isolated clusters

- **Zero outbound egress:** A network isolated cluster doesn't require any egress traffic beyond the VNet throughout the cluster bootstrapping process and throughout the lifecycle of cluster upgrade and operation. This is achieved through private endpoint connection to the associated private Azure Container Registry (ACR) instance; images and binaries required for AKS cluster creation and operation are first pulled from Microsoft Artifact Registry (MAR) to this attached ACR. This proxy architecture helps eliminate all outbound requests during AKS cluster bootstrapping and maintenance.
- **Simplicity:** Instead of creating a tedious list of firewall rules, you can just create a network isolated cluster with AKS managed Azure Container Registry (ACR). That's all. With network isolated clusters, you no longer need to worry about the outbound traffic during cluster creation, operation, and upgrading.
- **Secure by default:**  A network isolated cluster reduces the risk of data exfiltration or unintentional exposure of the cluster's public endpoints. This is critical if you have strict security and compliance requirements to regulate egress (outbound) network traffic.

[Firewalls](https://learn.microsoft.com/azure/aks/limit-egress-traffic?tabs=aks-with-system-assigned-identities) still have their own unique value proposition. This is especially evident when you need outbound traffic from your applications or cluster elsewhere, or when you want to control, inspect, and secure cluster traffic, both egress and ingress, in a finer manner.

## Get Started 

Network isolated cluster is now general available across all Azure public cloud. You can get started today by following the [how-to guide](https://learn.microsoft.com/en-us/azure/aks/network-isolated?pivots=aks-managed-acr) to create a network isolated cluster and secure your cluster environment.

## Looking forward

Now that the fundational building block of network isolated cluster is ready in place, we have a rich roadmap that we will be working on in the coming months:

**Outbound type of `block`**: this outbound type is still in preview considering when using this outbound type, AKS configures network rules to actively block all egress traffic from the cluster, this is only intended for highly secure environments where outbound connectivity must be stirctly restricted. We plan to bring this outbound type to a more matured state.

**Add-on enable experience**: right now if you want to use any AKS feature or add-on that requires outbound network access in network isolated clusters, you will need to either set up private endpoints to access these features or set up the cluster with a user-defined routing table and an Azure Firewall based on the network rules and application rules that required for that feature. We plan to automate the process above so you can easily use these add-ons or features in network isolated cluster as you do in a normal cluster.

We are far from finished. We have tons of planned experiences that will be shipping over the following months and would love to hear your [feedback and suggestions](https://github.com/Azure/AKS/issues/3319) on how to make network isolated clusters even better.


