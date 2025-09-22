---
title: "Ray on AKS"
date: "2025-01-13"
description: ""
authors: ["kenneth-kilty"]
tags: ["ai", "ray", "anyscale"]
---

We've released new guidance for running Ray on AKS!

<!-- truncate -->

## Open Source Ray on AKS

Ray is an open-source project developed at UC Berkeley's RISE Lab that provides a unified framework for scaling AI and Python applications. It consists of a core distributed runtime and a set of AI libraries designed to accelerate machine learning workloads. Ray may be run on Kubernetes via the KubeRay operator which simplifies the process of deploying and managing Ray clusters on Kubernetes.

Check out our new guide, "[Deploy a Ray cluster on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/ray-overview)," which walks you through deploying the necessary AKS infrastructure using Terraform to support a Ray cluster. This guide also includes a sample CPU-based project that demonstrates distributed training of a PyTorch model on Fashion MNIST with Ray Train on AKS.

## RayTurbo by Anyscale on AKS

For customers requiring commercial support, [RayTurbo](https://www.anyscale.com/product/platform/rayturbo) by [Anyscale](https://www.anyscale.com/) is supported on AKS. For more information regarding RayTurbo on AKS, reach out [directly to Anyscale](https://www.anyscale.com/book/demo?utm_source=azure&utm_medium=blog&utm_campaign=aks_rayturbo_blog).

Ray is the AI Compute Engine powering workloads with leading performance. RayTurbo, Anyscale's optimized Ray engine, delivers better performance, scale, reliability, and efficiency for AI workloads.

We look forward to seeing what amazing Ray and RayTurbo workloads you run on AKS!
