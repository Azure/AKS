---
title: "Multi-Cluster Management with KubeFleet"
description: "KubeFleet helps easily manage multiple Kubernetes clusters. This Microsoft-led, open source project was recently accepted as a CNCF sandbox project."
date: 2025-01-17
author: Sanket Bakshi
categories: general
---


In the ever-evolving world of cloud native technologies, managing multiple Kubernetes clusters efficiently is a challenge. KubeFleet makes it easier and more efficient to manage applications running across multiple Kubernetes clusters.. This open-source project was recently accepted as a [CNCF sandbox project](https://github.com/cncf/sandbox/issues/307). This was a journey 3 years in making! 

Managing multiple Kubernetes clusters can be challenging, with issues like -  

* How to manage cloud native configs and applications across these clusters? 

* How to perform changes to those resources safely without triggering global failures? 

* How to pick the right clusters to meet special needs of the applications (e.g. specific region footprint, highly specific CPU or memory needs, lowering cost per GB etc.)? 

* How to seamlessly move applications between clusters so that one can treat clusters as “cattle” instead of “pets”? 

In this blog post, we'll delve into what KubeFleet is, its key features, and how it can benefit your organization. 

## What is KubeFleet? 

KubeFleet is an open-source, multi-cluster Kubernetes resource management solution developed by Microsoft Azure. It provides a robust framework for orchestrating and distributing Kubernetes resources representing configs (e.g., roles, bindings, quotas, policies) and applications (e.g., deployments, services) across a fleet of Kubernetes clusters. Whether you're managing clusters on-premises, in the cloud, or in a hybrid environment, KubeFleet offers the tools you need to ensure seamless operations. 
KubeFleet is designed to be cloud provider agnostic. This allows KubeFleet to manage clusters across cloud providers and on-prem. It also supports provider mode that allows each adapter to provide their customized plug-ins like resource price.

## Key Features of KubeFleet 

 * Multi-Cluster Orchestration: KubeFleet enables users to create resources on a central cluster and selectively propagate these resources to desired member clusters. This intelligent scheduling is based on various factors such as names, labels, capacity, cluster size, and cost. It also has powerful override capabilities to allow users to customize the resources based on the selected cluster. 

 * Staged Rollouts: With KubeFleet, you can centrally manage the rollout of changes to your applications across multiple clusters. This feature ensures that updates are deployed in a controlled and efficient manner without causing multi-cluster failures. 

 * Config Management: KubeFleet streamlines config management by allowing teams to manage Kubernetes native configurations, such as resource quotas, RBAC, and network policies, at scale. It also provides a set of powerful tools to allow users to perform takeover actions, detect drifting, and report differences between the desired version and the applied resources on each cluster. 

 * One-way Connections: KubeFleet doesn't require connections from the central management cluster (i.e., hub cluster) to member clusters. It only requires one-way connections from member clusters to the hub, allowing member clusters to stay private. 

 

## How KubeFleet Works 

KubeFleet operates on a hub-and-spoke model, where a central hub cluster hosts the control plane, and member clusters are part of the fleet. The hub cluster manages the orchestration and coordination of resources across the member clusters. This architecture ensures that all clusters in the fleet are managed consistently and efficiently. 

![KubeFleet Architecture!](https://github.com/Azure/fleet/raw/main/docs/concepts/Components/architecture.jpg)


## Benefits of Using KubeFleet 

 * Enhanced Operational Efficiency: By centralizing the management of multiple clusters, KubeFleet reduces the complexity and overhead associated with managing individual applications and thus makes clusters expendable. 

 * Improved Security: KubeFleet's support for private egress and network isolation ensures that your clusters remain secure and compliant with industry standards. 

 * Scalability: Whether you have a few clusters or hundreds, KubeFleet scales to meet your needs, providing a flexible and robust solution for multi-cluster management. 

 * Community and Support: As an open-source project under the CNCF Sandbox, KubeFleet benefits from a vibrant community of contributors and users. This ensures continuous improvement and support for the solution. 

 

## Getting Started with KubeFleet 

To get started with KubeFleet, you can visit the [KubeFleet github repo](https://github.com/Azure/fleet). The repository provides all the resources you need to set up and start using KubeFleet in your environment. 

If you preferred a managed version of KubeFleet with full Azure support and traffic shifting capabilities, check out [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/overview).