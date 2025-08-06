---
title: "Announcing the AKS-MCP Server: Unlock Intelligent Kubernetes Operations"
description: "Learn about AKS-MCP server, the latest open-source tooling to Unlock intelligent automation 
by standardizing and streamlining the way AI agents interact with your AKS cluster."
date: 2025-08-06
authors: Pavneet Ahluwalia
categories: 
  - developer
  - ai
  - operations
tags:
  - ai
  - mcp
  - open-source
---

We're excited to announce the launch of the **AKS-MCP Server**.
An open source Model Context Protocol (MCP) server designed to make your Azure Kubernetes Service (AKS)
clusters AI-native and more accessible for developers, SREs, and platform engineers through Agentic AI workflows.

AKS-MCP isn't just another integration layer.
It empowers cutting-edge AI assistants (such as **Claude**, **Cursor**, and **GitHub Copilot**)
to interact with AKS through a secure, standards-based protocol—opening new possibilities for
automation, observability, and collaborative cloud operations.

![aks-mcp-github](/assets/images/aks-mcp/aks-mcp-announcement.pngg)

## The Problem: Why Do We Need MCP Now?

The biggest pain point facing modern AI assistants is not their reasoning or language abilities, or writing good prompts (although still important)
but the fragmented, brittle context in which they operate. Organizations today are struggling with:

- **Siloed information and workflows**: AI can only act on what it can see—often, just a fraction of what's truly relevant. For example, Kubectl commands may not be enough for Claude code to figure out the issues you are facing or [you may not want to put pictures of several dashboards](https://www.anthropic.com/news/how-anthropic-teams-use-claude-code), log lines etc. into you coding agent.
- **Complex, expensive integrations**: Every new data source, tool, or AI agent means more custom connectors, patches, and technical debt. Environments evolve, tooling evolves, you might be using ArgoCD, or Istio, or other open-sourced/third party tooling in your workflows. How can users extend the AI agent's capabilities as their environment evolves, coding one connector at a time?
- **Stunted automation and insight**: When assistants lack rich, real-time access to infrastructure, APIs, and data sources, their utility is massively limited. For example, GitHub Copilot can tell you how to get health of your AKS clusters from Azure APIs or in other cases, it may ask for resource information such as subscription ID, Resource Group etc. before it can really start helping you. Often missing the connection between resources to do truly autonomous diagnostics.

![GitHub Copilot Example 1](/assets/images/aks-mcp/GHC1.png)

![GitHub Copilot Example 2](/assets/images/aks-mcp/GHC2.png)

## Our thought process

What we felt is needed here is a building block for real context engineering i.e. "the art of providing all the context for the task to be plausibly solvable by the LLM." - Tobi Lutke. The rise and standardization around the open [Model Context Protocol (MCP)](https://modelcontextprotocol.io/overview) opens the doors for us to start realizing this vision.

Our team thought hard about what should be the tenets of an AKS AI experience and how to realize this, as we had several tradeoffs to navigate, this is what we narrowed it down to:

- **Open-source and community driven**: We launched aks-mcp as an open-sourced (under MIT license) project not just because we wanted to tap into the rich cloud native open source community, but also since security, trust and transparency are top of mind for our users and us. By opening up the source code, and enabling users to contribute, we believe we are closer to that goal.This approach aligns with AKS's commitment to open development, contribution to the community, and cloud-native flexibility for users of all sizes.
- **Plug-and-play AI agent support**: We wanted to be where our customers are, the solutions we build should work out of the box with Claude, Cursor, GitHub Copilot, and more—so you can use the assistants you already love. Hence our investment in the key LEGO building blocks of a best-in-class AI Agent experience for Kubernetes. Step one in that process was building an MCP server for AKS that has the depth of tools needed to provide detailed context, and integrating it into the AKS VS Code extension v1.6.12. But we will not stop here, stay tuned for other announcements!
![LEGO Building Blocks](blog/assets/images/aks-mcp/image-3.png)
- **Speed over Perfection**: The underlying technology for AI Agents is changing fast as demonstrated by the growth of MCP servers, and even changes with it - such as the [deprecation of the SSE transport](https://github.com/modelcontextprotocol/modelcontextprotocol/discussions/308) in favor of streamable HTTP. This highlights the need to move fast and trust in users' understanding of the evolving ecosystem. That is why we started by releasing the binaries and docker images on GitHub, so that users can run it locally or in-cluster and unlock its benefits, while the community converges on a secure remote MCP server architecture.
- **Human-in-the-loop workflows first**: AI is delivering massive value and rewards for organizations across the globe, however its non-deterministic nature introduces risks. We believe users want control over actions performed by AI agents. Whether that is deploying a debug pod or creating/deleting resources - users want AI tools to request explicit write permissions. Hence, aks-mcp defaults to read-only tools with explicit user opt-in required for write tool access.

## The Solution: AKS-MCP's Open, Secure Protocol

We believe AKS-MCP is that building block and acts as a universal, protocol-first bridge between AI agents and AKS.

- **Secure by default**: Leverage Azure authentication and granular RBAC to keep operations and data safe, the agents can only access the data/resources that users have access to.
- **Extensible and community-driven**: Fully open source, so you can adapt, extend, and evolve the platform for new tools and future needs.
- **In-depth troubleshooting tools**: Supports a number of tools to interact with Kubernetes and Azure APIs, monitoring telemetry (activity/audit logs), diagnostic tooling such as [Inspektor Gadget](https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/logs/capture-system-insights-from-aks?tabs=azurelinux30). AKS customers have repeatedly shared that troubleshooting Kubernetes and AKS issues is hard, so we have started with that problem and will expand rapidly over the coming weeks.

![AKS-MCP Architecture](/assets/images/aks-mcp/mcp-arch.png)

For a full list of tools and capabilities please see [Available tools](https://github.com/Azure/aks-mcp#available-tools).

## Getting Started with AKS MCP

### Option A: VS Code Extension (Recommended)

To make it easy for AKS users to leverage the new AKS-MCP server, we have integrated it with AKS VS Code Extension starting with version 1.6.12.

1. Install the AKS Extension from the VS Code Marketplace.
2. Run **AKS: Setup AKS MCP Server** from the command palette (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
3. The extension automatically installs the binary based on the platform, configures the MCP server and updates your VS Code `mcp.json` file.
4. Run **MCP: List Servers** (via Command Palette). From there, you can start the AKS-MCP server or view its status.
5. Instantly start using GitHub Copilot or your favorite AI agent with first-class access to AKS tools.

This one-click setup brings AI-powered Kubernetes operations to every developer's fingertips.

![aksmcp-github](/assets/images/aks-mcp/aks-mcp-vscode.png)

### Option B: Download Binaries/Container Image from GitHub

You can download the correct binaries from the [AKS-MCP GitHub releases page](https://github.com/Azure/aks-mcp),
and then manually configure the MCP server in VS Code or the IDE/agent of your choice.
Find information on [how to install and get started](https://github.com/Azure/aks-mcp#how-to-install).

## Real-World Example Use Cases

AKS-MCP enables intelligent, agent-driven cloud operations. Here are a few hands-on scenarios that you can try in GitHub Copilot, Claude Code or other MCP compatible agents:

### Diagnose Resource Health

**Prompt**: *"Why is one of my AKS nodes in NotReady state?"*

### Understand Network Security

**Prompt**: *"Can you help me understand my AKS cluster's VNet and NSG configuration? I think DNS traffic is being blocked."*

### Automate Operations

**Prompt**: *"Scale my payments-api deployment to 5 replicas and confirm rollout status."*

The result? AI agents that can reason, act, and surface Azure-specific insights—accelerating DevOps and cloud troubleshooting. See an example below: 
![github-aks-mcp](blog/assets/images/aks-mcp/ghc-mcp.png)

## Get Involved

Visit [Azure/aks-mcp](https://github.com/Azure/aks-mcp) on GitHub. We're looking for feedback, contributions, and innovative feature ideas.

Let's take the next step in cloud-native DevOps—where Kubernetes, AI, and open protocols empower every developer.
