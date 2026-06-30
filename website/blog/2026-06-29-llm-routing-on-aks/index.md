---
title: "Routing agent traffic on AKS is three decisions"
date: 2026-06-29
description: "Agents make many LLM calls in loops, so routing each to the right model — cheap self-hosted or frontier — keeps them affordable. Three decisions on AKS."
authors: [fuyuan-bie]
tags: [ai-inference, agent, agentgateway, routellm, kaito, gateway-api, app-routing]
---

A chat turn is one LLM call. An agent is hundreds — a reasoning loop that plans, calls a tool, reads the result, re-plans, and only sometimes stops. The cost and latency you signed up for in a demo get multiplied by that loop, and most of those calls are *easy* — a tool-argument fill, a yes/no gate, a short summary — that never needed a frontier model. So the question isn't "which model is best." It's "which model should answer *this specific call*, and how do I govern a flood of them?" That's not one decision; it's three, on different signals.

This post wires up those three decisions on AKS as a single OpenAI-compatible endpoint: a trivial agent step lands on a cheap self-hosted model (KAITO + vLLM, placed by GPU state) while a hard step escalates to a frontier model on Azure OpenAI — every call authenticated, metered, and traced. We lean on managed Azure throughout (**KAITO** for serving, the **application routing** add-on for the Gateway API, **Azure OpenAI** for the frontier path, **Azure Managed Prometheus and Grafana** for observability); the two layers without a drop-in managed service — the semantic router and the AI gateway — run as open source on the cluster, and we name the managed alternative for each.

<!-- truncate -->

## The three decisions

"Route this request" hides three separate questions, each reading a different signal, each with a different owner. For an agent firing calls in a loop, all three matter on every iteration:

1. **Which model should answer this call?** A multi-step reasoning hop deserves a frontier model; "extract the date from this string" does not. Answering means reading the request *content* and predicting answer quality. This is **semantic routing**, and we'll use **[RouteLLM](https://github.com/lm-sys/RouteLLM)**.
2. **How do I expose, secure, govern, and forward this traffic?** Provider abstraction, auth, per-agent budgets, rate limits, guardrails, observability. None of that cares about prompt meaning — it's a *policy* job for a data plane. We'll use **[agentgateway](https://agentgateway.dev/docs/)**, an OpenAI-compatible, agent-native proxy, in the cluster.
3. **Which replica of the chosen model gets this call?** Across a fleet of GPU pods the right target depends on KV-cache occupancy, queue depth, and which LoRA adapters are already resident — live *GPU state*. That's the **[Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/)** and its Endpoint Picker.

**Content → policy → GPU state.** That's the through-line, and the discipline is refusing to let any layer answer a question that belongs to another: the router never thinks about auth, the gateway never thinks about prompt difficulty, the Endpoint Picker never thinks about *which* model — only *which replica*.

![Structure and ownership of the three-layer agent-traffic routing design on AKS: RouteLLM (Layer 1) and agentgateway (Layer 2) run as open source inside the AKS cluster, while the application routing Gateway API, Inference Extension Endpoint Picker, and KAITO-served vLLM pods make up Layer 3; the gateway abstracts a managed Azure OpenAI frontier backend and a self-hosted backend, and Azure Monitor scrapes vLLM and cost metrics. Solid lines show composition and ownership, not request order.](./llm-routing-on-aks-architecture.svg)

## The architecture on AKS

Each open-source slot has a managed Azure alternative, called out in the layer that earns it:

| Layer | Decision | Featured component | Managed on AKS? |
| --- | --- | --- | --- |
| 1 — Semantic | which *model* answers | RouteLLM | Open source on AKS |
| 2 — AI gateway | auth, cost, guardrails, provider abstraction | agentgateway | Open source on AKS |
| 2 — Gateway API | in-cluster HTTP routing | **Application routing** add-on | Managed add-on |
| 3 — Inference LB | which *replica* | Gateway API Inference Extension (Endpoint Picker) | Open source, runs on the gateway |
| 3 — Serving | run the model on GPUs | **KAITO** add-on → vLLM | Managed add-on |
| Frontier path | the "strong" model | **Azure OpenAI** | Managed |
| Observability | metrics & dashboards | **Azure Managed Prometheus + Grafana** | Managed |

![Per-request trace through the three layers, numbered in order: an agent call (step 1) enters RouteLLM, which reads the prompt and picks strong or weak (step 2); agentgateway dispatches the strong path straight to Azure OpenAI (step 3a, ends there) or the weak path onward (step 3b) through the Gateway API (step 4) to the Inference Extension Endpoint Picker (step 5), which selects one KAITO-served vLLM pod by GPU state (step 6). The strong path ends at step 3a; the weak path ends at step 6.](./llm-routing-on-aks-request-path.svg)

:::note[A NOTE ON EXACTNESS]
Several pieces here are young, and field names drift between releases — the Inference Extension renamed and restructured CRDs on its way to v1, and the managed gateway's inference support is still rolling out. Everything below was validated end-to-end on AKS in mid-2026 against Inference Extension v1.0.0 and agentgateway v1.3.1. Treat the manifests as the *shape* of the solution, pin your versions, and confirm fields against the docs at the end. The decomposition is stable; specific flags and CRD fields move quickly.
:::

With the map in hand, the rest of this post builds it — bottom-up, serving first and the semantic decision last, because each layer needs the address of the one beneath it. First, the cluster everything runs on.

## Prerequisites

- An Azure subscription with GPU quota for the VM family you'll serve on (this guide uses a single `Standard_NC*` GPU node pool, provisioned for you by KAITO). Quota isn't capacity — confirm the SKU is actually allocatable in your region before you rely on it.
- A recent Azure CLI and `kubectl`.
- An Azure OpenAI (or AI Foundry) resource with a current frontier deployment for the strong path. We use `gpt-5.1`; `gpt-4o` is deprecating in many regions and may not be newly deployable.

Create a cluster with the serving and monitoring add-ons enabled. KAITO provisions and manages GPU node pools on demand, so you don't pre-create them:

```bash
az aks create \
  --resource-group $RG \
  --name $CLUSTER \
  --node-count 2 \
  --enable-ai-toolchain-operator \
  --enable-oidc-issuer \
  --enable-azure-monitor-metrics \
  --generate-ssh-keys

az aks get-credentials --resource-group $RG --name $CLUSTER
```

The Gateway API front door (Layer 3) needs two more enablements, and two things trip people up. The managed gateway and its Gateway API CRDs are **separate flags**; and AKS **serializes** cluster-control-plane updates, so firing these while KAITO provisions its GPU node pool gets them preempted — enable the gateway before applying the KAITO workspace, or wait for the pool.

```bash
# the meshless Istio gateway (preview), then the managed Gateway API CRDs
az aks update --resource-group $RG --name $CLUSTER --enable-app-routing-istio
az aks update --resource-group $RG --name $CLUSTER --enable-gateway-api
```

The first command deploys a **meshless Istio control plane**: an `istiod` in `aks-istio-system` that reconciles Kubernetes Gateway API resources only — no sidecar injection, no Istio CRDs, just managed Envoy gateways. The second installs the Gateway API CRDs and registers the GatewayClass **`approuting-istio`**. Confirm both flags against the [application routing Gateway API docs](https://learn.microsoft.com/azure/aks/app-routing-gateway-api); they're preview and they move.

With the cluster up, start at the bottom: serving the weak model.

## Layer 3 — Serving, and the load-balancing trap

Start with the failure mode, because it's the whole reason this layer is more than a `Service` — and agents make it worse.

Round-robin assumes requests are interchangeable. LLM requests are anything but: a 100k-token context-stuffed agent step and a 200-token tool-argument fill differ by three orders of magnitude in cost. An agent fleet mixes both constantly. Spray them uniformly across identical pods and round-robin will cheerfully queue a cheap completion behind a giant prefill on a saturated pod while an idle pod sits next to it. Your throughput looks fine and your p99 — the thing an agent loop feels on *every* iteration — falls off a cliff.

The fix isn't more pods — it's *placing each request on the pod best able to take it right now*, by reading live KV-cache occupancy and queue depth. That capability is what the **Endpoint Picker** is. Everything else in this layer exists to feed it.

### 3.1 The pods to place: KAITO

The Endpoint Picker needs a homogeneous pool of model servers exporting the right signals, and KAITO produces exactly that: declare a `Workspace`, point it at a preset, and KAITO provisions the GPU SKU, runs vLLM, and exposes an OpenAI-compatible Service. Because the engine is vLLM, every pod emits the metrics the Endpoint Picker routes on (`vllm:num_requests_waiting`, `vllm:kv_cache_usage_perc`). Apply [`kaito-workspace.yaml`](https://github.com/Azure/AKS/blob/master/examples/llm-routing-on-aks/kaito-workspace.yaml) — it pins `instanceType: Standard_NC24ads_A100_v4`, `count: 2`, and `preset: phi-4-mini-instruct`:

```bash
kubectl apply -f kaito-workspace.yaml
kubectl get workspace workspace-phi-4-mini -n llm -w   # Ready can take ~10–20 min
```

KAITO provisions the GPU node, pulls the model, and starts vLLM; the workspace flips to `Ready` when inference is up:

```text
NAME                   INSTANCE                   RESOURCEREADY   INFERENCEREADY   STATE
workspace-phi-4-mini   Standard_NC24ads_A100_v4   True            True             Ready
```

KAITO publishes a Service named `workspace-phi-4-mini` on port 80 and labels its pods `kaito.sh/workspace: workspace-phi-4-mini` — that label is how the next step selects the pool. One detail that will bite you later: the Service maps port 80 to the vLLM **container's port 5000**, and the Endpoint Picker routes to pod IPs directly, bypassing the Service. So the pool below targets `5000`, not `80`.

### 3.2 The placement logic: the Inference Extension

Pool membership — *which pods are the model server* — is a different concern from how a workload is weighted against that pool, so the Inference Extension splits them across two objects on top of Gateway API:

- An **`InferencePool`** — the set of model-server pods plus a reference to the **Endpoint Picker (EPP)**, the extension the gateway calls over Envoy ext-proc to choose an endpoint per request.
- An **`InferenceObjective`** — the per-workload treatment: an integer `priority` against a pool. (It's a redesign of the earlier `InferenceModel`, which carried a `modelName` and a `criticality` enum; v1 dropped both, taking the served-model name from the request instead.)

Install the CRDs and the Endpoint Picker (the project ships a Helm chart), pointing it at the KAITO pods. The EPP must serve **plaintext** gRPC to match the gateway's ext-proc cluster — set `--secure-serving=false`, or the gateway's call to it resets before headers:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.0.0/manifests.yaml

helm install phi-epp \
  oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool \
  --version v1.0.0 -n llm \
  --set inferencePool.modelServers.matchLabels."kaito\.sh/workspace"=workspace-phi-4-mini \
  --set provider.name=none \
  --set inferenceExtension.extraArgs="{--secure-serving=false}"
```

The Helm chart creates its own `InferencePool` named after the release, so you don't strictly need to apply one. If you do, [`inference-pool.yaml`](https://github.com/Azure/AKS/blob/master/examples/llm-routing-on-aks/inference-pool.yaml) has the full `InferencePool` + `InferenceObjective` — with two fields that trip people up. The pool's selector needs a structured `matchLabels`, and its `targetPorts` must be the vLLM **container** port `5000` (the pool routes to pod IPs, bypassing the Service's port 80):

```yaml
spec:
  selector:
    matchLabels: { kaito.sh/workspace: workspace-phi-4-mini }
  targetPorts:
    - number: 5000          # the vLLM container port, NOT the Service's 80
```

The other trap is the API group: `InferencePool` lives in `inference.networking.k8s.io`, but `InferenceObjective` lives in `inference.networking.x-k8s.io` — different groups, easy to miss.

### 3.3 The front door: a Gateway API gateway

The Endpoint Picker needs a gateway that speaks ext-proc to call it. [`inference-gateway.yaml`](https://github.com/Azure/AKS/blob/master/examples/llm-routing-on-aks/inference-gateway.yaml) defines a `Gateway` on the `approuting-istio` class and an `HTTPRoute` whose backend is the `InferencePool` — note the backend is the *pool*, not a Service:

```bash
kubectl apply -f inference-gateway.yaml
```

:::warning[MANAGED GATEWAY VS. WHAT WORKS TODAY]
Fronting an `InferencePool` with the **managed** Application routing gateway is the direction this is heading and the destination this post points at — one managed gateway, no Istio to operate. As of mid-2026 that pairing is **private preview**, gated server-side: the managed `istiod` ships with the inference extension turned off, so an `HTTPRoute → InferencePool` backend is rejected ("InferencePool is not enabled") until the capability reaches your subscription and region. To run the weak path **today**, front the pool with a self-managed upstream-Istio gateway that has the extension enabled, revision-isolated so the add-on can't revert it:

```bash
istioctl install -y --set profile=minimal --set revision=gie \
  --set values.pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true \
  --set values.pilot.env.PILOT_GATEWAY_API_CONTROLLER_NAME=istio.io/gie-gateway-controller \
  --set values.pilot.env.PILOT_GATEWAY_API_DEFAULT_GATEWAYCLASS_NAME=istio-gie
```

Then set `gatewayClassName: istio-gie` on the `Gateway` above. When the managed gateway's inference support ships for you, switch the class back to `approuting-istio` and delete the self-managed install — nothing else changes.
:::

Fire a burst of differently-sized requests and watch them spread by load rather than position — that's the picker earning its keep:

```bash
GW_IP=$(kubectl get gateway inference-gw -n llm -o jsonpath='{.status.addresses[0].value}')
curl -s http://$GW_IP/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"phi-4-mini-instruct","messages":[{"role":"user","content":"ping"}]}'
```

**What this layer decided:** only *which replica*, on GPU state. It has no idea what a "strong" model is, no budgets, no auth. Those are the next layer's job.

## Layer 2 — The gateway, and why agents need it most

The tempting shortcut is to let the router call backends directly. Resist it — and with agents the reason is sharper than with chat. An agent loop can spend an unbounded number of tokens before it decides to stop; without a budget and a rate limit *somewhere on the path*, a single misbehaving agent can run up a frontier bill or saturate your GPU fleet. A gateway is where that policy lives, written once, so nothing else has to reinvent it.

agentgateway is an open-source, OpenAI-compatible AI gateway built for exactly this traffic: provider abstraction, auth, token-based rate limiting, model-cost tracking, guardrails, and OpenTelemetry across backends — and, because it's agent-native, first-class MCP tool-serving and agent-to-agent routing when you grow into them. Here it does two jobs: hide the **strong** (Azure OpenAI) and **weak** (in-cluster) backends behind one endpoint, and enforce policy on every call.

:::note[CONFIG SHAPE]
The snippets below were validated against agentgateway v1.3.1 and trimmed for the argument; pin field names to the [agentgateway docs](https://agentgateway.dev/docs/). The full file is in the [example manifests](https://github.com/Azure/AKS/tree/master/examples/llm-routing-on-aks).
:::

The outer shape is `binds → listeners → routes → backends`. The one thing to internalize: an AI backend is `ai: { name, provider: { <provider>: {...} } }` — the provider nests under `provider:`, `name` is required, and the Azure provider needs `resourceName` **and** `resourceType` (its `model` is your Azure *deployment* name). Auth attaches as a route policy whose key the Azure provider sends as the `api-key` header:

```yaml
backends:
  - ai:
      name: aoai-strong
      provider:
        azure: { resourceName: "$AOAI_RESOURCE", resourceType: openAI, model: gpt-5.1, apiVersion: "2024-10-21" }
```

The full two-route config — `strong` to Azure OpenAI, `weak` to the Layer-3 inference gateway (a plain `host` backend with a path rewrite, since it already speaks OpenAI) — is in [`agentgateway-config.yaml`](https://github.com/Azure/AKS/blob/master/examples/llm-routing-on-aks/agentgateway-config.yaml). The credential never leaves the gateway, and the `weak` route neither knows nor cares that an Endpoint Picker sits behind it.

The governance that makes this safe for agents lives there too: a per-million-token **cost catalog** (so every call carries a real dollar figure into your logs and metrics) and a token **rate limit**, both as route policies — the backstop against an agent loop that won't stop spending.

:::tip[MANAGED ALTERNATIVE FOR THIS LAYER]
If you'd rather not run a gateway, **Azure API Management**'s AI gateway gives you token-based rate limiting (`azure-openai-token-limit` / `llm-token-limit`), token metrics to Application Insights, semantic caching, and load-balancing with circuit-breaker failover across Azure OpenAI backends — all managed. Pair it with **Azure AI Content Safety** for guardrails. The trade-off is concrete: APIM is a managed service you configure with policies, but agentgateway is an extra in-path component you run and own — one more failure domain on the critical path. APIM buys that back as Azure-managed surface; agentgateway gives you OpenAI-compatible, agent-native policy next to your pods.
:::

Smoke-test both paths before the router exists:

```bash
# strong → Azure OpenAI
curl -s http://agentgateway.llm.svc.cluster.local:4000/strong/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.1","messages":[{"role":"user","content":"Say no in one word."}]}'

# weak → KAITO via the Endpoint Picker
curl -s http://agentgateway.llm.svc.cluster.local:4000/weak \
  -H "Content-Type: application/json" \
  -d '{"model":"phi-4-mini-instruct","messages":[{"role":"user","content":"Say hi in one word."}]}'
```

Both return an OpenAI-shaped completion — the `strong` call comes back stamped with the resolved Azure deployment, the `weak` call from the in-cluster model, and neither caller had to know where the model lived:

```jsonc
// strong → Azure OpenAI
{ "model": "gpt-5.1-2025-11-13",
  "choices": [{ "message": { "role": "assistant", "content": "No." } }],
  "usage": { "total_tokens": 29 } }

// weak → KAITO / vLLM
{ "model": "phi-4-mini-instruct",
  "choices": [{ "message": { "role": "assistant", "content": "Hello." } }] }
```

**What this layer decided:** how to authenticate, meter, guardrail, and forward — on *policy*, never on content. It dispatches whatever model name it's handed. Choosing that name is Layer 1's job.

## Layer 1 — The semantic decision, and the threshold that is the whole ballgame

Here's the only layer that reads the prompt — and the one decision that actually moves the bill. For an agent firing hundreds of calls per task, it's also the layer with the most leverage: every easy call it keeps off the frontier model is multiplied by the loop.

RouteLLM is a set of routers trained on human-preference data to predict, per prompt, whether a cheap model can match a strong model's answer. On the paper's own model pair, the featured `mf` (matrix-factorization) router reaches **~95% of GPT-4's quality on MT-Bench while making just ~26% of the GPT-4 calls** — cutting cost by up to ~85% versus sending everything to GPT-4, by escalating only the genuinely hard prompts.

:::warning[WHERE IT STRAINS]
Those figures are for the pair RouteLLM was trained on — not your strong/weak pair. The router's quality predictor is fit to a particular pairing, so whether ~26% escalation holds with phi-4-mini as your weak model is something you confirm against your own traffic. And the router isn't free: scoring every prompt is itself a paid `text-embedding-3-small` round-trip, so the cost win depends on the price gap between strong and weak dwarfing that per-call overhead. That's the reason for the calibrate-then-close-the-loop step below, not a footnote to it.
:::

The composition is the elegant part: **RouteLLM's strong and weak upstreams are just agentgateway.** It makes the semantic call, picks a model, and forwards into the governed data plane — so the decision layer inherits all of Layer 2's auth, budgets, and tracing without re-implementing a line of it.

One wiring detail the reviewer in you should catch: agentgateway routes by **path** (`/strong`, `/weak`), but RouteLLM hands its choice to litellm as a *model name*. So point each model at the matching agentgateway path with a per-model `api_base` rather than a single base URL:

```bash
# inside the RouteLLM container — each model maps to its agentgateway route
python -m routellm.openai_server --routers mf \
  --strong-model openai/gpt-5.1 \
  --weak-model   openai/phi-4-mini-instruct \
  --config routellm-config.yaml   # sets api_base per model → /strong and /weak
```

One more gotcha from running this against current models: newer frontier models reject the `presence_penalty` / `frequency_penalty` parameters RouteLLM sends by default, so set `litellm.drop_params=True` to drop them rather than 400 the call.

Clients call RouteLLM with a model string that encodes both the router and the cost threshold:

```text
router-mf-0.11593
        │   └── threshold: the strong/weak cutoff — calibrate it
        └────── the matrix-factorization router
```

That threshold is the ballgame. Set it too low and you escalate everything and pay frontier prices for "hello"; set it too high and quality craters on the hard steps that needed the strong model. Don't guess it — calibrate against a representative sample so a target fraction of *your* traffic escalates:

```bash
python -m routellm.calibrate_threshold --routers mf --strong-model-pct 0.5
# → 0.11593: the threshold that sends ~50% of calls to "strong"
```

Then close the loop with the *real* numbers. Run live agent traffic and read the actual strong/weak split and dollar cost off **agentgateway's** metrics — not RouteLLM's estimate — and nudge the threshold until the cost/quality trade sits where you want it. The router proposes; your own cost data disposes.

:::tip[MANAGED ALTERNATIVE FOR THIS LAYER]
**Microsoft Foundry**'s model router is a single managed deployment that routes among models by query complexity and cost — the managed analogue to RouteLLM. We feature RouteLLM precisely because the explicit, calibratable threshold is the heart of this design and worth holding in your own hands. If you'd rather not operate a router, the Foundry model router fills the same slot.
:::

## Observability with managed Azure monitoring

Layer 1 trades quality for cost, so this section closes one question: can you trust the cost number, and can you watch the same signals the Endpoint Picker routes on? The answer splits by source — **GPU and latency come from vLLM; dollars and the strong/weak split come from agentgateway** — so a complete view scrapes both.

To get there, add two `PodMonitor`s to the Managed Prometheus you enabled at cluster creation: one selecting the KAITO pods for vLLM's metrics on port 5000, one for agentgateway's on port 15020. Then link **Azure Managed Grafana** to the workspace. (One gotcha: the managed add-on uses Azure's CRDs under the **`azmonitoring.coreos.com`** API group, not upstream `monitoring.coreos.com`, so change a community manifest's `apiVersion` to `azmonitoring.coreos.com/v1` or the add-on won't scrape it.)

![Live metrics from the running cluster under mixed agent load, scraped by Azure Managed Prometheus into an Azure Monitor workspace. Top row (agentgateway, Layers 1–2): request rate by route showing the strong/weak split, a cumulative donut at roughly 30% strong and 70% weak, and vLLM token throughput. Bottom row (vLLM, Layer 3): KV-cache utilization spiking under load, and requests running versus queued. The routing split comes from agentgateway's metrics; the GPU-serving signals come from vLLM's.](./llm-routing-on-aks-observability.png)

## The full path, one call

```bash
# trivial step → router picks weak → gateway → Endpoint Picker → KAITO pod
curl -s http://routellm.llm.svc.cluster.local:6060/v1/chat/completions \
  -d '{"model":"router-mf-0.11593","messages":[{"role":"user","content":"What is 2+2?"}]}'

# hard step → router picks strong → gateway → Azure OpenAI
curl -s http://routellm.llm.svc.cluster.local:6060/v1/chat/completions \
  -d '{"model":"router-mf-0.11593",
       "messages":[{"role":"user","content":"Derive the EM algorithm and explain why each step cannot decrease the log-likelihood."}]}'
```

The `model` field in each response is the receipt — it tells you which way the router decided. Against the calibrated threshold `0.11593`, `"What is 2+2?"` scores a strong-win-rate of `0.09` (below the line → weak) while the EM-algorithm prompt scores `0.29` (above → strong), so they come back from different models:

```jsonc
// "What is 2+2?"             → "model": "phi-4-mini-instruct"   (weak, a fraction of a cent)
// "Derive the EM algorithm…" → "model": "gpt-5.1-2025-11-13"    (strong, frontier pricing)
```

Both hit the *same* endpoint with the *same* model string. Three decisions — content, policy, GPU state — resolved in one round trip, each by the layer that owns it. Now point your agent framework's base URL at that endpoint and every call in the loop gets sorted the same way.

## Scale it to your problem

You rarely need all of it on day one. Because the layers don't bleed into each other, you can adopt exactly the slice your problem demands:

- **One hosted model, a few agents, no self-hosting?** **Layer 2 only** — agentgateway (or APIM) for auth, budgets, and guardrails over Azure OpenAI. There's nothing to route *to* and no GPUs to place on.
- **Self-hosting at scale but one model class?** **KAITO + the Inference Extension** give you managed serving and cache-aware placement. Skip semantic routing — there's only one model.
- **A real cost problem from agents sending easy steps to expensive models?** Add **RouteLLM**. It earns its keep the moment you have a meaningful price gap and a meaningful fraction of easy traffic — which describes essentially every agent in a loop.

## Conclusion

Routing agent traffic isn't one decision — it's three, each on its own signal: **content** picks the model (RouteLLM), **policy** governs the call (agentgateway), and **GPU state** picks the replica (the Inference Extension over KAITO-served vLLM). Keep those seams clean and you get a single OpenAI-compatible endpoint your agents point at, where every call is routed, metered, and traced by the layer that owns that concern — and where the easy calls an agent loop fires by the hundred quietly stay off the frontier bill.

From here, the obvious next moves all reinforce the same shape: autoscale the weak fleet on `vllm:num_requests_waiting` with the managed **KEDA** add-on so the GPU pool breathes with bursty agent traffic; lean into agentgateway's agent-native side by serving tools over **MCP** and routing **agent-to-agent** traffic through the same governed data plane; and add per-agent budgets at the gateway so spend stays attributable as more agents share the cluster.

The [example manifests](https://github.com/Azure/AKS/tree/master/examples/llm-routing-on-aks) have everything here ready to adapt. For the components themselves, see [KAITO on AKS](https://learn.microsoft.com/azure/aks/ai-toolchain-operator), the [application routing Gateway API add-on](https://learn.microsoft.com/azure/aks/app-routing-gateway-api), the [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/), [agentgateway](https://agentgateway.dev/docs/), [RouteLLM](https://github.com/lm-sys/RouteLLM) (and its [paper](https://arxiv.org/abs/2406.18665)), and [Managed Prometheus and Grafana for AKS](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable).
