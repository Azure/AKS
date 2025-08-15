---
title: "Announcing the CLI Agent for AKS: Agentic AI-powered operations and diagnostics at your fingertips"
description: "Learn more about the Agentic AI-powered CLI experience for AKS and how it can streamline your cluster diagnostics and operational workflows."
date: 2025-08-15 # date is important. future dates will not be published
author: Pavneet Ahluwalia, Julia Yin, Aritra Ghosh # must match the authors.yml in the _data folder
categories: 
- general 
- ai
- operations
tags:
  - ai
  - agent
  - open-source

---

Last week at KubeCon India, the AKS team shared our newest Agentic AI-powered feature with the broader Kubernetes community: the CLI Agent for AKS. CLI Agent for AKS is a new AI-powered command-line experience designed to help Azure Kubernetes Service (AKS) users troubleshoot, optimize, and operate their clusters with unprecedented ease and intelligence.

Built on **open-source building blocks** — including the CNCF-pending [HolmesGPT](https://github.com/robusta-dev/holmesgpt) agent and the [AKS Model Context Protocol (MCP) server](https://github.com/Azure/aks-mcp) — the Agentic CLI brings secure, extensible, and intelligent agentic workflows directly to your terminal.

We have been working on this for the last 3 months, and for starters we focused on the no. 1 pain point for most users - troubleshooting and diagnosing issues in their environments. We are currently providing early access to a limited set of users to collaborate closely with and gather feedback, please sign up here if you are interested: aka.ms/cli-agent/signup

![cli-agent-vision](/assets/images/cli-agent-for-aks/cli-agent-vision.png)

## Why We Built This?

AKS's mission is to "Enable developers, SREs, Devops/Platform engineers to do more with AKS". AI is the single biggest force multiplier we have seen in a generation, we wanted to harness the power of this foundational technology in a responsible, secure, and focused way to solve hard problems for our users by applying it to complex problems like troubleshooting, optimizing cost, managing configuration/decision overload.

The first tradeoff we faced was, do we go for breadth of use cases (such as all aks interactions) or depth of usefulness (focused application to specific patterns). We have tried to strike a balance by going for depth in troubleshooting for 4 main types of problems - networking/DNS, pod scheduling, node health and cluster CRUD issues and failures while providing a table stakes experience for general Kubernetes and AKS (in fact internally we first called it AKS AI troubleshooter). But rest assured, we have every intention to cover most of the AKS user workflows and use cases, this is where your feedback is invaluable.

Troubleshooting in Kubernetes is notoriously complex. AKS customers—from cloud-native startups to large enterprises—face several recurring challenges. AKS users often face overwhelming signal fragmentation—struggling to correlate metrics, logs, and traces across layers and tools—while lacking the deep Kubernetes and Azure expertise needed to interpret them. Troubleshooting is further complicated by the need to manually wrangle multiple tools, leading to high mean-time-to-resolution (MTTR) and avoidable support costs. Existing tools surface raw data but lack built-in intelligence to guide users through diagnosis and resolution, making AI-powered assistance both timely and essential.

The AKS Agentic CLI is designed to solve these problems—reducing downtime, bridging the knowledge gap and empowering users to troubleshoot and manage their AKS environments confidently.

[Internal slide, on how we are thinking about this]
[customer benefits slide]

## Built on Open Source: HolmesGPT + AKS-MCP

Another question we wrestled with was - should we build something proprietary or build/contribute in the open source community. This was simpler, "Working in the Open-Source community" is one of the core product pillars for AKS , so that is what we did.

**The agent framework - HolmesGPT**: An open-source agentic AI framework that performs root cause analysis (RCA), executes diagnostic tools, and synthesizes insights using natural language prompts.  We conducted a thorough due dilligence of serveral existing open-sourced solutions, and even built internal prototypes. In the end we decided to work with Robusta.dev on homlesgpt becuase of its architecture couples with an active and collaberateive community - it is highly extensible as it supports modular toolsets, MCP-servers, custom runbooks, and extensible prompts tailored for Kubernetes environments. Microsoft AKS team is now a co-maintainer of Homlesgpt, and Robusta has kindly donated it to CNCF as a sandbox project. We welcome you all to join this community and contribute: [HolmesGPT](https://github.com/robusta-dev/holmesgpt).

**The tools and capabilities - AKS-MCP Server**: A secure, protocol-first bridge between AI agents and AKS clusters. It exposes Kubernetes and Azure APIs, observability signals, and diagnostic tools to AI agents via a standardized interface . Today, you can use it aks-mcp or any mcp server as a custom toolset (learn more here) , we will add a more seamless integration as we add more functionality and best practice knowledge into the [AKS-MCP project](https://github.com/Azure/aks-mcp).

Together, these components form a **lego-block architecture** that allows users to plug in their preferred AI providers, observability tools, and cluster configurations—while maintaining full control over data and execution.

## Designing for Safety: Why We Started with a CLI Experience

While our long-term vision is to build an **autonomous, AI-powered autohealing system** — a true “SRE-as-a-service” for AKS—our first step is intentionally cautious.

In production environments, the **cost of failure is high**. Automated actions without human oversight can lead to unintended disruptions, especially when AI agents misinterpret telemetry or act on incomplete data. Recent public incidents across the industry have reaffirmed this tenet: **autonomy without accountability is risky**.

That’s why we chose to begin with a **human-in-the-loop CLI experience**.

The AKS Agentic CLI is designed to **assist**, not replace, the operator. It synthesizes insights, runs diagnostics, and recommends actions—but leaves the final decision to the user. This approach ensures:

- **Transparency**: Users see exactly what tools were run and what data was analyzed.
- **Control**: No changes are made to the cluster without explicit user approval.
- **Trust**: AI outputs are grounded in real telemetry and presented with supporting evidence.

This model allows us to validate the AI’s reasoning, gather feedback, and iterate safely—while laying the foundation for more autonomous workflows in the future.

Security and privacy are core to the Agentic CLI experience:

- **Runs locally**: All diagnostics and data collection happen on the user’s machine.
- **Uses Azure CLI Auth**: Inherits Azure identity and RBAC permissions, ensuring access only to authorized resources.
- **Bring Your Own AI**: Users configure their own AI provider (OpenAI, Azure OpenAI, Anthropic, etc.)—no telemetry is sent to Microsoft or third-party services .

## 🔌 Extensible and Customizable

The Agentic CLI is designed to adapt to your environment:

- **Custom Toolsets**: Integrate with Prometheus, Datadog, Dynatrace, or proprietary observability platforms.
- **Runbook Plugins**: Add your own troubleshooting workflows or use community-contributed ones.
- **MCP Server Support**: Expand capabilities by connecting to AKS-MCP or other MCP servers for advanced diagnostics, including AppLens detectors, Azure Monitor, and debug pod deployment .

## How to Get Started:

Once you have signed up for the limited preview, we will reach out to everyone in batches and provide access to the CLI installation guide, documentation and next steps. 

You can start by simply running the following command to understand what commands and capabilities CLI Agent for AKS has to offer:

$ az aks agent --help
// or $ az aks agent "how is my cluster <Cluster-name> in resource group <Resource-group-name>".

Here are a few more examples to help you see different ways to use az aks agent : 

### 🧠 Node NotReady

Diagnose kubelet crashes, CNI failures, and resource pressure:

$ az aks agent "why is one of my nodes in NotReady state?"

### 🌐 DNS Failures

Identify CoreDNS issues, NSG misconfigurations, and upstream DNS problems:

$ az aks agent "why are my pods failing DNS lookups?"

### 🕵️ Pod Scheduling Failures

Detect resource constraints, affinity mismatches, and zone limitations:

$ az aks agent "why is my pod stuck in Pending state?"

### 🔄 Upgrade Failures

Pinpoint PDB violations, quota issues, and IP exhaustion:

$ az aks agent "my AKS cluster is in a failed state, what happened?"

### General CloudOps and Optimizations 

$ az aks agent " how can optimize the cost of my cluster?"

Each scenario is powered by AI-driven reasoning, tool execution, and actionable recommendations—bridging the gap between raw telemetry and real insight .

## 🌐 Vision: Omnichannel AI Across AKS Interfaces

The Agentic CLI is just the beginning. Our long-term vision is to bring **agentic AI** troubleshooting across all AKS interfaces:
- **Azure Portal**: Integrated diagnostics via Copilot and Diagnose & Solve.
- **Visual Studio Code**: One-click troubleshooting via AKS extension and MCP integration.
- **AKS Desktop**: Native agent mode powered by HolmesGPT.
- **Azure CLI**: Managed experience via az aks debug and az aks troubleshoot.

This omnichannel strategy ensures that every AKS user—whether developer, operator, or SRE—can access intelligent troubleshooting wherever they work.

## 📣 Join the Preview

We’re actively gathering feedback and iterating — so please share your experience via GitHub issues or email us at aksagentcli@service.microsoft.com.

## 💬 Final Thoughts

The AKS Agentic CLI represents a major step forward in making Kubernetes operations more accessible, intelligent, and secure. By combining open-source innovation with Azure-native integration, we’re empowering every AKS user to troubleshoot faster, reduce downtime, and focus on what matters most: building great applications.

Stay tuned for more updates as we expand capabilities, integrate with managed experiences, and bring AI-powered troubleshooting to every corner of the AKS ecosystem.
