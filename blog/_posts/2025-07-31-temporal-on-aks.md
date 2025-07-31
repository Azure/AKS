---
title: "Streamlining Temporal Worker Deployments on AKS"
description: "Learn how to deploy and scale Temporal Workers on AKS with ease. This guide walks you through containerizing Temporal applications, automating deployments, and optimizing resource management for resilient, enterprise-grade workflows on Kubernetes. "
date: 2025-07-31
authors:
  - Steve Womack
  - Brian Redmond
categories: developer
tags:
  - ai
  - open-source
---

## Introduction

[Temporal](https://temporal.io/) is an open source platform that helps developers build and scale resilient Enterprise and AI applications. Complex and long-running processes are easily orchestrated with durable execution, ensuring they never fail or lose state. Every step is tracked in an Event History that lets developers easily observe and debug applications. In this guide, we will help you understand how to run and scale your workers on Azure Kubernetes Service (AKS).

Running Temporal Workers efficiently is crucial for scalable and resilient distributed services. Azure Kubernetes Service (AKS) stands out as a leading platform for hosting Temporal workers, offering tight integration with Azure's ecosystem and built-in auto-scaling capabilities with fault tolerance—critical features for enterprise Temporal deployments.

Everything you need can be found at the following repo: [https://github.com/temporal-community/temporal-on-aks-starter](https://github.com/temporal-community/temporal-on-aks-starter)

## Getting Started

This walkthrough will cover writing Temporal Worker code, containerizing and publishing the Worker to Azure Container Registry (ACR), and then deploying it to AKS. We'll leverage Temporal's Python SDK for our examples, along with automation scripts.

### Project Structure and Configuration

A well-organized project is key to managing complex deployments. Your project's structure, with dedicated files for activities, workflows, workers, clients, and configuration, provides a clear roadmap for development and deployment.

When you're dealing with complex deployments, keeping things organized is important. Breaking everything out into separate files for activities, workflows, workers, clients, and config simplifies development and deployment.

Your approach to configuration is just as important. By using a config.env file, you centralize configuration and make environment variables easier to manage. For an AKS deployment, you would then configure variables such as:

* **ACR Name**: Azure Container Registry name
* **Resource Group**: Azure resource group name
* **ACR Username/Password/Email**: Credentials for ACR authentication
* **Temporal Address**: The address of your Temporal server (whether self-hosted or Temporal Cloud)
* **Temporal Namespace**: The Temporal namespace you're using
* **Temporal Task Queue**: The name of your task queue
* **Resource Limits**: CPU and memory requests and limits for your worker pods.

You would typically set up this configuration by copying an example file and then populating it with your specific Azure and Temporal environment values.

### Crafting Your Temporal Worker Implementation

Temporal applications elegantly separate business logic into **Workflow definitions**, with **Worker processes** handling the actual execution of Workflows and Activities.
Temporal applications separate business logic into **Workflow definitions**, with **Worker processes** handling the actual execution of Workflows and Activities.

Your `activities.py` file defines the individual tasks your workflows perform, like data processing or external API calls.

The `worker.py` file is where your Temporal Worker is initialized. It connects to the Temporal server and registers the workflows and activities it's responsible for. For AKS deployments, your worker would connect to your Temporal server address, handling both local development scenarios (without TLS or API Keys) and production environments (like which require TLS or an API Key).

Finally, a `client.py` application is used to trigger your workflows, initiating their execution within the Temporal system. This client would also connect to your Temporal server.

### Preparing Your Containers for Kubernetes

Containerization is a fundamental step for deploying applications to Kubernetes. Your project's `Dockerfile` provides the blueprint for building your worker image. This Dockerfile would typically:

* Use a suitable base image (e.g., Python slim).
* Set a working directory.
* Install necessary system dependencies.
* Install the Temporal Python SDK and other project dependencies.
* Copy your application code.
* Configure Python for unbuffered output.
* Ensure your startup scripts are executable.
* Define the command to start your worker process.

### Automated Deployment Process

A flexible automation system is important for reliable deployments to Kubernetes. This project’s `deploy.sh` script emulates this, handling everything from building and pushing Docker images to applying Kubernetes manifests. You’d likely substitute in your own automation processes and tools for your use cases.

The automated deployment process would generally involve:

1. **Configuration Setup**: Copying and configuring your environment variables in `config.env.`
1. **Building and Pushing Images**: Building your Docker image (potentially for multiple architectures) and pushing it to Azure Container Registry (ACR).
1. **Kubernetes Manifest Generation**: Scripts like your `generate-k8s-manifests.sh` would create Kubernetes deployment files, including:

    * An ACR authentication secret.
    * A ConfigMap for Temporal configuration.
    * A Deployment YAML for your application.

1. **Applying Manifests**: Using `kubectl` to create the necessary Kubernetes namespace, apply Secrets and ConfigMaps, and deploy your application to the AKS cluster.

### Local Development

Getting set up locally is the best way to start building and testing. Your project provides instructions that clearly lay out all the steps, which include:

* Installing Python dependencies.
* Configuring your `config.env` for local development.
* Running your worker and client applications directly.

For a faster setup, the `start.sh` script launches the local environment with a single command.

### Validating Worker Connectivity and Resource Management

After deployment, verify that Temporal Workers have successfully connected to the Temporal server. You can use `kubectl` commands to check pod statuses and examine worker logs for confirmation messages like "Starting worker... Awaiting tasks."

Resource management is critical for stable and efficient Kubernetes deployments. Your Kubernetes deployment is configured with specific CPU and memory requests and limits. These values are adjustable in your `config.env` and should be fine-tuned based on your worker's actual resource consumption to prevent performance bottlenecks or unnecessary resource allocation.

### Troubleshooting and Configuration Details

Common issues often revolve around configuration errors, ACR authentication, Temporal connection problems, or insufficient resource limits. Your guide's troubleshooting section provides valuable insights and useful `kubectl` commands for diagnosing and resolving these issues. These include checking configuration, viewing generated manifests, examining pod logs, and restarting deployments.

For a comprehensive understanding of all configuration options, refer to the project documentation. Your configuration system prioritizes environment variables and supports automatic manifest generation. This offers a flexible approach for both local and production deployments.

By following these principles and leveraging robust automation, you can confidently deploy and manage your Temporal Workers on Azure Kubernetes Service (AKS), ensuring your distributed services are scalable, resilient, and efficiently operated.

Want to learn more?  

* [Get started with Azure Kubernetes Service (AKS) basics](https://learn.microsoft.com/azure/aks/get-started-aks)
* [Free courses, examples and tutorials on Temporal.](https://learn.temporal.io/)
* [Join the Temporal Community Slack](https://temporalio.slack.com/join/shared_invite/zt-358xvk634-RXs1lBob_t9pdWsLWBCvCg#/shared-invite/email)
