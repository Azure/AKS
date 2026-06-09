---
title: "App Routing Gateway API is generally available"
date: "2026-06-08"
description: "The AKS App Routing Gateway API implementation is now GA, with Azure DNS and Azure Key Vault TLS integration via the App Routing operator along with access logging on gateway proxies."
authors: ["jaiveer-katariya"]
tags:
  - app-routing
  - gateway-api
  - networking
  - istio
  - dns
  - tls
keywords: ["AKS", "Gateway API", "App Routing", "Istio", "ExternalDNS", "Azure DNS", "Azure Key Vault", "TLS", "Kubernetes"]
image: ./Designer.png
---

The AKS application routing add-on's Kubernetes Gateway API implementation — `approuting-istio` — is **generally available**. Together with that, the **Managed Gateway API installation** for AKS is also GA, so the CRDs, the controller stack, and the gateway data plane you need to run Gateway API on AKS are all now first-class, supported features.

<!-- truncate -->

Since [our March preview announcement](/blog/2026/03/18/app-routing-gateway-api), we've also shipped tow of our most requested capabilities that gated a real production story for Gateway API on AKS:

- **Azure DNS and Azure Key Vault, wired in for you.** No more manually deploying a `SecretProviderClass`, a sync pod, or a separate `external-dns` instance just to get a TLS-terminated, DNS-resolvable hostname. Drop two `tls.options` on a listener, apply an `ExternalDNS` CR, and you're done.
- **Access logs, on out of the box.** Every gateway proxy writes a structured JSON access log line per request to stdout. `kubectl logs` the gateway deployment and you're already debugging — no `Telemetry` resource, no `EnvoyFilter`, no opt-in flag. This closes one of the last parity gaps with the nginx experience our users are accustomed to.

The rest of this post walks through both. We'll create a cluster, expose a sample app over the Gateway API, see access logs land on stdout, and then layer on DNS + TLS using the `ClusterExternalDNS` and `ExternalDNS` CRDs plus listener TLS options. A working DNS zone and Key Vault are part of the demo, so by the end you'll have HTTPS records resolving in a zone you own.

:::note Rollout

App Routing Istio and the Managed Gateway API installation both went GA as part of the **AKS 20260428 release**, which has rolled out to all regions — those features are available everywhere today. The DNS/TLS operator integration and access-logging-by-default ship with the **AKS 20260529 release**; track region-by-region progress on the [AKS release tracker](https://releases.aks.azure.com/AKSRelease).

:::

## What's new

### Access logs by default

Every Envoy gateway proxy that AKS provisions for your `Gateway` resources now writes one structured JSON access log line per request to its container log out of the box. The very first thing you can do once traffic flows is `kubectl logs` the gateway deployment and watch requests arrive. No Istio resources needed to manage it, and no opt-in flag. This brings the Gateway API experience closer to parity with the nginx-based experience our users are accustomed to.

### DNS and TLS integration via the App Routing operator

At preview, DNS and TLS automation was a major piece of the ingress-nginx experience the Gateway API path didn't match. That gap is now closed via two paths in the App Routing operator:

- **TLS** — A pair of listener `tls.options` keys (`kubernetes.azure.com/tls-cert-keyvault-uri` and `kubernetes.azure.com/tls-cert-service-account`) tell the operator to provision a `SecretProviderClass`, sync the certificate from Azure Key Vault as a `kubernetes.io/tls` Secret, and patch the listener's `certificateRefs` for you.
- **DNS** — Two CRDs, `ClusterExternalDNS` (cluster-scoped) and `ExternalDNS` (namespace-scoped), let you stand up an `external-dns` instance scoped to one or more Azure DNS zones and tell it to watch `Gateway`/`HTTPRoute`/`GRPCRoute` resources. Records appear automatically based on the hostnames on your routes.


## Demo: from cluster create to HTTPS-with-DNS

The rest of this post is a hands-on walkthrough that takes you through our newly-GA'd feautres along with the enhancements we're so excited about. To follow along you'll need:

- `azure-cli` `2.86.0` or later (`az --version` to check, `az upgrade` to update).
- An Azure subscription and resource group, plus permission to create resources in it.
- Sufficient Key Vault RBAC on your own Azure identity to create certificates — `Key Vault Certificates Officer` is the minimum, `Key Vault Administrator` is fine. Grant this on the vault you'll create in step 5b before running the cert-creation command.

Export these once and reuse them throughout:

```bash
export RESOURCE_GROUP=<your-resource-group>
export CLUSTER=<your-cluster-name>
export LOCATION=<your-azure-region>
```

### 1. Create the cluster (or update an existing one)

The three flags that matter are `--enable-app-routing-istio` (turns on the App Routing Gateway API implementation), `--enable-gateway-api` (installs the AKS-managed Gateway API CRDs), and `--enable-app-routing` (deploys the App Routing operator, which manages the DNS/TLS integration). All APIs are GA — no preview-feature registration and no `aks-preview` extension required.

**On a new cluster:**

```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER \
  --location $LOCATION \
  --enable-app-routing-istio \
  --enable-app-routing \
  --enable-gateway-api \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-addons azure-keyvault-secrets-provider
```

**On an existing cluster:**

```bash
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER \
  --enable-app-routing \
  --enable-app-routing-istio \
  --enable-gateway-api \
  --enable-oidc-issuer \
  --enable-workload-identity

# CSI addon needs its own command on existing clusters
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER \
  --addons azure-keyvault-secrets-provider
```

`--enable-oidc-issuer` and `--enable-workload-identity` are required for the DNS/TLS demo later — both DNS and TLS use Microsoft Entra Workload Identity to authenticate to Azure DNS and Key Vault. The `azure-keyvault-secrets-provider` addon installs the Secrets Store CSI Driver, which the operator uses to materialize Key Vault certificates as Kubernetes Secrets. Set them all now even if you don't have a workload to expose yet.

Pull credentials so `kubectl` works:

```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER
```

### 2. Confirm the control plane is up

The App Routing Gateway API implementation runs `istiod` in the `aks-istio-system` namespace.

```bash
kubectl get pods -n aks-istio-system
```

```output
NAME                      READY   STATUS    RESTARTS   AGE
istiod-54b4ff45cf-htph8   1/1     Running   0          3m15s
istiod-54b4ff45cf-wlvgd   1/1     Running   0          3m
```

You'll also see the `app-routing-system` namespace with NGINX still running:

```bash
kubectl get pods -n app-routing-system
```

You can ignore this for the rest of the demo. NGINX-by-default is on its way out as part of the [Ingress-NGINX retirement](/blog/2026/03/18/app-routing-gateway-api#why-now-the-ingress-nginx-retirement). Once we stop deploying it after November 2026, it won't appear for users by default.

The `approuting-istio` `GatewayClass` is what you'll target with your `Gateway` resources:

```bash
kubectl get gatewayclass approuting-istio
```

```output
NAME               CONTROLLER                    ACCEPTED   AGE
approuting-istio   istio.aks.azure.com/gateway-controller   True       4m
```

### 3. Expose a sample app via Gateway API

We'll deploy `httpbin`, front it with a single `Gateway` listener over plain HTTP, attach an `HTTPRoute`, and verify traffic flows. (We'll make this HTTPS in section 5.)

Deploy `httpbin` in the `default` namespace:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/httpbin/httpbin.yaml
```

Create the `Gateway` and `HTTPRoute`:

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

AKS provisions the Envoy `Deployment`, `Service`, `HorizontalPodAutoscaler`, and `PodDisruptionBudget` for the `Gateway` automatically. Wait for the Gateway to be programmed and grab its external IP:

```bash
kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io httpbin-gateway --timeout=120s
export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -ojsonpath='{.status.addresses[0].value}')
```

Send a request:

```bash
curl -s -I -H "Host: httpbin.example.com" "http://$INGRESS_HOST/get"
```

You should see an `HTTP/1.1 200 OK`.

### 4. See access logs on the gateway proxy

Each `Gateway` resource is backed by a managed `Deployment` named `<gateway-name>-approuting-istio`:

```bash
kubectl get deployment httpbin-gateway-approuting-istio
```

```output
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
httpbin-gateway-approuting-istio   2/2     2            2           1m
```

Tail its logs and re-issue a curl:

```bash
kubectl logs deploy/httpbin-gateway-approuting-istio --tail=20 -f
```

You should see an access log for each of your requests. That's the JSON-formatted Envoy access log written to stdout, on by default — useful for sanity checks, post-mortem analysis, or shipping into Azure Monitor / Log Analytics via the standard container log pipeline.

### 5. Add Azure DNS and TLS

Now for the best part (well, at least in my opinion). We'll create an Azure DNS zone we own, an Azure Key Vault with a real cert for a hostname in that zone, a user-assigned managed identity that can write to both, and then wire everything in via two CRDs and two listener `tls.options`.

For this demo we'll use the zone `ga-demo.dev` with two sub-hosts, `a.ga-demo.dev` and `b.ga-demo.dev`. Substitute your own zone name.

```bash
export ZONE_NAME=ga-demo.dev
export KV_NAME=approuting-ga-demo-kv  # must be globally unique
export UAMI_NAME=approuting-ga-demo-id
export SA_NAME=approuting-demo-sa
```

#### 5a. Create an Azure DNS zone

```bash
az network dns zone create --resource-group $RESOURCE_GROUP --name $ZONE_NAME
export ZONE_ID=$(az network dns zone show --resource-group $RESOURCE_GROUP --name $ZONE_NAME --query id -o tsv)
```

The zone's authoritative nameservers are listed under `az network dns zone show ... --query nameServers`. You can find this on the Azure portal too. If you're using a registrar-owned domain in production, you'd point the registrar at those NS records. But for a one-off demo, you can resolve through the zone NS directly with `dig @<ns> a.${ZONE_NAME}` which is what we'll do later to ensure our curl resolves correctly.

#### 5b. Create an Azure Key Vault and a self-signed wildcard cert

We'll mint a self-signed wildcard cert directly in Key Vault so it covers both `a.ga-demo.dev` and `b.ga-demo.dev` from a single certificate. (For production, import a CA-issued PFX with `az keyvault certificate import` instead.)

```bash
az keyvault create \
  --name $KV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization true

# Cert policy: wildcard subject + SAN so one cert covers every sub-host of the zone
cat > /tmp/cert-policy.json <<EOF
{
  "issuerParameters": { "name": "Self" },
  "keyProperties": { "exportable": true, "keyType": "RSA", "keySize": 2048, "reuseKey": false },
  "secretProperties": { "contentType": "application/x-pkcs12" },
  "x509CertificateProperties": {
    "subject": "CN=*.${ZONE_NAME}",
    "subjectAlternativeNames": { "dnsNames": ["*.${ZONE_NAME}", "${ZONE_NAME}"] },
    "validityInMonths": 12,
    "keyUsage": ["digitalSignature", "keyEncipherment"]
  }
}
EOF

az keyvault certificate create \
  --vault-name $KV_NAME \
  --name approuting-demo-cert \
  --policy @/tmp/cert-policy.json

# Capture the unversioned cert URI so the listener tracks rotations automatically
export CERT_URI=$(az keyvault certificate show \
  --vault-name $KV_NAME \
  --name approuting-demo-cert \
  --query id -o tsv | sed 's|/[^/]*$||')
echo "Cert URI: $CERT_URI"
```

#### 5c. Create a managed identity, role assignments, and federated credentials

Both the operator's DNS controller and the gateway listener's TLS sync authenticate to Azure as a user-assigned managed identity (UAMI), federated to a Kubernetes ServiceAccount via the cluster's OIDC issuer.

```bash
# 1. Create the UAMI
az identity create --resource-group $RESOURCE_GROUP --name $UAMI_NAME
export UAMI_CLIENT_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $UAMI_NAME --query clientId -o tsv)
export UAMI_PRINCIPAL_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $UAMI_NAME --query principalId -o tsv)

# 2. Grant DNS Zone Contributor on the zone, Key Vault Secrets User on the vault
az role assignment create \
  --assignee-object-id $UAMI_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "DNS Zone Contributor" \
  --scope $ZONE_ID

az role assignment create \
  --assignee-object-id $UAMI_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $(az keyvault show --name $KV_NAME --query id -o tsv)

export OIDC_ISSUER=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query oidcIssuerProfile.issuerUrl -o tsv)
```

We'll create the `app-a` and `app-b` namespaces now and federate the same UAMI to a `$SA_NAME` ServiceAccount in each. Federated credentials are subject-specific — each `(namespace, ServiceAccount)` pair needs its own:

```bash
for ns in app-a app-b; do
  kubectl create namespace $ns

  az identity federated-credential create \
    --identity-name $UAMI_NAME \
    --resource-group $RESOURCE_GROUP \
    --name approuting-demo-fic-$ns \
    --issuer $OIDC_ISSUER \
    --subject "system:serviceaccount:$ns:$SA_NAME" \
    --audiences "api://AzureADTokenExchange"

  kubectl apply -n $ns -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SA_NAME
  annotations:
    azure.workload.identity/client-id: $UAMI_CLIENT_ID
  labels:
    azure.workload.identity/use: "true"
EOF
done
```

The `azure.workload.identity/use: "true"` label is required — it's what tells the AKS Workload Identity webhook to inject the projected OIDC token volume and the `AZURE_*` env vars into pods that consume this SA. Without it, the operator's placeholder pod gets a default Kubernetes SA token instead of one signed by your cluster's OIDC issuer, and Entra rejects it with `AADSTS700211: No matching federated identity record`.

The same ServiceAccount drives both the DNS controller and the listener's TLS sync. One identity, two roles in Azure, one SA per namespace.

#### 5d. Deploy two gateways in two namespaces

Deploy `httpbin` in each namespace, then create one `Gateway` per namespace with an HTTPS listener pointing at the Key Vault cert URI and the SA. Each gateway covers its own sub-host:

```bash
for ns in app-a app-b; do
  kubectl apply -n $ns -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/httpbin/httpbin.yaml
done

for pair in "app-a:a" "app-b:b"; do
  ns=${pair%%:*}; sub=${pair##*:}
  fqdn=${sub}.${ZONE_NAME}
  kubectl apply -n $ns -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${sub}-gateway
  labels:
    app: approuting-demo
    zone: ${sub}
spec:
  gatewayClassName: approuting-istio
  listeners:
  - name: https
    hostname: $fqdn
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      options:
        kubernetes.azure.com/tls-cert-keyvault-uri: $CERT_URI
        kubernetes.azure.com/tls-cert-service-account: $SA_NAME
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${sub}-route
spec:
  parentRefs:
  - name: ${sub}-gateway
  hostnames: ["$fqdn"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
EOF
done
```

The TLS options tell the App Routing operator to:
1. Resolve `$CERT_URI` against the Key Vault, using the workload identity bound to `$SA_NAME` in the listener's namespace.
2. Provision a `SecretProviderClass` named `kv-gw-cert-<gateway>-<listener>`.
3. Sync the certificate as a `kubernetes.io/tls` Secret of the same name in the listener's namespace.
4. Patch the listener's `certificateRefs` to point at the Secret.

You can confirm the SPCs and Secrets exist:

```bash
kubectl get secretproviderclass,secret -n app-a
kubectl get secretproviderclass,secret -n app-b
```

#### 5e. Scenario A — `ClusterExternalDNS`: records for both gateways

`ClusterExternalDNS` is cluster-scoped: a single CR points at one or more Azure DNS zones and watches Gateway resources cluster-wide. The operator deploys an `external-dns` instance in the namespace named under `resourceNamespace`; the SA in that namespace authenticates to Azure DNS.

Apply it:

```bash
kubectl apply -f - <<EOF
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: ClusterExternalDNS
metadata:
  name: demo-cluster-dns
spec:
  resourceName: demo-cluster-dns
  resourceNamespace: app-a
  dnsZoneResourceIDs:
  - $ZONE_ID
  resourceTypes:
  - gateway
  identity:
    type: workloadIdentity
    serviceAccount: $SA_NAME
EOF
```

After a minute, both records show up in the zone:

```bash
az network dns record-set a list --resource-group $RESOURCE_GROUP --zone-name $ZONE_NAME -o table
```

```output
Name    ResourceGroup              Ttl    Type    AutoRegistered    Metadata
------  -------------------------  -----  ------  ----------------  --------
a       <your-rg>                  300    A       False
b       <your-rg>                  300    A       False
```

That's `ClusterExternalDNS`: one CR, one `external-dns` deployment, records for both gateways across both namespaces.

#### 5f. Scenario B — `ExternalDNS`: namespace-scoped, with label filtering

Now flip the model. Delete the `ClusterExternalDNS`:

```bash
kubectl delete clusterexternaldns demo-cluster-dns
```

To make the namespace + label scope concrete, deploy a **third** gateway in `app-a` labeled `zone=c`. We'll point a namespace-scoped `ExternalDNS` at it and watch a fresh record appear — without touching the existing `a` and `b` records:

```bash
kubectl apply -n app-a -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: c-gateway
  labels:
    app: approuting-demo
    zone: c
spec:
  gatewayClassName: approuting-istio
  listeners:
  - name: https
    hostname: c.${ZONE_NAME}
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      options:
        kubernetes.azure.com/tls-cert-keyvault-uri: $CERT_URI
        kubernetes.azure.com/tls-cert-service-account: $SA_NAME
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: c-route
spec:
  parentRefs:
  - name: c-gateway
  hostnames: ["c.${ZONE_NAME}"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /get
    backendRefs:
    - name: httpbin
      port: 8000
EOF
kubectl wait -n app-a --for=condition=programmed gateway c-gateway --timeout=240s
```

Now create a namespace-scoped `ExternalDNS` in `app-a` with a label filter for `zone=c`:

```bash
kubectl apply -n app-a -f - <<EOF
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: ExternalDNS
metadata:
  name: demo-ns-dns
spec:
  resourceName: demo-ns-dns
  dnsZoneResourceIDs:
  - $ZONE_ID
  resourceTypes:
  - gateway
  identity:
    type: workloadIdentity
    serviceAccount: $SA_NAME
  filters:
    gatewayLabels: "zone=c"
EOF
```

Two scoping rules apply at once:

1. **Namespace scope** — `ExternalDNS` only watches resources in its own namespace, so `b-gateway` in `app-b` is invisible to it.
2. **Label filter** — within `app-a`, only gateways carrying `zone=c` are picked up. The label key/value is rendered into the underlying `external-dns` controller's label selector.

After about a minute, a new `c` record appears alongside whatever was already there from the cluster-scoped run:

```bash
az network dns record-set a list --resource-group $RESOURCE_GROUP --zone-name $ZONE_NAME -o table
```

```output
Name    ResourceGroup              Ttl    Type    AutoRegistered    Metadata
------  -------------------------  -----  ------  ----------------  --------
a       <your-rg>                  300    A       False
b       <your-rg>                  300    A       False
c       <your-rg>                  300    A       False
```

The new namespace-scoped controller is responsible for `c` only. `a-gateway` (also in `app-a`) is excluded by the label filter; `b-gateway` is excluded by the namespace filter.

#### 5g. Verify HTTPS end-to-end

Grab the zone's authoritative nameserver, resolve the FQDN through it, and feed the result straight into `curl --resolve`. That keeps the test self-contained — you don't need the registrar pointing at Azure DNS or your local resolver to know about the zone:

```bash
NS=$(az network dns zone show --resource-group $RESOURCE_GROUP --name $ZONE_NAME --query 'nameServers[0]' -o tsv | sed 's/\.$//')
GATEWAY_IP=$(dig +short @${NS} a.${ZONE_NAME} | tail -1)
echo "Resolved a.${ZONE_NAME} -> $GATEWAY_IP via $NS"

# Self-signed cert, so -k. Use --cacert if you exported the chain.
curl -k -I --resolve "a.${ZONE_NAME}:443:${GATEWAY_IP}" "https://a.${ZONE_NAME}/get"
```

You should see `HTTP/2 200`. The certificate Envoy presents is the one synced from Key Vault — and re-tail the gateway deployment's logs (`kubectl logs deploy/a-gateway-approuting-istio -n app-a`) to see the access log line for the request.

## Next steps

- **Migrate**: If you're on the NGINX add-on, see the [Ingress to Gateway API migration guide](https://learn.microsoft.com/azure/aks/app-routing-nginx-to-gateway-api-migration). Managed NGINX support continues through November 2026.
- **Deepen**: The full reference docs are at [Configure ingress with the Kubernetes Gateway API](https://learn.microsoft.com/azure/aks/app-routing-gateway-api) and [Secure ingress with the application routing Gateway API implementation](https://learn.microsoft.com/azure/aks/app-routing-gateway-api-tls).
- **Track**: [AKS release tracker](https://releases.aks.azure.com/AKSRelease) and the [AKS release notes](https://github.com/Azure/AKS/releases).
- **Feedback**: Open an issue at [Azure/AKS issues](https://github.com/Azure/AKS/issues).
