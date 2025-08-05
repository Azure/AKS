---
title: "Announcing the AKS-MCP Server: Unlock Intelligent Kubernetes Operations"
description: "Learn about AKS-MCP server, the latest open-source tooling to Unlock intelligent automation 
by standardizing and streamlining the way AI agents interact with your AKS cluster."
date: 2025-08-05
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
clusters AI-native and more accessible than ever for developers, SREs, and platform engineers.

AKS-MCP isn't just another integration layer.
It empowers cutting-edge AI assistants (such as **Claude**, **Cursor**, and **GitHub Copilot**)
to interact with AKS through a secure, standards-based protocol—opening new possibilities for
automation, observability, and collaborative cloud operations.

We believe users should have the flexibility to leverage the AI tooling of their choice with AKS. For instance if you have a strong
affinity for Claude code or Github-Copilot or some other agent for your workflows,
you can plug-in AKS-MCP Server and unlock intelligent interactions, automation and troubleshooting for your AKS environments.

![aks-mcp-github](/assets/images/aks-mcp/aks-mcp-github.png)

## The Problem: Why Do We Need MCP Now?

The biggest pain point facing modern AI assistants is not their reasoning or language abilities,
but the fragmented, brittle context in which they operate. Organizations today are struggling with:

- **Siloed information and workflows**: AI can only act on what it can see—often, just a fraction of what's truly relevant.
- **Complex, expensive integrations**: Every new data source, tool, or AI agent means more custom connectors, patches, and technical debt.
- **Stunted automation and insight**: When assistants lack rich, real-time access to infrastructure, their utility is massively limited.

## The Solution: AKS-MCP's Open, Secure Protocol

AKS-MCP answers this challenge as a universal, protocol-first bridge between AI agents and AKS. Built on the open Model Context Protocol (MCP), it delivers:

- **One protocol, limitless context**: Replace dozens of brittle integrations with a secure, standard interface—making all your Kubernetes data, events, and actions available to any AI assistant.
- **Plug-and-play AI agent support**: Works out of the box with Claude, Cursor, GitHub Copilot, and more—so you can use the assistants you already love.
- **Secure by default**: Leverage Azure authentication and granular RBAC to keep operations and data safe.
- **Extensible and community-driven**: Fully open source, so you can adapt, extend, and evolve the platform for new tools and future needs.

## Core Capabilities at a Glance

The AKS MCP server supports a number of tools that surface capabilities to interact with Kubernetes and Azure APIs.
It provides several observability telemetries to aid users with diagnosing health issues in their environments.
Currently, AKS MCP server supports the following tools:

- **Kubectl commands using the Kubernetes API**: Read and write commands such as `get`, `describe`, `logs`, `exec`, `apply`, `delete` etc.
- **Azure CLI AKS commands for interacting with Azure APIs**: `show`, `list`, `get-credentials`, nodepool operations, `check-network`
- **Other Azure resource commands attached to AKS clusters**: Basic, read-only Azure Compute, Networking, Kubernetes Fleet Manager commands
- **Azure Monitor API commands for retrieving monitoring data**: Pull activity logs, audit logs, metrics, alerts
- **Other Diagnostic information**: Diagnose and solve detectors, Azure Advisor, [Inspektor Gadget](https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/logs/capture-system-insights-from-aks?tabs=azurelinux30) for real time troubleshooting 

For a full list of tools and capabilities please see - [Available tools](https://github.com/Azure/aks-mcp#available-tools).

## Getting Started with AKS MCP

### Option A: VS Code Extension (Recommended)

To make it easy for AKS users to leverage the new AKS-MCP server, we have integrated it with AKS VS Code Extension starting with version 1.6.12.

1. Install the AKS Extension from the VS Code Marketplace.
2. Run **AKS: Setup AKS MCP Server** from the command palette (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
3. The extension auto installs the binary based on the platform, configures the MCP server and updates your VS Code `mcp.json` file.
4. Instantly start using GitHub Copilot or your favorite AI agent with first-class access to AKS tools.

This one-click setup brings AI-powered Kubernetes operations to every developer's fingertips.

![aksmcp-github](/assets/images/aks-mcp/aks-mcp-vscode.png)

### Option B: Download Binaries/container image from Github

You can download the correct binaries from the [AKS-MCP GitHub releases page](https://github.com/Azure/aks-mcp),
and then manually configure the mcp server in VSCode or the IDE/agent of your choice.
Find information on [how to get install and get started](https://github.com/Azure/aks-mcp#how-to-install).

## Real-World Example Use Cases

AKS-MCP enables intelligent, agent-driven cloud operations. Here are a few hands-on scenarios that you can try in GitHub Copilot, Claude Code or other mcp compatible agents:

### Diagnose Resource Health

**Prompt**: *"Why is one of my AKS nodes in NotReady state?"*

### Understand Network Security

**Prompt**: *"Can you help me understand my AKS cluster's VNet and NSG configuration? I think DNS traffic is being blocked."*

### Automate Operations

**Prompt**: *"Scale my payments-api deployment to 5 replicas and confirm rollout status."*

The result? AI agents that can reason, act, and surface Azure-specific insights—accelerating DevOps and cloud troubleshooting.

## Why Open Source and Protocol-First?

By architecting AKS-MCP as an open, extensible protocol server, we invite you—the community—to:

- Seamlessly integrate into your unique AI automation workflows
- Support new tools, capabilities and agent integrations as the tech evolves
- Help define the future of human-AI collaboration for Kubernetes operations

This approach aligns with AKS's commitment to open development, contribution to the community, and cloud-native flexibility for users of all sizes.

## Get Involved

Visit [Azure/aks-mcp](https://github.com/Azure/aks-mcp) on GitHub and be part of the movement to advance AI + AKS together. We're looking for feedback, contributions, and innovative feature ideas.

Let's take the next step in cloud-native DevOps—where Kubernetes, AI, and open protocols empower every developer.
