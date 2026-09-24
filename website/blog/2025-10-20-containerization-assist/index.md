---
title: "Containerization Assist: AI-Driven Artifact Generation for Kubernetes "
date: "2025-10-20"
description: "Introducing Containerization Assist, a new MCP server designed for containers and kubernetes manifests."
authors: ["quentin-petraroia", "kenneth-kilty"]
tags:
  - ai
  - mcp
  - kubernetes
  - containers
  - developer
  - open-source
---

### Introducing Containerization Assist: AI-Driven Artifact Generation for Kubernetes

AI has quickly become an integral part of the modern developer's workflow. Whether it’s GitHub Copilot, MCPs, or other emerging tools, AI is now central to how developers build, test, and ship software. Inspired by the productivity gains AI enables, the AKS DevX team began exploring how it could simplify and accelerate the creation of Kubernetes deployment artifacts. In AKS, we’ve consistently seen how challenging it can be for customers to containerize legacy applications and move them onto Kubernetes. The process is rarely straightforward, often requiring more time and effort than it ideally should.

<!-- truncate -->

It doesn’t take long in a cloud-native journey to realize that containerizing an application requires much more than just executing a single command. It involves a deep understanding of your app’s dependencies, writing secure and optimized Dockerfiles, producing the right Kubernetes manifests, and deploying everything reliably. Each of these steps can introduce its own set of challenges, from dependency mismatches to subtle configuration issues that slow you down and distract you from building features that matter. 

That’s why today we’re introducing Containerization Assist, an AI-powered MCP server designed to simplify the process of containerizing your applications. Without requiring deep Docker expertise, Containerization Assist guides you step by step through creating Dockerfiles and Kubernetes deployment manifests, all from within your development environment using natural language. Best of all, no matter your stack, whether you're using GitHub Copilot, Cursor, Claude Code, or another tool, Containerization Assist works seamlessly wherever MCP servers are supported.

## So how does it work?

What makes Containerization Assist truly powerful is its knowledge-enhanced architecture. At its core sits a comprehensive knowledge base that we've built up with language-specific optimizations, security hardening patterns, performance techniques, and cloud provider best practices. Instead of relying on generic templates, the system matches your specific application characteristics against curated knowledge entries that contain patterns, recommendations, and contextual tags.

Here's how it works behind the scenes: When you run a tool, it follows a consistent five-phase process. First, it analyzes your repository structure by understanding modern architectures, detecting monorepo setups, and distinguishing between deployable services and shared libraries. The knowledge matching engine then scores and ranks the most relevant best practices using pattern matching and semantic similarity. These recommendations get organized into security, optimization, and compliance categories before the system applies business logic based on what it detected. Finally, you get structured output with base image recommendations, security enhancements, optimization techniques, and confidence scores.

This approach gives you some serious advantages. Because the knowledge queries use deterministic matching algorithms, the same repository analysis will always produce identical plans, which is perfect for reliable CI/CD integration. The tools execute in under 150ms because they avoid AI inference during execution. Most importantly, we've separated knowledge retrieval from content generation, which means AI clients can adapt plans to your specific preferences while still following best practices and organizational policies.

![Containerization Assist Flow](containerization-assist-flow.png)
_Figure 1: The workflow of the containerization assist MCP server._ 

## Going beyond basic file detection

Most traditional containerization tools do basic file detection. They look for `package.json` or `pom.xml` files and call it a day. Containerization Assist uses sophisticated analysis that actually understands modern application architectures. It automatically identifies independently deployable services in complex monorepo structures by analyzing workspace configurations, separate build files, and independent entry points while intelligently excluding shared libraries and utility folders. 

When you're working with a typical enterprise monorepo, the system can distinguish between an API gateway service running Spring Boot with PostgreSQL dependencies and a user service running Quarkus with MongoDB drivers, then generate appropriate containerization strategies for each.

Our tool ecosystem provides 13 specialized capabilities that cover the complete containerization lifecycle. You get analysis tools for repository structure and dependency detection, plus knowledge-enhanced planning for both Dockerfiles and Kubernetes manifests. Container operations include building with integrated security analysis, vulnerability scanning with AI-powered remediation guidance using Trivy, and intelligent tagging strategies for registry management. For deployment, we handle Kubernetes cluster preparation, application deployment with rollout validation, and comprehensive health verification. Quality assurance tools provide policy compliance validation and intelligent remediation suggestions for existing artifacts.

By providing prioritized and composable implementations for Java Spring Boot multi-stage builds, .NET minimal APIs, Node.js Alpine optimizations, security hardening with distroless images and non-root users, performance techniques for build optimization and layer caching, and deep cloud provider integration patterns. Each entry includes implementation examples, severity classifications, and contextual tags that enable precise matching against your detected application characteristics.

## What makes this different from other tools?

We've built an MCP that's fundamentally different from existing containerization approaches. Instead of relying on static templates that someone has to manually maintain, or direct AI generators that give you different results every time, our tools return structured data that your AI client can consume to generate artifacts. This means you get the consistency you need for production while still having the flexibility to adapt things to your specific requirements.

This has resulted in a more seamless experience that fits naturally into how developers are actually using AI tools in 2025. Every operation logs clear "Starting" and "Completed" messages that your AI assistant can interpret, summarize, and build upon in conversation. We've built in Docker and Kubernetes integration, vulnerability scanning powered by Trivy, and intelligent tool routing that automatically handles dependencies. You can start creating production-ready containers today without becoming a containerization expert overnight.

## Get started

Visit https://aka.ms/aks/containerization-assist to get started today!

![Containerization Assist Gif](ca-demo-fullscreen.gif)
_Figure 2: A gif showcasing Containerization Assist._ 
