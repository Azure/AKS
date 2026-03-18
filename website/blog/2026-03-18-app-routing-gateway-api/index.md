---
title: "Announcing Gateway API support for App Routing (preview)"
date: "2026-03-18"
description: "The AKS app routing add-on now supports the Kubernetes Gateway API via a lightweight, meshless Istio control plane — the recommended migration path ahead of the Ingress-NGINX retirement in November 2026."
authors: ["jaiveer-katariya"]
tags:
  - app-routing
  - gateway-api
  - networking
  - istio
  - ingress-nginx
keywords: ["AKS", "Gateway API", "app routing", "Istio", "ingress", "NGINX", "Kubernetes"]
---

We're announcing preview support for the **Kubernetes Gateway API** in the AKS application routing add-on. This brings a modern, role-oriented traffic management model to AKS — and establishes a clear migration path ahead of the [upcoming Ingress-NGINX retirement](#why-now-the-ingress-nginx-retirement).

## Background: the Kubernetes networking stack is evolving

For years, the Kubernetes [Ingress API](https://kubernetes.io/docs/concepts/services-networking/ingress/) has been the standard way to expose HTTP services running in a cluster. It works, but it has real limitations: the spec is intentionally minimal, leaving providers to implement advanced routing via non-standard annotations, and its flat, single-resource model doesn't map well to real-world organizational boundaries where platform teams and application teams have different concerns.

The [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) was designed by SIG Network to address these gaps. It introduces a layered, role-oriented model:

- **GatewayClass** — defines the type of gateway infrastructure (managed by infrastructure operators)
- **Gateway** — instantiates a gateway and its listeners (managed by cluster operators)
- **HTTPRoute / GRPCRoute / etc.** — bind application traffic rules to a gateway (managed by application developers)

This separation means a platform team can provision and own shared gateway infrastructure, while application teams independently control their routing rules — without needing elevated access or custom annotations. Gateway API also has first-class support for features like traffic splitting, header-based routing, and backend weighting that previously required vendor-specific workarounds.

Gateway API is the direction Kubernetes networking is heading. The Ingress API is not going away, but active development has shifted to Gateway API, and the tooling ecosystem is following.

## Why now: the Ingress-NGINX retirement

In November 2025, Kubernetes SIG Network and the Security Response Committee [announced the retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/) of the Ingress-NGINX project. Upstream maintenance ended in **March 2026**.

Microsoft is providing a support bridge: critical security patches for the application routing add-on's managed NGINX implementation will continue through **November 2026**. But after that date, managed NGINX will no longer receive Azure support, and users will need to have migrated.

If your cluster uses the application routing add-on with NGINX today, the application routing Gateway API implementation is your recommended migration path.

## What's new: Gateway API support in the app routing add-on

The application routing add-on now supports the Kubernetes Gateway API through a new mode, enabled via `--enable-app-routing-istio`. Under the hood, this deploys a lightweight Istio control plane to manage the gateway infrastructure — but without enabling the full Istio service mesh. No sidecar injection, no Istio CRDs for your workloads. Just Istio doing what it does well: managing Envoy-based gateway proxies.

When you create a `Gateway` resource using the `approuting-istio` GatewayClass, AKS automatically provisions:

- An Envoy-based **Deployment** to handle traffic
- A **LoadBalancer Service** exposing the gateway externally
- A **HorizontalPodAutoscaler** (default: 2–5 replicas at 80% CPU)
- A **PodDisruptionBudget** (minimum 1 available) for safe upgrades

All of this is managed for you. You write a `Gateway` and an `HTTPRoute`, and AKS handles the underlying infrastructure.

### Meshless Istio: how it differs from the Istio service mesh add-on

If you're already using or considering the [Istio service mesh add-on](https://learn.microsoft.com/azure/aks/istio-about), it's worth understanding how this differs:

| | App routing Gateway API | Istio service mesh add-on |
|---|---|---|
| **GatewayClass** | `approuting-istio` | `istio` |
| **Sidecar injection** | Not enabled | Enabled cluster-wide |
| **Istio CRDs** | Not installed | Installed |
| **Upgrades** | In-place (minor and patch) | Canary upgrades for minor versions |

The two cannot run simultaneously — enabling one requires the other to be disabled first. If you want a full service mesh (mTLS between services, traffic policies, telemetry), use the Istio service mesh add-on. If you want a managed Gateway API ingress implementation without the operational overhead of a mesh, this is the right choice.

## Getting started

### Prerequisites

1. **`aks-preview` CLI extension**, version `19.0.0b26` or later:

    ```bash
    az extension add --name aks-preview
    az extension update --name aks-preview
    ```

2. **Managed Gateway API CRDs** enabled on your cluster. This installs and lifecycle-manages the Gateway API CRDs, keeping them in sync with your Kubernetes version automatically. Register the feature flag and enable it:

    ```bash
    az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
    az aks update --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --enable-gateway-api
    ```

### Enable the app routing Gateway API implementation

**On a new cluster:**

```bash
az aks create \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --enable-app-routing-istio \
  --enable-gateway-api
```

**On an existing cluster** (assuming the Managed Gateway API CRDs prerequisite above is already complete):

```bash
az aks update \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --enable-app-routing-istio
```

After a moment, you should see `istiod` running in `aks-istio-system`:

```bash
kubectl get pods -n aks-istio-system
```

```output
NAME                      READY   STATUS    RESTARTS   AGE
istiod-54b4ff45cf-htph8   1/1     Running   0          3m15s
istiod-54b4ff45cf-wlvgd   1/1     Running   0          3m
```

### Deploy a sample app, Gateway, and HTTPRoute

First, deploy the `httpbin` sample application:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/httpbin/httpbin.yaml
```

Then create a `Gateway` using the `approuting-istio` GatewayClass and attach an `HTTPRoute` to it:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  gatewayClassName: approuting-istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
spec:
  parentRefs:
  - name: httpbin-gateway
  hostnames: ["httpbin.example.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
EOF
```

AKS will provision the underlying Deployment, Service, HPA, and PDB automatically. Wait for the Gateway to be programmed and retrieve its external IP:

```bash
kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io httpbin-gateway
export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -ojsonpath='{.status.addresses[0].value}')
```

Send a request to verify traffic is flowing:

```bash
curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST/get"
```

You should see an `HTTP 200` response.

### Upgrades

The Istio control plane version is tied to your AKS cluster's Kubernetes version. Patch version upgrades happen automatically as part of AKS releases. Minor version upgrades happen in-place when you upgrade your cluster's Kubernetes version, or automatically when a new Istio minor version is released for your AKS version. Follow the [AKS release notes](https://github.com/azure/aks/releases) to stay current.

:::caution

Unlike the Istio service mesh add-on, the app routing Gateway API implementation does **not** use canary revisions for minor version upgrades. Upgrades happen in-place. The HPA and PDB on each Gateway minimize disruptions, but plan accordingly for production workloads. If your cluster has a [maintenance window](https://learn.microsoft.com/azure/aks/planned-maintenance) configured, in-place upgrades of the `istiod` deployment will respect it.

:::

## Current limitations

- **DNS and TLS certificate management** via the app routing add-on is not yet supported for Gateway API, and won't be until the feature reaches GA. This is a meaningful difference from the existing NGINX-based add-on, which automates Key Vault and Azure DNS integration through `az aks approuting update` and `az aks approuting zone add`. In the meantime, TLS termination is possible but requires manual setup — see [Secure ingress traffic with the application routing Gateway API implementation](https://learn.microsoft.com/azure/aks/app-routing-gateway-api-tls) for steps.
- **SNI passthrough** (`TLSRoute`) and **egress traffic management** are not supported.
- **Mutually exclusive** with the Istio service mesh add-on — the two cannot run simultaneously.

## Next steps

- **Try it**: Follow the [application routing Gateway API quickstart](https://learn.microsoft.com/azure/aks/app-routing-gateway-api).
- **Secure it**: Configure [TLS termination with Azure Key Vault](https://learn.microsoft.com/azure/aks/app-routing-gateway-api-tls).
- **Share feedback**: Open an issue in [AKS GitHub Issues](https://github.com/Azure/AKS/issues).
