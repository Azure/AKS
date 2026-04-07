---
title: "Turn your agents into AKS experts: Agent Skills for AKS"
date: 2026-03-26
description: "Announcing agent skills for AKS, easily pluggable into any agent to enhance them with built-in AKS expertise, safer workflows, and reduced developer overhead."
authors: [julia-yin]
tags: [agent, skills, mcp, developer]
draft: false
---

**Agent skills for Azure Kubernetes Service (AKS)** bring production-grade AKS guidance, troubleshooting checklists, and guardrails directly into any compatible AI agent. The first set of skills are now available through the **GitHub Copilot for Azure** extension, with support for VS Code, Visual Studio, Copilot CLI, and Claude.

While AI agents already carry a good baseline of Kubernetes and AKS knowledge, that knowledge is only as current as their training data and varies across models. Skills enhance agents with prescriptive, up-to-date guidance on the tools and processes our AKS engineers use today to make the right AKS decisions across cluster creation, operations, and issue resolution.

<!-- truncate -->

![Diagram showing artistic rendition of the components](./hero-image.png)

## What are agent skills?

Agent skills are an open standard pioneered by Anthropic for enhancing AI agents with domain-specific expertise in a token-efficient way. You install a skill once, and any compatible agent (such as GitHub Copilot, Claude, Gemini, or others) picks it up automatically for relevant prompts. They provide essential expertise to your agents while staying context efficient, as each skill loads only when your prompt is relevant to the skill's content:

- If you're not asking about AKS, the skill **stays out of the way** and doesn't add to your token usage.
- When you do ask an AKS-related question, the skill **activates automatically** and brings in the right guidance, commands, and context.

## Available skills

The first release includes the following skills:

1. A high-level [**AKS best practices** skill](https://github.com/microsoft/GitHub-Copilot-for-Azure/blob/main/plugin/skills/azure-kubernetes/SKILL.md)
1. Sub-skills for [**AKS troubleshooting**](https://github.com/microsoft/GitHub-Copilot-for-Azure/tree/main/plugin/skills/azure-diagnostics/aks-troubleshooting)

The **AKS best practices** skill guides agents through cluster configuration recommendations across networking, upgrade strategy, security, reliability, scale, and more. The guidance reflects what the AKS engineering team recommends for production clusters for optimal performance and uptime, along with specific defaults and critical decisions that apply to AKS. After installing the skill, try the following commands to invoke the skill and receive targeted recommendations for your AKS cluster:

- "What are the best practice recommendations for a highly reliable and performant AKS cluster?"
- "Help me determine the Day-0 decisions I need to make when creating a new AKS cluster."
- "What networking setup is best for my AKS cluster?"

**AKS troubleshooting** covers the most common incident scenarios: node health failures and networking issues. It includes the exact CLI commands and diagnostic sequences that AKS engineers use internally when working customer incidents. Commands are permission-gated: the skill only suggests and executes commands that your current credentials allow, so there's no risk of unintentional changes. Here's what a typical troubleshooting session looks like in VS Code with the skill active:

```text
User: What are the best practices for deploying a secure, reliable, and cost-efficient AKS cluster?

Copilot: I’ll pull AKS-specific best-practice guidance first so I can give you a concise, production-ready checklist for security, reliability, and cost.

Action: Read skill `azure-kubernetes`

For AKS, the best results come from making strong Day-0 choices, then layering autoscaling, policy, and operational guardrails.
```

## How to get started

You have two options: install individual skills directly, or get the full bundle through the GitHub Copilot for Azure plugin.

### Option 1: Install through GitHub Copilot for Azure plugin

The GitHub Copilot for Azure plugin is available through VS Code, Claude, and Copilot CLI and bundles AKS skills alongside 20+ skills across cost optimization, other Azure resources, and deployment workflows. Learn more about [GitHub Copilot for Azure](https://learn.microsoft.com/azure/developer/github-copilot-azure/introduction?tabs=vscode), and get the extension:

**Install the Azure extension for VS Code:**

1. Open VS Code and go to the Extensions marketplace (`Ctrl+Shift+X` / `Cmd+Shift+X`).
1. Search for **GitHub Copilot for Azure** and select **Install**. ([Direct link to the marketplace](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azure-github-copilot))
1. Open GitHub Copilot Chat in VS Code (the chat icon in the sidebar or `Ctrl+Alt+I` / `Cmd+Alt+I`).
1. Run a prompt that references AKS, such as *"What's the recommended upgrade strategy for my AKS cluster?"* or *"What are the best practices for AKS clusters?"*. The AKS skill will install and load automatically.

> **Note**: If skills don't activate after installing the extension, open the VS Code Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and run **GitHub Copilot for Azure: Refresh Skills**. Alternatively, running any AKS-related prompt will trigger the extension to initialize and load available skills.

**Install the Azure plugin to Claude or Copilot CLI:**

1. Add the marketplace with `/plugin marketplace add microsoft/azure-skills`
1. Install the plugin with `/plugin install azure@azure-skills`
1. Update the plugin with `/plugin update azure@azure-skills`
1. Verify that the azure-kubernetes skill has successfully installed with `/skills`
1. Run a prompt that references AKS, which will invoke the relevant skill.

### Option 2: Install AKS skills directly

1. Go to [skills.sh](https://skills.sh/microsoft/github-copilot-for-azure) and locate the AKS skills: [azure-kubernetes](https://skills.sh/microsoft/github-copilot-for-azure/azure-kubernetes) and [azure-diagnostics](https://skills.sh/microsoft/github-copilot-for-azure/azure-diagnostics).
1. Follow the `npx skills add` command at the top of the page to install the skill directly.
1. Run any AKS-related prompt such as *"Review my cluster for best practices"*, and the skill will activate automatically.

## AI-powered capabilities for AKS

AKS now has several AI-powered experiences: skills, the [AKS MCP server](/2025/08/06/aks-mcp-server), and the [agentic CLI for AKS](https://aka.ms/aks/agentic-cli). Understanding the differences helps you choose the right combination for your workflow.

The **[AKS MCP server](/2025/08/06/aks-mcp-server)** is a tool layer that pairs directly with skills. Where skills tell the agent *what* to do, the MCP server gives it the ability to *act*: securely access your cluster details, run scoped diagnostic commands, and interact with Kubernetes and Azure APIs. Without the AKS MCP server, agents fall back to running direct CLI commands, which lack the structured, permission-aware interface the MCP server provides.

Skills enhance the base knowledge of any agent, including the **[agentic CLI for AKS](https://aka.ms/aks/agentic-cli)** (`az aks agent`). We're working on built-in support for all AKS skills in the agentic CLI, making it the right choice when you want a purpose-built terminal experience without assembling the individual pieces across tooling and AKS expertise yourself.

The three layers are designed to complement each other:

| Capability | Role | Requires cluster | Best for |
|:---|:---|:---|:---|
| AKS skills | Knowledge | No | Wide range of scenarios from cluster configuration to troubleshooting/operations |
| AKS MCP server | Tools | Yes | Live diagnostics, cluster state, Azure and Kubernetes API access |
| Agentic CLI for AKS | End-to-end experience | Yes | AI-powered cluster operations and workflows |

## Conclusion

AKS skills give your agents a baseline of production AKS knowledge using the same guidance, commands, and diagnostic approaches that AKS engineers use. The first release covers best practices and troubleshooting, and we're planning to cover more scenarios based on customer feedback. If you run into issues or have scenarios you'd like to see covered, open an issue on the [AKS repository](https://github.com/Azure/AKS/issues).

## Resources

- Link to the [azure-kubernetes skill](https://github.com/microsoft/GitHub-Copilot-for-Azure/blob/main/plugin/skills/azure-kubernetes/SKILL.md)
- Link to the [azure-diagnostics skill](https://github.com/microsoft/GitHub-Copilot-for-Azure/blob/main/plugin/skills/azure-diagnostics/SKILL.md)
- Find all skills in the [Microsoft/skills repo](https://github.com/microsoft/skills/tree/main/.github/plugins/azure-skills)
