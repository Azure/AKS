---
title: "Update on the Azure Kubernetes Service (AKS) Application Routing add-on, the Ingress API, and Ingress-NGINX"
date: "2025-11-13"
description: "Microsoft's commitment to Azure Kubernetes Service (AKS) customers using the Application Routing add-on with Ingress-NGINX and guidance on migrating to modern Gateway API solutions." 
authors: ["ahmed-sabbour"]
tags:
  - app-routing
  - istio
  - traffic-management
---

The [Kubernetes SIG Network](https://github.com/kubernetes/community/blob/master/sig-network/README.md) and the Security Response Committee have [announced](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/) the upcoming retirement of the [Ingress NGINX project](https://github.com/kubernetes/ingress-nginx/), with maintenance ending in **March 2026**.

<!--truncate-->

## No immediate action required

Microsoft understands that customers value continuity and clarity around the maintenance and evolution of the components that power their workloads. There is no change or immediate action required today for AKS clusters using the [Application Routing add-on with NGINX](https://learn.microsoft.com/azure/aks/app-routing) to manage Ingress NGINX resources. Microsoft will provide official support for Application Routing add-on Ingress NGINX resources through **November 2026** and only for critical security patches during this period.

We are actively investing in the future of application connectivity in Azure Kubernetes Service (AKS), centered on the Gateway API. This includes support for the Gateway API in the Istio-based service mesh add-on, expanding the Application Routing add-on to support the Gateway API, and continuing investment in Application Gateway for Containers.

### The future of the Application Routing add-on

**Application Routing with Gateway API**, which will be powered by the Istio control plane, is **planned for the first half of 2026**, along with migration guidance documentation. The Kubernetes Gateway API represents the next generation of Kubernetes traffic management, evolving from the Ingress API by offering richer routing capabilities, standardized extensibility, and a more secure, role-oriented design.

### Alternative migration paths

Alternatively, existing users of Ingress NGINX, including users who provisioned it through Application Routing add-on, can also migrate to one of the following options:

- The [Istio-based service mesh add-on](https://learn.microsoft.com/azure/aks/istio-gateway-api) using the Gateway API
- [Application Gateway for Containers](https://aka.ms/agc/addon) using either the Ingress API or the Gateway API

For further questions, you can reach us on [GitHub](https://github.com/Azure/AKS/issues) or create a [support case](https://learn.microsoft.com/azure/azure-portal/supportability/how-to-create-azure-support-request).
