---
title: "Announcing the CLI Agent for AKS: Agentic AI-powered operations and diagnostics at your fingertips"
description: "Learn more about the Agentic AI-powered CLI experience for AKS and how it can streamline your cluster diagnostics and operational workflows."
date: 2025-08-15
author: Pavneet Ahluwalia, Julia Yin, Aritra Ghosh
categories: 
- general 
- ai
- operations
tags:
  - ai
  - agent
  - open-source

---

At KubeCon India earlier this month, the AKS team shared our newest Agentic AI-powered feature with the broader Kubernetes community: the **CLI Agent for AKS**. CLI Agent for AKS is a new AI-powered command-line experience designed to help Azure Kubernetes Service (AKS) users troubleshoot, optimize, and operate their clusters with unprecedented ease and intelligence.

Built on **open-source building blocks** — including the CNCF-pending [HolmesGPT](https://github.com/robusta-dev/holmesgpt) agent and the [AKS Model Context Protocol (MCP) server](https://github.com/Azure/aks-mcp) — the Agentic CLI brings secure, extensible, and intelligent agentic workflows directly to your terminal.

We have been working on this experience for the last few months, starting with a focus on the number one pain point for most Kubernetes users: troubleshooting and diagnosing issues in their environments. We are currently providing early access to a limited set of users to collaborate closely with and gather feedback. If you are interested in participating, please fill out our [sign up form](https://aka.ms/aks/cli-agent/signup).

![cli-agent-vision](/assets/images/cli-agent-for-aks/cli-agent-vision.png)

## Why We Built This?

AKS's mission is to "enable developers, SREs, DevOps and platform engineers to do more with AKS." AI is the single biggest force multiplier we have seen in a generation, and we wanted to harness the power of this foundational technology in a responsible, secure, and focused way. We want to put this technology in the hands of our users to solve complex and difficult problems like troubleshooting, optimizing cost, managing configuration/decision overload.

The first tradeoff we faced was whether we should solve for a breadth of use cases, such as all AKS interactions, or depth of usefulness by targeting focused and specific scenarios. We are striking a balance by going for depth in troubleshooting, the most common and proven problem which we see agentic AI is the most promising (in fact, internally we first called this project the "AKS AI troubleshooter"). We focused on 4 main types of problems for troubleshooting: networking/DNS, pod scheduling, node health, and cluster CRUD issues and failures. In parallel, we are also building a table-stakes experience for general Kubernetes and AKS use cases since we see agentic AI being widely useful across many different everyday scenarios. Rest assured, we have every intention to cover most of the AKS user workflows and use cases, and this is where your feedback is invaluable.

Troubleshooting in Kubernetes is notoriously complex. AKS customers from cloud-native startups to large enterprises face several recurring challenges. One example is the overwhelming signal fragmentation and struggle to correlate metrics, logs, and traces across layers and tools. This is exacerbated without the deep Kubernetes and Azure expertise needed to interpret all of these cluster signals. Troubleshooting is further complicated by the need to manually wrangle multiple tools, leading to high mean-time-to-resolution (MTTR) and avoidable support costs. Existing tools can surface raw data but lack built-in intelligence to guide users through diagnosis and resolution, making AI-powered assistance both timely and essential.

The AKS Agentic CLI is designed to solve these problems to reduce downtime, bridge the knowledge gap, and empower users to troubleshoot and manage their AKS environments with confidence.

![target-customer-pain-points](/assets/images/cli-agent-for-aks/target-customer-pain-points.png)
![target-customer-benefits](/assets/images/cli-agent-for-aks/cli-agent-benefits.png)

## Built on Open Source: HolmesGPT + AKS-MCP

Another question we wrestled with was: should we build something proprietary or build/contribute in the Open Source community? This was a simple decision because "Working in the Open Source community" is one of the core product pillars for AKS, so that is what we did.

**The agent framework - HolmesGPT**: HolmesGPT is an open-source agentic AI framework that performs root cause analysis (RCA), executes diagnostic tools, and synthesizes insights using natural language prompts. Before deciding on an open-source project to work with, we conducted a thorough due diligence of several existing open-source solutions and even built internal prototypes. In the end, we decided to work with the team at Robusta.dev on HolmesGPT because of several reasons:

- Highly extensible architecture with built-in support for modular toolsets, MCP servers, and custom runbooks
- Extensible and comprehensive prompts tailored for Kubernetes environments
- An active and collaborative community in the open-source

The Microsoft AKS team is now a co-maintainer of HolmesGPT and Robusta has kindly donated it to CNCF as a Sandbox project. We welcome you all to join this community and contribute: [HolmesGPT](https://github.com/robusta-dev/holmesgpt).

**The tools and capabilities - AKS-MCP Server**: The AKS Model Context Protocol (MCP) server provides a secure, protocol-first bridge between AI agents and AKS clusters. It exposes Kubernetes and Azure APIs, observability signals, and diagnostic tools to AI agents via a standardized interface. Today, you can use AKS-MCP (or any MCP server of your choosing) in combination with HolmesGPT (learn more [here](https://docs.robusta.dev/master/configuration/holmesgpt/remote_mcp_servers.html)), and we will add a more seamless integration as we add more functionality and best practice knowledge into the [AKS-MCP project](https://github.com/Azure/aks-mcp).

Together, these components form a **lego-block architecture** that allows users to plug in their preferred AI providers, observability tools, and cluster configurations all while maintaining full control over data and execution.

![cli-agent-lego-blocks](/assets/images/cli-agent-for-aks/cli-agent-lego-blocks.png)

## Designing for Safety: Why We Started with a CLI Experience

While our long-term vision is to build an **autonomous, AI-powered autohealing system** (a true “SRE-as-a-service” for AKS), our first step is intentionally cautious.

In production environments, the **cost of failure is high**. Automated actions without human oversight can lead to unintended disruptions, especially when AI agents misinterpret telemetry or act on incomplete data. Recent public incidents across the industry have reaffirmed this tenet: **autonomy without accountability is risky**.

That’s why we chose to begin with a **human-in-the-loop CLI experience**.

The AKS Agentic CLI is designed to **assist**, not replace, the Kubernetes cluster operator. The agent synthesizes insights, runs diagnostics, and recommends actions but leaves the final decision to the user. This approach ensures:

- **Transparency**: Users see exactly what tools were run and what data was analyzed.
- **Control**: No changes are made to the cluster without explicit user permissions.
- **Trust**: AI outputs are grounded in real telemetry and presented with supporting evidence.

This model allows us to validate the AI’s reasoning, gather feedback, and iterate safely while laying the foundation for more autonomous workflows in the future.

Security and privacy are core to the Agentic CLI experience:

- **Runs locally**: All diagnostics and data collection are performed on the user’s machine, ensuring that no data leaves your client or is stored elsewhere.
- **Uses Azure CLI Auth**: Inherits Azure identity and RBAC permissions from the user, ensuring access only to authorized resources.
- **Bring Your Own AI**: Users configure their own AI provider (OpenAI, Azure OpenAI, Anthropic, etc.) so no user data is retained by Microsoft. Users can bring their own LLMs approved by their organization - including Azure OpenAI instances deployed in their own subscriptions and virtual network.

![cli-agent-demo](/assets/images/cli-agent-for-aks/cli-agent-demo.gif)

## 🔌 Extensible and Customizable

The Agentic CLI is designed to adapt to your environment:

- **Custom Toolsets**: Easily configure integrations with Prometheus, Datadog, Dynatrace, or proprietary observability platforms.
- **Runbook Plugins**: Add your own troubleshooting workflows or use community-contributed ones.
- **MCP Server Support**: Expand capabilities by connecting to AKS-MCP or other MCP servers for advanced diagnostics, including AppLens detectors, Azure Monitor, and debug pod deployment.

## How to Get Started

Once you have signed up for the [limited preview](https://aka.ms/aks/cli-agent/signup), we will reach out to everyone in batches and provide access to the CLI installation guide, documentation and next steps.

Once you have access, get started the following command to understand what commands and capabilities CLI Agent for AKS has to offer:

```
az aks agent --help
// or $ az aks agent "how is my cluster [Cluster-name] in resource group [Resource-group-name]".
```

Here are a few more examples of different ways you can use the CLI Agent:

### 🧠 Node NotReady

Diagnose kubelet crashes, CNI failures, and resource pressure:

```
az aks agent "why is one of my nodes in NotReady state?"
```

### 🌐 DNS Failures

Identify CoreDNS issues, NSG misconfigurations, and upstream DNS problems:

```
az aks agent "why are my pods failing DNS lookups?"
```

### 🕵️ Pod Scheduling Failures

Detect resource constraints, affinity mismatches, and zone limitations:

```
az aks agent "why is my pod stuck in Pending state?"
```

### 🔄 Upgrade Failures

Pinpoint PDB violations, quota issues, and IP exhaustion:

```
az aks agent "my AKS cluster is in a failed state, what happened?"
```

### General CloudOps and Optimizations

```
az aks agent "how can I optimize the cost of my cluster?"
```

Each scenario is powered by AI-driven reasoning, tool execution, and actionable recommendations to bridge the gap between raw telemetry and real insights.

## 🌐 Vision: Omnichannel AI Across AKS Interfaces

The CLI Agent for AKS is just the beginning. We want to be where our customers are, and we understand that every user has preference of tooling - some prefer command-line interfaces, others use the AKS VS Code Extension, and others use Azure Copilot. Hence, our long-term vision is to integrate with all the user's touchpoints so that they can get a consistent and comprehensive experience wherever they are. Some of our next focus areas include:

- **Azure Portal**: Integrated agentic capabilities such as diagnostics and operations via Copilot and Diagnose & Solve.
- **Visual Studio Code**: One-click troubleshooting via the AKS VS Code Extension and MCP integration.

This omnichannel strategy ensures that every AKS user across developers, operators, or SREs can access intelligent troubleshooting wherever they work.

## 📣 Join the Preview

We’re actively gathering feedback and iterating throughout the process before officially launching the CLI Agent for AKS via our Limited Preview: aka.ms/cli-agent/signup. Please feel free to share your experience with the CLI Agent or AKS-MCP via GitHub issues or through our [feedback form](https://aka.ms/aks/cli-agent/feedback).

## 💬 Final Thoughts

The AKS Agentic CLI represents a major step forward in making Kubernetes operations more accessible, intelligent, and secure. By combining open-source innovation with Azure-native integrations, we’re empowering every AKS user to troubleshoot faster, reduce downtime, and focus on what matters most: building great applications.

Stay tuned for more updates as we expand capabilities, integrate with managed experiences, and bring AI-powered troubleshooting to every corner of the AKS ecosystem!
