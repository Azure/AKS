---
title: "Accelerating Open-Source Innovation with AKS and Bitnami on Azure Marketplace"
date: "2025-03-11"
description: "Accelerate your Kubernetes deployments on Azure with Bitnami’s secure, pre-configured OSS solutions. This guide shows how to use Terraform, Azure CLI, and ARM templates to effortlessly deploy popular OSS offers like Argo CD, ClickHouse, MinIO, Prometheus Operator, RabbitMQ, Kafka, MongoDB, NGINX, PostgreSQL, and Redis—cutting operational overhead and fueling innovation"
authors: ["bob-mital"]
tags: ["general"]
---

Azure Kubernetes Service (AKS) is a highly managed platform that simplifies deploying, managing, and scaling containerized applications using Kubernetes on Azure. When paired with Bitnami's open-source solutions available on Azure Marketplace, AKS becomes an even more powerful platform for accelerating the deployment of Kubernetes workloads that rely on popular open-source projects.

<!-- truncate -->

Bitnami, a leader in open-source packaging and security for nearly 15 years, offers a catalog of over 250 pre-packaged open-source Kubernetes applications. These solutions are maintained with continuous updates—over 1,000 releases monthly—ensuring users always have access to the latest upstream patches and security fixes.

With Bitnami’s ready-to-use Kubernetes apps, available directly in the Azure Marketplace, users can skip writing Helm charts, YAML files, or custom deployment scripts. Instead, they can follow simple guides to deploy production-ready open-source software in just a few clicks.

This seamless integration allows teams to focus on building and innovating rather than managing infrastructure. Additionally, the automatic and timely security updates from Bitnami simplify lifecycle management and enhance the security posture of Kubernetes workloads on Azure.

### Why AKS + Bitnami OSS?

✔ Instant Open-Source Deployments on AKS

Bitnami's Kubernetes-optimized OSS solutions let you deploy databases, web apps, developer tools, and more on AKS quickly.

- **Deploy faster** – Get up and running in minutes with pre-configured applications. Deploy one-click via Azure marketplace onto your AKS cluster.
- **Reduce operational overhead** – Let AKS manage infrastructure while Bitnami provides security-hardened OSS solutions.
- **Ensure enterprise-grade reliability** – Built-in Azure scaling and monitoring keep applications running smoothly.
- **Simplified Kubernetes Management**: AKS is a fully managed Kubernetes platform that handles infrastructure complexities, freeing your team from operational burdens like cluster upgrades and patching. The Bitnami packaged OSS apps manage the application lifecycle, further reducing your workload.
- **Enhanced Security and Reliability**: Bitnami's open-source Kubernetes apps on Azure Marketplace are pre-packaged, secure, and rigorously certified. Each app undergoes thorough vulnerability scans and regular updates to ensure security and reliability.
- **Innovate with open source**: By using Bitnami's open-source strengths, you gain flexibility, transparency, and community-driven innovation. This helps your team build confidently on proven technology stacks, using popular open-source projects in your AKS workloads.

### Better Together: AKS + Bitnami OSS for Cloud-Native Success

By combining the power of AKS with Bitnami's trusted open-source applications, organizations can:

- **✔ Strengthen security posture** – Bitnami apps are pre-hardened, regularly updated, and scanned for vulnerabilities, while AKS provides built-in features like RBAC, network policies, and automated patching to safeguard your workloads.
- **✔ Deploy faster** – Get up and running in minutes with pre-configured applications. Deploy one-click via Azure marketplace onto your AKS cluster or programmatically via Terraform, Azure CLI or ARM templates.
- **✔ Ensure enterprise-grade reliability** – Built-in Azure scaling and monitoring keep applications running smoothly.

### Follow up links for detailed instructions and deployment options

**Link to OSS Deployment guides on AKS** [https://github.com/bitnami/azure-cnab-guides](https://github.com/bitnami/azure-cnab-guides)

| Deployment              | Description                                                    | Link                                                                                             |
| ----------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **Argo CD**             | Deploy Argo CD for GitOps continuous delivery on Kubernetes.   | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/argocd.md)              |
| **ClickHouse**          | Deploy ClickHouse, a fast open-source columnar database.       | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/clickhouse.md)          |
| **MinIO®**              | Deploy MinIO®, a high-performance object storage system.       | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/minio.md)               |
| **Prometheus Operator** | Deploy Prometheus Operator for monitoring and alerting.        | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/prometheus-operator.md) |
| **RabbitMQ**            | Deploy RabbitMQ, a message-broker for reliable communication.  | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/rabbitmq.md)            |
| **Kafka**               | Deploy Apache Kafka for distributed event streaming.           | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/kafka.md)               |
| **MongoDB**             | Deploy MongoDB, a popular NoSQL document database.             | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/mongodb.md)             |
| **NGINX**               | Deploy NGINX as a web server or reverse proxy.                 | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/nginx.md)               |
| **PostgreSQL**          | Deploy PostgreSQL, a powerful open-source relational database. | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/postgresql.md)          |
| **Redis**               | Deploy Redis, an in-memory key-value data store.               | [View Guide](https://github.com/bitnami/azure-cnab-guides/blob/main/docs/redis.md)               |

## What Are Kubernetes Apps?

As organizations scale their Kubernetes environments, the demand for **secure**, **intelligent**, and **cost-effective** deployments has never been higher.

👉 Learn more in the [What Are Kubernetes Apps?](https://techcommunity.microsoft.com/blog/appsonazureblog/deploy-smarter-scale-faster---secure-ai-ready-cost-effective-kubernetes-apps-at-/4363258?previewMessage=true) blog post.

## Programmatic Kubernetes Deployment

Learn how to programmatically deploy Kubernetes using the following tools:

- [Terraform](https://developer.hashicorp.com/terraform/install): Infrastructure as Code tool for provisioning Kubernetes clusters.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli): Command-line interface for managing Azure resources, including Kubernetes deployments.
- [ARM Templates](https://learn.microsoft.com/azure/aks/deploy-application-template): Azure Resource Manager templates for declarative deployment of Kubernetes applications.

👉 Check out the [blog post](https://techcommunity.microsoft.com/blog/AzureArcBlog/deploy-a-kubernetes-application-programmatically-using-terraform-and-cli/4357388) for a step-by-step guide on deploying a Kubernetes application using Terraform and Azure CLI.
