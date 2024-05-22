---
title: "AKS Automatic"
description: "Hello AKS Automatic, a new experience for AKS!"
date: 2024-05-22
author: Jorge Palma
categories: general
classes: wide
---

## AKS Automatic

You may have heard about AKS Automatic in the Build keynote today. We thought we'd share a bit of the thinking that went into it and why we think it can be a game changer for you.

Automatic is a new experience for Azure Kubernetes Service (AKS) that lets you create and manage production-ready clusters with minimal effort and added confidence. This means you can focus on developing and running your applications, while AKS handles the rest for you.

AKS Automatic is based on three key pillars:

- **Production-Ready by Default:** AKS Automatic mode provides a turnkey solution that is production-ready right out of the box. You don't need to spend hours or days configuring your cluster, scaling your resources, or securing your environment. AKS does it all for you, using best practices and proven templates. Cluster day-2 operations like upgrades are configured and handled automatically and reliably. Developers only need to use the deployment mechanisms from Automatic to ensure availability. With AKS Automatic mode, your environment benefits, out of the box, from features such as automatic separation, Availability Zone spread and node auto-provisioning, which enhance the performance, reliability, and scalability of your cluster.
- **Integrated Best Practices and Safeguards:** AKS Automatic ensures that your cluster and applications adhere to the highest standards of security and reliability and builds on the many best practices that we've already been encouraging people to do with Kubernetes. It comes with robust default settings, such as deployment safeguards, network policies, and access to Microsoft Entra protected resources. It also integrates with Azure Policy, Azure Monitor, and Azure Key Vault to provide you with comprehensive governance and visibility.
- **Code to Kubernetes in Minutes:** AKS Automatic integrates with Automated Deployments that dramatically simplify the process of going from code to Kubernetes and we’re further adding new production defaults like Pod Disruptions Budgets and Probes into the automatic manifest generation, all controlled via CI/CD pipelines that are generated for you. In just minutes, you can take your projects from the ideation stage to a fully-fledged Kubernetes deployment, using the Azure portal, Azure CLI, or GitHub Actions. You can also expose your applications to the internet or to other applications within the cluster using routes and ingresses, with AKS managing the DNS records and SSL certificates for you.

A key thing to understand is that while AKS Automatic is a more opinionated and automated mode of operation, it is still AKS, with the full power and flexibility of the Kubernetes API and ecosystem available when you need it. And if you ever find that its approach doesn't work for you, you can easily switch your cluster to AKS Standard without touching your applications or otherwise impacting your environment.

AKS Automatic mode is currently in preview and available across all Azure public commercial regions that support availability zones. You can get started today by following the [quickstart guide on Microsoft Learn](https://aka.ms/aks/automatic-quickstart) to create an AKS Automatic cluster and deploy an application.

We are just getting started, we have a ton of planned experiences that we will be shipping over the following months and we‘d love to hear your [feedback and suggestions](https://github.com/Azure/AKS/issues/4301) on how to make AKS Automatic mode even better and allow you to stay focused on your workloads.

AKS Automatic mode is the easiest way to get the most out of Kubernetes on Azure. Try it today and see for yourself how it can accelerate your Kubernetes journey.
