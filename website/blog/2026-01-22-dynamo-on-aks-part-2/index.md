---
title: "Scaling multi-node LLM inference with NVIDIA Dynamo and NVIDIA GPUs on AKS (Part 2)"
date: 2026-01-22
description: "Learn how to scale multi-node LLM inference on Kubernetes using NVIDIA Dynamo, H100 GPUs, and Dynamo Planner tools to optimize throughput and latency."
authors:
- sachi-desai
- sertac-ozercan
tags: ["dynamo-series", "ai", "performance", "open-source"]
---

*This blog post is co-authored with
[Saurabh Aggarwal](https://www.linkedin.com/in/sa126/),
[Anish Maddipoti](https://www.linkedin.com/in/anish-maddipoti/),
[Amr Elmeleegy](https://www.linkedin.com/in/meleegy/), and
[Rohan Varma](https://www.linkedin.com/in/rohan-s-varma/) from NVIDIA.*

In our [previous post](https://blog.aks.azure.com/2025/10/24/dynamo-on-aks),
we demonstrated the power of the Azure ND GB200-v6 VMs accelerated by
NVIDIA GB200 NVL72, achieving a
staggering **1.2M tokens per second** across 10 nodes using NVIDIA Dynamo.
Today, we shift focus from raw throughput to **developer velocity** and
**operational efficiency**.

We will explore how the
[**Dynamo Planner**](https://github.com/ai-dynamo/dynamo/blob/main/docs/planner/sla_planner.md)
and
[**Dynamo Profiler**](https://github.com/ai-dynamo/dynamo/tree/main/benchmarks/profiler)
remove the guesswork from performance tuning on Azure Kubernetes Service (AKS).

<!-- truncate -->

## The Challenge: Balancing the "Rate Matching" Equation

Disaggregated serving separates the prefill phase (when the model first
processes the entire input sequence at once) and decode phase (when the
model starts sequentially generating output tokens) of inference
across distinct GPU nodes. This allows each phase to be independently
optimized with custom GPU counts and model parallelism configurations.

![Disaggregated serving with Dynamo](./dynamo_inference_diagram.jpg)

One of the main challenges in disaggregated serving is **rate matching**:
determining the right GPU allocation between prefill and decode stages to
meet a specific Service Level Objective (SLO). If you miscalculate the GPU
ratio between these stages, you face two "silent killers" of performance:

* **Over-provisioned Prefill**: Your prompt processing is fast, but
requests bottleneck at the generation stage. This spikes *Inter-Token
Latency (ITL)* and leaves expensive compute nodes idle.
* **Under-provisioned Prefill**: Your decode GPUs sit starved for data.
This drives up *Time-To-First-Token (TTFT)* and inflates your
*Total Cost of Ownership (TCO)*.

Beyond rate matching, developers must also optimize model parallelism
parameters (data, tensor, and expert parallelism) to maintain high
["Goodput"](https://arxiv.org/abs/2401.09670) (the fraction of time
and resources where the model is learning or producing correct results,
instead of waiting or doing extra work).

Exploring these configurations manually is technically challenging,
time-consuming and often results in suboptimal resource utilization.

## Dynamic Traffic: The Move to SLO-Driven Scaling

Static configurations are brittle. In production, traffic is rarely uniform:

* **Volatile Request Volume**: Traditional Horizontal Pod Autoscalers (HPA)
are too slow for LLM jitters.
* **Shifting Sequence Patterns**: If your workload shifts from short chat
queries (low input sequence length (ISL)) to long-context document analysis (high ISL), a static
disaggregated split becomes suboptimal instantly (resulting in overworked
prefill GPUs and idle decode GPUs).

NVIDIA Dynamo addresses these gaps through two integrated components:
the **Planner Profiler** and the **SLO-based Planner**.

---

### Let’s see it through an example application scenario

Consider a mission-critical AI workload running on AKS: an airline’s
automated rerouting system during a widespread delay This use case is a
'stress test' for
inference: it is subject to massive, sudden bursts in traffic and highly
variable request patterns, such as a mix of short status queries and
long-context itinerary processing. To prevent latency spikes during these
peaks, the underlying system requires the precise orchestration offered
by a disaggregated architecture.

Using the
[Qwen3-32B-FP8](https://huggingface.co/Qwen/Qwen3-32B-FP8)
model, we can deploy an Airline Assistant with
strict SLA targets: TTFT ≤ 500ms and ITL (Inter-Token Latency) ≤ 30ms.

During normal operations, passengers ask short queries like
"What's my flight status?" But when a major weather system causes
flight cancellations, passengers flood the app with complex rerouting
requests—long-context queries (~4,000 tokens) requiring detailed itinerary
responses (~500 tokens). This sudden surge of 200 concurrent users is
exactly the kind of real-world spike that breaks static configurations.

To build a truly efficient disaggregated AI inference system, you
need to transition from manual "guess-and-check" configurations
to an automated, SLO-driven approach. The core of this automation
lies in two distinct but deeply integrated components: the Dynamo
Planner profiler and the Dynamo Planner.

The first step in building your system is determining the "Golden Ratio"
of GPUs: how many should handle prefill versus decode, and what tensor
parallelism (TP) levels each should use.

### The Architect: Dynamo Profiler

The Dynamo Planner profiler is your pre-deployment simulation engine.
Instead of burning GPU hours testing every possible configuration, you
define your requirements in a **DynamoGraphDeploymentRequest (DGDR)**
manifest. The profiler then executes an automated
["sweep"](https://github.com/ai-dynamo/dynamo/blob/main/docs/benchmarks/sla_driven_profiling.md#profiling-method)
of the search space:

* **Parallelization Mapping**: It tests different TP sizes for both prefill
and decode stages to find the lowest TTFT and ITL.
* **Hardware Simulation**: Using the **AI Configurator (AIC)** mode, the
profiler can simulate performance in just 20–30 seconds
based on pre-measured performance data, allowing for rapid
iteration before you ever touch a physical GPU.
* **Resulting Recommendation**: The output is a highly tuned
configuration that maximizes ["Goodput"](https://arxiv.org/abs/2401.09670),
the maximum throughput
achievable while staying strictly within your latency bounds.

Ultimately, the app developers and AI engineers reduce their time
spent on testing different system setups, and can focus on their airline
passengers’ needs.

### The Pilot: Dynamo Planner

Once your system is deployed, static configurations can't handle the
"jitter" of real-world traffic. This is where the Dynamo Planner takes
over as a runtime orchestration engine.

Unlike a traditional load balancer, the Dynamo Planner is **LLM-aware**.
It continuously monitors the live state of your cluster, specifically
looking at:

* **KV Cache Load**: It monitors memory utilization in the decode pool.
* **Prefill Queue Depth**: It tracks how many prompts are waiting to be
processed.

Using the performance bounds identified earlier by the profiler
(i.e. TTFT ≤ 500ms and ITL ≤ 30ms) the Planner
proactively scales the number of prefill and decode workers up or down. For
example, if a *sudden burst of long-context itinerary queries* floods the
system, the Planner detects the spike in the prefill queue and shifts available
GPU resources to the prefill pool *before* your TTFT violates its SLO.

## Seeing it in Action

In our airline scenario, the system starts with 1 prefill worker and
1 decode worker. When the passenger surge hits, the Planner's 60-second
adjustment interval detects the SLA violations:

```bash
Prefill calculation: 138.55 (p_thpt) / 4838.61 (p_engine_cap) = 1 (num_p)
Decode calculation: 27.27 (d_thpt) / 19381.08 (d_engine_cap) = 1 (num_d)
```

As traffic spikes to 200 concurrent passengers, the Planner recalculates:

```bash
Prefill calculation: 16177.75 (p_thpt) / 8578.39 (p_engine_cap) = 2 (num_p)
Decode calculation: 400.00 (d_thpt) / 3354.30 (d_engine_cap) = 1 (num_d)
Predicted number of engine replicas: prefill=2, decode=1
Updating prefill component VllmPrefillWorker to desired replica count 2
```

[See the Dynamo SLA Planner](https://asciinema.org/a/67XW4yXJIBmIe7bv)
in action as it automatically scales the Airline Assistant during a
traffic surge. The Planner automatically scales to 2 prefill workers
while keeping 1 decode worker (the optimal configuration to handle the
surge while maintaining SLA targets). Within minutes, the new worker is
online and passengers are getting their rerouting options without
frustrating delays.

Now, you can try this yourself by running the NVIDIA Dynamo Planner Profiler
to capture burst and request behavior, then using the SLO-based Planner to
translate latency targets into placement and scaling decisions on your AKS
cluster. Setting it up in this order - profile under stress, define SLOs,
and let the planner orchestrate your disaggregated inference system to
handle sudden traffic spikes without latency spikes.

After deploying Dynamo by following [these instructions](https://aka.ms/aks-dynamo),
get hands on with the
[Qwen3-32B-FP8](https://huggingface.co/Qwen/Qwen3-32B-FP8)
model using the example in [AKS Dynamo Part 2 sample](https://aka.ms/aks-dynamo-part-2).

## Conclusion: Inference Without the Infrastructure Burden

The shift toward disaggregated serving is a necessity for the next
generation of reasoning-heavy and long-context LLMs. However, as we
have seen, the complexity of manually tuning these distributed systems
on Kubernetes can quickly become a bottleneck for even the most
experienced AI teams.

By utilizing the NVIDIA Dynamo Planner Profiler, developers can move
from educated guessing to data-driven certainty, modeling performance
in seconds rather than days. When paired with the Dynamo Planner, this
static optimization becomes a dynamic, SLO-aware reality on AKS, capable of
weathering the unpredictable traffic spikes of production environments.

Ultimately, this suite transforms your inference stack from a series of
fragile configurations into a resilient, self-optimizing engine. For the AI
engineer, this means less time spent managing hardware limits and configuring
system scalability and more time spent delivering the high-quality,
interactive experiences that your users (and your passengers) expect.
