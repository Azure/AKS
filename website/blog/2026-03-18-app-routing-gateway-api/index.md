---
title: "Announcing Gateway API support for App Routing (preview)"
date: "2026-03-18"
description: "The AKS app routing add-on now supports the Kubernetes Gateway API via a meshless Istio control plane — the recommended path to migrate from Ingress-NGINX."
authors: ["jaiveer-katariya"]
tags:
  - app-routing
  - gateway-api
  - networking
  - istio
  - ingress-nginx
keywords: ["AKS", "Gateway API", "app routing", "Istio", "ingress", "NGINX", "Kubernetes"]
---

![Gateway API logo](https://gateway-api.sigs.k8s.io/images/logo/logo-text-horizontal.png)

We're announcing preview support for the **Kubernetes Gateway API** in the AKS application routing add-on. This brings a modern, role-oriented traffic management model to AKS — and establishes a clear migration path ahead of the [upcoming Ingress-NGINX retirement](#why-now-the-ingress-nginx-retirement).

<!-- truncate -->

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

| Feature | App routing Gateway API | Istio service mesh add-on |
|---|---|---|
| **GatewayClass** | `approuting-istio` | `istio` |
| **Sidecar injection** | Not enabled | Enabled cluster-wide |
| **Istio CRDs** | Not installed | Installed |
| **Upgrades** | In-place (minor and patch) | Canary upgrades for minor versions |

The two cannot run simultaneously — enabling one requires the other to be disabled first. If you want Gateway API based ingress on a full service mesh (mTLS between services, traffic policies, telemetry), use the Istio service mesh add-on. If you just wish to have ingress via the Gateway API without Istio-specific features, this is the right choice.

## Getting started

### Prerequisites

1. **`aks-preview` CLI extension**, version `19.0.0b26` or later:

    ```bash
    az extension add --name aks-preview
    az extension update --name aks-preview
    ```

2. **Preview feature flags** registered on your subscription:

    ```bash
    az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
    az feature register --namespace "Microsoft.ContainerService" --name "AppRoutingIstioGatewayAPIPreview"
    ```

### Enable the app routing Gateway API implementation

**On a new cluster:**

```bash
az aks create \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --enable-gateway-api \
  --enable-app-routing-istio
```

**On an existing cluster:**

```bash
az aks update \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --enable-gateway-api \
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
kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io httpbin-gateway --timeout=120s
export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -ojsonpath='{.status.addresses[0].value}')
```

Send a request to verify traffic is flowing:

```bash
curl -s -I -H "Host: httpbin.example.com" "http://$INGRESS_HOST/get"
```

You should see an `HTTP 200` response.

### Internal load balancer

By default, AKS assigns a public IP to the Gateway's underlying Service. To expose the existing `httpbin-gateway` on an internal (private) IP instead, add Azure load balancer annotations to the Gateway's `spec.infrastructure.annotations` field. You can also target a specific subnet for the internal IP address.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  gatewayClassName: approuting-istio
  infrastructure:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      # Optional: place the internal LB on a dedicated subnet
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "my-ilb-subnet"
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
```

AKS propagates these annotations onto the Kubernetes Service it creates for the Gateway. After the Gateway is programmed, its `status.addresses` will contain a private IP from the specified subnet (or the cluster's default subnet if the subnet annotation is omitted):

```bash
kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io internal-gateway --timeout=120s
kubectl get gateways.gateway.networking.k8s.io internal-gateway -ojsonpath='{.status.addresses[0].value}'
```

> **Note**: The subnet must exist in the cluster's virtual network and must be delegated or available for Azure Load Balancer use. See [Use an internal load balancer with AKS](https://learn.microsoft.com/azure/aks/internal-lb) for networking prerequisites.

Any annotation supported by the Azure load balancer controller can be used in `spec.infrastructure.annotations`. For the full list of supported annotations, see the [Azure load balancer annotations reference](https://learn.microsoft.com/azure/aks/load-balancer-standard#additional-customizations-via-kubernetes-annotations).

### Upgrades

The Istio control plane version is tied to your AKS cluster's Kubernetes version — AKS automatically reconciles the latest supported Istio revision that is compatible with your cluster's Kubernetes version. Patch version upgrades happen automatically as part of AKS releases. Minor version upgrades happen in-place when you upgrade your cluster's Kubernetes version, or automatically when a new Istio minor version is released for your AKS version. To see which Istio revision your cluster will receive, consult the [service mesh add-on release calendar](https://learn.microsoft.com/azure/aks/istio-support-policy#service-mesh-add-on-release-calendar). You can also follow the [AKS release notes](https://github.com/azure/aks/releases) to stay current.

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
