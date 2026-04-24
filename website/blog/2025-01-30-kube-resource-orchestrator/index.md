---
title: "Building Community with CRDs: Kube Resource Orchestrator"
date: "2025-01-30"
description: "Kube Resource Orchestrator (kro) streamlines Kubernetes complexity."
authors: ["matthew-christopher", "bridget-kromhout"]
tags: ["operations", "developer", "kro"]
---

[Kube Resource Orchestrator](https://kro.run/) introduces a Kubernetes-native, cloud-agnostic way to define groupings of Kubernetes resources. With [kro](https://github.com/kro-run/kro), you can group your applications and their dependencies as a single resource that can be easily consumed by end users.

Just as we collaborate in upstream Kubernetes, Azure is partnering with AWS and Google Cloud on kro (pronounced “crow”) to make Kubernetes APIs simpler for all Kubernetes users. We’re centering the needs of customers and the cloud native community to offer tooling that works seamlessly no matter where you run your K8s clusters.

<!-- truncate -->

## Why kro?

- **Kubernetes-native**: kro extends Kubernetes via Custom Resource Definitions (CRDs), so it works with any Kubernetes resource and with your existing tooling.
- **Approachable end-user experience**: kro simplifies defining end-user interfaces for complex groups of Kubernetes resources, making it easier for people who are not Kubernetes experts to consume services built on Kubernetes.
- **Consistency for application teams**: kro templates can be reused across different projects and environments, promoting standardization and reducing duplication of effort (while making life easier for platform engineering teams!)

## How kro works

kro is a Kubernetes-native framework that lets you create reusable APIs to deploy multiple resources as a single unit; at its core, kro enables abstraction.

kro introduces the concept of a ResourceGraphDefinition, which specifies how a standard Kubernetes Custom Resource Definition (CRD) should be expanded into a set of Kubernetes resources. Users specify their resources and the dependencies between them in a ResourceGraphDefinition, other users can deploy an instance of that definition, and kro will dynamically manage that instance, including propagating updates and driving the collection of resources to their goal state.

Examples of using kro with Azure resources:

- [A simple storage account and container](https://github.com/kro-run/kro/tree/main/examples/azure/storage-container)

- [An entire application, including both Azure resources and Kubernetes resources](https://github.com/kro-run/kro/tree/main/examples/azure/todo-app)

## Get started with kro

While we work to get kro ready for production, you can help shape its evolution. We’re already thinking ahead in our roadmap and will soon be sharing more details. We’re collaborating on [GitHub](https://github.com/kro-run/kro) and communicating in the [#kro channel](https://kubernetes.slack.com/archives/C081TMY9D6Y) on [Kubernetes Slack](https://communityinviter.com/apps/kubernetes/community), so join us there for updates.

Our choice to work in the open means that you can have confidence that we’re considering the community’s input and creating a structure for participation via open governance. If you’d like to help create a foundational tool from the ground up, with the benefit of having your needs informing the earliest decisions, we would be thrilled to have you build the kro project in the community with us!
