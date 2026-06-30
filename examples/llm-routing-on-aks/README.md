# LLM routing on AKS — example manifests

Companion manifests for the blog post **[Routing agent traffic is really three
decisions](https://blog.aks.azure.com/2026/06/29/llm-routing-on-aks)**. Agentic
workloads make many LLM calls in loops with tool use, so *where each call lands*
— a cheap self-hosted model vs. a frontier model — drives both cost and latency.
The post splits "routing" into three decisions on three signals:
**content → policy → GPU state**.

These files are the manifest-grade artifacts pulled out of the post. The `az`,
`helm`, and `curl` setup commands stay in the post itself.

> **Versions move fast.** These were validated against KAITO (AKS add-on),
> Gateway API Inference Extension **v1.0.0**, and agentgateway **v1.3.1** in
> mid-2026. The Inference Extension renamed/restructured CRDs on its way to v1
> and the managed gateway story is still settling — pin your versions and
> confirm fields against the docs linked below.

## Files

| File | Layer | What it is |
| --- | --- | --- |
| `kaito-workspace.yaml` | 3 — serving | A KAITO `Workspace` that provisions GPU nodes and serves `phi-4-mini-instruct` on vLLM. |
| `inference-pool.yaml` | 3 — inference LB | The `InferencePool` (pods + Endpoint Picker reference) and an `InferenceObjective` (per-workload priority). |
| `inference-gateway.yaml` | 3 — front door | A `Gateway` on the `approuting-istio` class and an `HTTPRoute` whose backend is the `InferencePool`. |
| `agentgateway-config.yaml` | 2 — AI gateway | agentgateway's **application config** — strong (Azure OpenAI) and weak (in-cluster) backends, plus rate-limit / cost policies. Not a Kubernetes manifest (see note). |
| `podmonitors.yaml` | Observability | Managed-Prometheus `PodMonitor`s (`azmonitoring.coreos.com/v1`) scraping vLLM (:5000) and agentgateway (:15020) — the serving and routing metric sources. |

The first three are Kubernetes manifests with an `apiVersion`/`kind`, applied with
`kubectl apply -f`. `agentgateway-config.yaml` is **not** a Kubernetes object — it
has no GVK by design, because the agentgateway process reads it directly. You
deploy agentgateway as a Deployment + Service and mount this file as its config
(for example, via a ConfigMap); you do not `kubectl apply` it.

## Gotchas worth knowing before you start

These cost real debugging time during validation:

- **The InferencePool targets the vLLM *container* port `5000`, not the Service
  port `80`.** A GIE pool routes to pod IPs directly, bypassing the KAITO
  Service (which maps 80→5000). With `80` you get silent connection failures.
- **`InferenceObjective` is in the `inference.networking.x-k8s.io` group**, while
  `InferencePool` is in `inference.networking.k8s.io`. Mixing them up makes the
  objective fail to apply.
- **The Endpoint Picker must serve plaintext gRPC** to match the gateway's
  ext-proc cluster: install/run it with `--secure-serving=false`. Otherwise the
  gateway's ext-proc call resets (TLS vs. plaintext mismatch).
- **Enabling the managed Gateway API is a *separate* step** from app-routing-istio
  (`az aks update --enable-gateway-api`), and AKS **serializes** cluster updates —
  let KAITO finish provisioning the GPU node pool before issuing more `az aks
  update` calls, or they get preempted.
- **Use a current frontier model** (e.g. `gpt-5.1`) for the strong path; `gpt-4o`
  is deprecating in many regions and may not be newly deployable.

## Apply order

The layers build bottom-up — each needs the address of the one beneath it.

```bash
kubectl create namespace llm

# Layer 3 — serve the weak model (KAITO provisions the GPU pool; ~10–20 min).
# Let this FINISH before the next az aks update (AKS serializes cluster ops).
kubectl apply -f kaito-workspace.yaml
kubectl get workspace workspace-phi-4-mini -n llm -w

# Layer 3 — install the Inference Extension CRDs + Endpoint Picker (see the post
# for the kubectl apply of the v1.0.0 release manifests and the helm install of
# phi-epp with --secure-serving=false), then create the objective.
# NOTE: the Helm chart already creates an InferencePool named after the release;
# use that pool OR the one in inference-pool.yaml — not both.
kubectl apply -f inference-pool.yaml

# Layer 3 — front the pool with a Gateway API gateway (see "Layer-3 gateway" below)
kubectl apply -f inference-gateway.yaml

# Layer 2 — agentgateway is a Deployment + Service that loads
# agentgateway-config.yaml as its config (NOT a kubectl apply of this file —
# it has no GVK; mount it via a ConfigMap).
```

Layer 1 (RouteLLM) runs as a small Deployment pointed at the agentgateway
endpoint. It's configured by flags/env, so there's no manifest here. Note its
`mf` router **requires a reachable `text-embedding-3-small` endpoint** to make a
routing decision, and needs `litellm.drop_params=True` for gpt-5.x models.

## Layer-3 gateway: managed vs. self-managed

`inference-gateway.yaml` targets the **managed Application routing** gateway
(`gatewayClassName: approuting-istio`) — the direction this is heading. As of
mid-2026 the managed gateway's Gateway API Inference Extension support is
**private preview**, gated server-side, so an `HTTPRoute → InferencePool` backend
may be rejected ("InferencePool is not enabled") until it reaches your
subscription/region.

To run the full weak path **today**, front the InferencePool with a self-managed
upstream-Istio gateway that has the inference extension enabled (revision-isolated
so the add-on can't revert it):

```bash
istioctl install -y --set profile=minimal --set revision=gie \
  --set values.pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true \
  --set values.pilot.env.PILOT_GATEWAY_API_CONTROLLER_NAME=istio.io/gie-gateway-controller \
  --set values.pilot.env.PILOT_GATEWAY_API_DEFAULT_GATEWAYCLASS_NAME=istio-gie
```

Then point `inference-gateway.yaml`'s `gatewayClassName` at `istio-gie`. When the
managed gateway's GAIE support ships, switch back to `approuting-istio` with no
other changes.

## Learn more

- [AI toolchain operator (KAITO) on AKS](https://learn.microsoft.com/azure/aks/ai-toolchain-operator)
- [Application routing add-on with the Gateway API](https://learn.microsoft.com/azure/aks/app-routing-gateway-api)
- [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/)
- [agentgateway documentation](https://agentgateway.dev/docs/)
- [RouteLLM](https://github.com/lm-sys/RouteLLM)
