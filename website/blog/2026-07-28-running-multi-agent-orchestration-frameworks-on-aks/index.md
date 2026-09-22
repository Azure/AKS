---
title: "Running Multi-Agent Orchestration Frameworks on AKS"
date: 2026-07-28
description: "Learn deployment, scaling, networking, state, security, and cost patterns for running multi-agent AI orchestration frameworks on Azure Kubernetes Service."
authors: [brian-redmond]
tags: [ai, agent, scaling, best-practices]
draft: false
---

Multi-agent AI systems are moving fast from experimental notebooks into production services. Instead of a single model call, these systems coordinate several specialized agents—planners, researchers, coders, critics—that collaborate to complete a task. That shift changes the infrastructure problem: you're no longer serving one stateless model endpoint, you're operating a distributed system with its own scaling, networking, state, and security requirements. Kubernetes, and Azure Kubernetes Service (AKS) in particular, is a natural home for that kind of workload.

<!-- truncate -->

This post walks through the patterns that matter most when running a multi-agent orchestration framework on AKS: how to deploy, scale, network, secure, and pay for the system.

## What multi-agent orchestration looks like in practice

Frameworks in this space—open-source projects such as AutoGen, CrewAI, LangGraph, and the agent features in Semantic Kernel are common examples—differ in how they model coordination, but most fall into one of three shapes: **hub-and-spoke**, where a central planner decomposes a task and delegates to worker agents; **graph or state machine**, where agents are nodes with conditional edges determining execution order; and **group chat**, where any agent can address any other over a shared message bus or transcript.

Whichever pattern a framework uses, the operational concerns on Kubernetes are largely the same: each agent role does its own reasoning (an LLM call plus tools and memory), and the system as a whole needs to schedule, scale, and secure those roles independently.

## Deployment patterns on AKS

For small agent teams, running everything as a single process—with all agents living as in-memory objects in one deployment—is the simplest starting point. It doesn't scale each role independently, but it's easy to reason about and deploy.

As systems grow or run continuously in production, a few patterns pay off:

- **Give each agent role its own Deployment.** Planner, researcher, coder, and critic can then scale, version, and release independently, so a bug in one agent doesn't force a redeploy of the whole system.
- **Put the orchestrator behind its own Service** so it can restart or scale separately from the workers it delegates to. This is also the natural place to add authentication, rate limiting, and centralized observability.
- **Model one-shot tasks as a Kubernetes `Job`.** For on-demand work—"research this ticket and draft a summary"—a Job gives cleaner completion and retry semantics than a long-lived Deployment.
- **Isolate risky tool execution in its own sidecar container.** Any agent that runs generated code, shell commands, or browser automation should sit in a container with a tighter security context than the reasoning container that calls the LLM.

## Scaling agent workloads

Agent workloads tend to be bursty and latency-sensitive—waiting on LLM API round trips—rather than CPU-bound. That means classic CPU-based Horizontal Pod Autoscaler (HPA) targets often under- or over-provision agent pools.

A few adjustments help:

- **Scale on request or queue depth, not CPU**, using **KEDA** (Kubernetes Event-driven Autoscaling), available as an AKS add-on.
- **Front bursty fan-out with a message queue.** When an orchestrator dispatches many parallel sub-agent calls, put a queue in front of the worker pool and use KEDA's queue-length scaler so workers scale to zero when idle and burst up under load.
- **Separate GPU and CPU-only agents into different node pools**, using taints and tolerations so GPU capacity isn't wasted on orchestration-only pods.
- **Let the cluster autoscaler handle node-level scaling.** The cluster autoscaler (or AKS Automatic's managed node pools) should respond to pod-level HPA/KEDA decisions rather than you managing node count manually.

## Networking and service mesh considerations

Agents typically talk to each other over HTTP, gRPC, or a message bus, and they also call out to external services—LLM APIs, search APIs, and other tools. Both directions deserve attention.

For agent-to-agent traffic, a service mesh such as Istio on AKS adds mutual TLS between agent services, fine-grained traffic policies (for example, canarying a new planner version), and mesh-level retries and circuit breaking—useful given how often LLM-backed calls are slow or flaky. Keep this traffic on the cluster network using ClusterIP Services rather than round-tripping through public endpoints; it reduces both latency and attack surface.

For egress, control matters more here than in typical microservices architectures, because agents frequently call third-party LLM and tool APIs. Use network policies or an egress gateway to allow-list only the destinations agents are permitted to reach, and centralize authentication and token injection there instead of embedding long-lived API keys in every agent pod. A dedicated AI or LLM gateway—a single ingress/egress layer for model traffic—centralizes provider abstraction, rate limiting, cost tracking, and logging instead of scattering that logic across every agent.

## State and persistence

Multi-agent frameworks maintain conversation and task state: message history, scratchpad memory, and intermediate results. Two broad patterns cover most cases.

**Stateless agent pods with externalized state** are easier to operate: agent pods hold no session state in memory, and state lives in an external store—Redis for short-lived working memory, a database or vector store for longer-term memory and embeddings. Any pod replica can then handle any request, and rolling restarts or scaling events are safe.

**Stateful agent processes** are sometimes unavoidable, particularly for frameworks that keep an in-memory graph or session per task run. If that state can't be cheaply externalized, use a StatefulSet with stable pod identity and a PersistentVolumeClaim, paired with a PodDisruptionBudget to protect in-flight runs during node maintenance.

Graph or state-machine frameworks often support checkpointing so a long multi-step run can resume after a crash—persist those checkpoints to durable storage, such as a managed database or blob storage, rather than local disk. Run vector stores and other memory backends as their own scalable service rather than embedding them per agent pod, so memory stays shared and consistent across replicas.

## Security considerations

Multi-agent systems widen the attack surface compared to a single model endpoint, since more components can call tools, execute code, and pull in external content. A few practices reduce that risk:

- **Assign distinct managed identities per agent role** using AKS workload identity, so a compromised tool-executing agent doesn't inherit the planner's permissions.
- **Sandbox any agent that executes generated code or shell commands.** Give it a restrictive security context, a read-only root filesystem, dropped capabilities, and ideally stronger isolation such as gVisor or confidential containers—never run it in the same container as the reasoning logic.
- **Store API keys and credentials in a secret store**, such as Azure Key Vault via the CSI Secret Store driver, rather than baking them into images or environment variables.
- **Defend against prompt injection.** Because agents often chain untrusted external content back into further LLM calls, validate tool outputs, constrain which agents can trigger which tools, and log full execution traces for auditability.

The egress allow-lists from the networking section double as a security control here, not just a cost control.

## Cost considerations

For most multi-agent systems, LLM API calls—metered by token—are the dominant cost, not compute. But inefficient orchestration multiplies that spend: unnecessary retries, redundant agent-to-agent round trips, and missing caches all add up quickly. Add response caching and deduplication at the orchestrator layer before you optimize anything else.

On the infrastructure side, a few AKS-native levers help:

- **Scale idle worker pools to zero** using KEDA so you're not paying for replicas between bursts of activity.
- **Use spot node pools for stateless, retryable workers** where interruption is tolerable, reserving on-demand or reserved capacity for the orchestrator and any stateful components.
- **Right-size resource requests and limits per agent role**, since reasoning-only agents are usually memory- and network-bound rather than CPU-bound.
- **Centralize external API calls through a gateway** to get per-agent, per-task cost attribution that's difficult to reconstruct from scattered direct calls.

## Conclusion

Running a multi-agent orchestration framework on AKS is less about the AI framework itself and more about applying proven Kubernetes patterns to a new kind of workload: independently scalable services per agent role, event-driven autoscaling instead of CPU-based HPA, careful egress control for external calls, externalized state where possible, least-privilege identity per role, and cost visibility into where tokens and compute go.

None of these patterns are exotic—AKS features like KEDA, workload identity, network policies, and the Key Vault CSI driver already support them. The work is applying them deliberately to a system built from many small, cooperating agents rather than one large service. Get those fundamentals in place, and the orchestration framework becomes an implementation detail your platform can support well.

