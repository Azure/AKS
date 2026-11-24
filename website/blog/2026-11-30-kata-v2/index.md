---
title: "How to run agents on AKS with pod sandboxing using Kata v2 (part I)"
date: 2026-11-30
description: "Explore Kata v2 pod sandboxing on AKS for AI agents, with lower memory overhead, faster sandbox startup, and extensions to manage and resume agent sessions."
authors: [flora-taagen]
tags: [agent, ai, security, performance, azure-linux]
draft: true
---

Building an AI assistant that can carry out tasks means thinking beyond model inference. When an agent writes and executes code, the execution environment becomes part of both the application's security model and the user experience.

Consider a hosted coding agent investigating a failing test. The service creates an isolated workspace where the agent can check out code, run tests, and propose a fix. Creating that workspace consumes time and memory, and as usage scales those costs directly affect responsiveness and cluster efficiency.

As we evolve pod sandboxing on Azure Kubernetes Service (AKS), we're looking closely at what it takes to make those workspaces isolated, efficient, and ready to use. Whether a service keeps workspaces running across multiple tasks or creates them on demand, sandbox startup time and resource consumption have a direct impact on the user experience.

<!-- truncate -->

This is the problem motivating our work on the Kata v2 runtime. We want less time and compute spent preparing sandboxes and more spent running applications, while preserving the VM-backed isolation that's increasingly important as AI agents execute potentially untrusted code.

## Keeping the isolation boundary, reducing the overhead

Pod sandboxing on AKS uses Kata Containers to run each sandboxed pod in a lightweight microVM with its own guest kernel. Applications continue to use familiar Kubernetes deployment workflows, but the workload runs with a kernel that is isolated from both the host and other sandboxed pods.

Creating that isolated environment takes time and resources. Before a coding agent can execute generated code or run tests in its workspace, the host-side runtime must prepare the VM, boot the guest kernel, and initialize the Kata agent that manages containers inside the guest.

These costs fall into two categories: initialization work performed whenever a new sandbox is created, and resource overhead that persists throughout the sandbox lifecycle. Kata v2 improves both areas. New sandboxes can be created more quickly by starting from a preinitialized template instead of performing a full VM boot sequence, while a leaner runtime reduces the resources consumed by running sandboxes.

The runtime improvements build on the upstream Rust implementation. The new Rust-based runtime and deferred paging deliver 29% lower pod memory usage compared to the previous Golang implementation, leaving more node memory available for applications.

Configured RuntimeClass memory overhead also drops from 600Mi to 32Mi. Kubernetes uses this setting to account for the resource overhead of the Kata VM and associated runtime components during scheduling. A smaller overhead allowance makes more cluster capacity available to workloads.

For agent platforms and hosted coding services, lower sandbox overhead means more node memory available for build tools, dependencies, test execution, and higher session density per node.

## Faster sandbox startup with Kata v2

Reducing steady-state overhead is only part of the equation. For services that frequently create new sandboxes, startup latency matters just as much.

Consider another developer submitting a task. Their coding session requires a separate workspace, but much of the guest initialization is identical to the workspace before it: booting the kernel, bringing up the Kata agent, and preparing the environment to run containers.

Kata v2 lets us prepare an empty guest once and use that baseline to create separate sandbox instances. Each workspace gets its own isolated VM without repeating the full guest boot path:

```text
Cold start:   Boot guest -> Initialize Kata agent -> Start application -> Ready
Template:     Restore prepared guest              -> Start application -> Ready
```

In our measurements, creating a sandbox from a preinitialized VM template delivered up to 42% lower startup latency compared to a standard Kata VM launch. For agentic workloads that create workspaces on demand, that translates directly into less time spent preparing the execution environment before work can begin. To create a template and use it for new sandboxed pods, follow the setup guide.

This process prepares the guest environment, not the application itself. In our example, the workspace still requires repository checkout, dependency installation, and initialization of build and test tooling. Resuming a previously initialized coding session requires preserving and restoring application state. This is where the Agent Sandbox and Pod snapshot cluster extensions come in.

## Using Kata v2 runtime in the Agent Sandbox cluster extension and Pod snapshot cluster extension

The Agent Sandbox cluster extension, based on the open-source agent-sandbox project, manages AI agent execution environments through a declarative Sandbox resource. You describe the container image, runtime, and resource requirements, and the extension controller creates and manages the sandbox pod. The Pod snapshot cluster extension captures the runtime state of a sandboxed pod and stores it in Azure Blob storage. A new pod can then restore that state and resume processes quickly. For example, AI agents can resume a session with its in-memory context intact; an application with a costly initialization can start from a snapshotted warm state instead of cold-starting.

Both extensions support the Kata v2 runtime. The Agent Sandbox cluster extension runs each Sandbox with the Kata v2 runtime, so every agent gets its own VM-isolated pod. The Pod snapshot cluster extension captures and restores the state of those Kata v2 pods. Together, they combine VM-backed isolation with fast, memory-intact resumes.

## Looking forward

While Kata v2 improves memory efficiency and startup latency today, we're continuing to invest in the performance of sandboxed workloads.

One area of focus is Azure Disk integration with virtio-blk, which provides sandboxed workloads with a more direct storage path. We expect this to reduce I/O overhead and improve performance for operations such as reading source files, restoring dependencies, and writing build artifacts on Azure Disk volumes.

## Try the Kata v2 runtime (public preview)

To get started, follow the Kata v2 preview setup and migration guidance. Begin with a representative workload to validate storage, resource allocation, and runtime compatibility before expanding adoption across your environment.

We're actively evolving pod sandboxing in AKS and welcome feedback from early adopters. Your experience with the Kata v2 preview will help shape future investments in workload isolation, performance, and support for agentic workloads.

Stay tuned for the next posts in our Agents on AKS series, where we’ll build on this foundation with agent sandbox management, pod snapshot and restore, and the infrastructure and tooling for running agent sessions on AKS.
