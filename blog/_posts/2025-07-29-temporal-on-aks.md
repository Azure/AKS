---
title: "Streamlining Temporal Worker Deployments on Azure Kubernetes Service (AKS)"
description: ""
date: 2025-07-29
authors:
  - Steve Womack
  - Brian Redmond
categories: developer
---

## Introduction

[Temporal](https://temporal.io/) is an open source platform that helps developers build and scale resilient Enterprise and AI applications. Complex and long-running processes are easily orchestrated with durable execution, ensuring they never fail or lose state. Every step is tracked in an Event History that lets developers easily observe and debug applications. In this guide, we will help you understand how to run and scale your workers on Azure Kubernetes Service (AKS).

Running Temporal Workers efficiently is crucial for scalable and resilient distributed services. Azure Kubernetes Service (AKS) stands out as a leading platform for hosting Temporal workers, offering tight integration with Azure's ecosystem and built-in auto-scaling capabilities with fault tolerance—critical features for enterprise Temporal deployments.

This guide outlines the process of deploying and operating Temporal Workers on AKS. The instructions are broadly applicable to both self-hosted Temporal installations and Temporal Cloud environments.

Everything you need can be found at the following repo: 
https://github.com/temporal-community/temporal-on-aks-starter

## Getting Started

This walkthrough will cover writing Temporal Worker code, containerizing and publishing the Worker to Azure Container Registry (ACR), and then deploying it to AKS. We'll leverage Temporal's Python SDK for our examples, along with automation scripts.

### Project Structure and Configuration

A well-organized project is key to managing complex deployments. Your project's structure, with dedicated files for activities, workflows, workers, clients, and configuration, provides a clear roadmap for development and deployment.

Centralized configuration management is vital. Your project's use of a config.env file simplifies managing environment variables. When deploying to AKS, you'd configure variables such as:

* Azure Subscription ID: Your Azure subscription ID
* ACR Name: Azure Container Registry name
* Resource Group: Azure resource group name
* ACR Username/Password/Email: Credentials for ACR authentication
* Temporal Address: The address of your Temporal server (whether self-hosted or Temporal Cloud)
* Temporal Namespace: The Temporal namespace you're using
* Temporal Task Queue: The name of your task queue
* Resource Limits: CPU and memory requests and limits for your worker pods.

You would typically set up this configuration by copying an example file and then populating it with your specific Azure and Temporal environment values.

### Crafting Your Temporal Worker Implementation

Temporal applications elegantly separate business logic into **Workflow definitions**, with **Worker processes** handling the actual execution of Workflows and Activities.

Your `activities.py` file would define the individual tasks your workflows perform, like data processing or external API calls. The `workflows.py` file orchestrates these activities into a cohesive business process.

The `worker.py` file is where your Temporal Worker is initialized. It connects to the Temporal server and registers the workflows and activities it's responsible for. For AKS deployments, your worker would connect to your Temporal server address, handling both local development scenarios (without TLS or API Keys) and production environments (like which require TLS or an API Key).

Finally, a `client.py` application is used to trigger your workflows, initiating their execution within the Temporal system. This client would also connect to your Temporal server.

### Preparing Your Containers for Kubernetes

Containerization is a fundamental step for deploying applications to Kubernetes. Your project's `Dockerfile` provides a clear blueprint for building your worker image. This Dockerfile would typically:

* Use a suitable base image (e.g., Python slim).
* Set a working directory.
* Install necessary system dependencies.
* Install the Temporal Python SDK and other project dependencies.
* Copy your application code.
* Configure Python for unbuffered output.
* Ensure your startup scripts are executable.
* Define the command to start your worker process.


### Automated Deployment Process 

A robust automation system is invaluable for streamlined deployments to Kubernetes. This project’s `deploy.sh` script emulates this, handling everything from building and pushing Docker images to applying Kubernetes manifests. You’d likely substitute in your own automation processes and tools for your use-cases.

The automated deployment process would generally involve:

1. **Configuration Setup**: Copying and configuring your environment variables in `config.env.`
2. **Building and Pushing Images**: Building your Docker image (potentially for multiple architectures) and pushing it to Azure Container Registry (ACR).
3. **Kubernetes Manifest Generation**: Scripts like your `generate-k8s-manifests.sh` would create Kubernetes deployment files, including:
* An ACR authentication secret.
* A ConfigMap for Temporal configuration.
* A Deployment YAML for your application.
4. **Applying Manifests**: Using `kubectl` to create the necessary Kubernetes namespace, apply Secrets and ConfigMaps, and deploy your application to the AKS cluster.

### Local Development

For efficient development and testing, a local setup is crucial. Your project provides clear instructions for setting up your local environment, including:

* Installing Python dependencies.
* Configuring your `config.env` for local development.
* Running your worker and client applications directly.

A quick start script can further simplify this process, allowing you to bring up your local Temporal Worker environment with a single command. `start.sh` is this project’s version.

### Validating Worker Connectivity and Resource Management 

After deployment, it's essential to verify that your Temporal Workers have successfully connected to the Temporal server. You can use `kubectl` commands to check pod statuses and examine worker logs for confirmation messages like "Starting worker... Awaiting tasks."

Resource management is critical for stable and efficient Kubernetes deployments. Your Kubernetes deployment is configured with specific CPU and memory requests and limits. These values are adjustable in your `config.env` and should be fine-tuned based on your worker's actual resource consumption to prevent performance bottlenecks or unnecessary resource allocation.

### Troubleshooting and Configuration Details

Common issues often revolve around configuration errors, ACR authentication, Temporal connection problems, or insufficient resource limits. Your guide's troubleshooting section provides valuable insights and useful `kubectl` commands for diagnosing and resolving these issues. These include checking configuration, viewing generated manifests, examining pod logs, and restarting deployments.

For a comprehensive understanding of all configuration options, referring to detailed configuration documentation is always recommended. Your configuration system, which prioritizes environment variables and supports automatic manifest generation, offers a flexible approach for both local and production deployments.

By following these principles and leveraging robust automation, you can confidently deploy and manage your Temporal Workers on Azure Kubernetes Service (AKS), ensuring your distributed services are scalable, resilient, and efficiently operated.