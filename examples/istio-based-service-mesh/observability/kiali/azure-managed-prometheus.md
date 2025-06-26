# Kiali with Azure Monitor Managed Prometheus

This guide shows how to set up Kiali dashboard with Azure Monitor managed Prometheus for Istio service mesh visualization on AKS.

> [!Important]
> Complete the [prerequisites and setup](README.md) before following this guide.

## Set additional environment variables

```shell
export WORKSPACE_NAME=<your-azure-monitor-workspace-name>
export WORKSPACE_RESOURCE_ID=/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/microsoft.monitor/accounts/<workspace-name>

# Derived variables
export TENANT_ID=$(az account show --query tenantId -o tsv)
export CLIENT_ID=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER --query identityProfile.kubeletidentity.clientId -o tsv)
export PROMETHEUS_QUERY_ENDPOINT=$(az monitor account show --ids $WORKSPACE_RESOURCE_ID --query metrics.prometheusQueryEndpoint -o tsv)
export ISTIO_REVISION=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER --query serviceMeshProfile.istio.revisions[0] -o tsv)
export ISTIO_CONFIG_MAP=$(kubectl get configmap -n aks-istio-system -o name | grep "istio.*${ISTIO_REVISION}" | head -1 | cut -d'/' -f2)
export ISTIOD_DEPLOYMENT=$(kubectl get deployment -n aks-istio-system -o name | grep "istiod.*${ISTIO_REVISION}" | head -1 | cut -d'/' -f2)
export ISTIO_SIDECAR_INJECTOR_CM=$(kubectl get configmap -n aks-istio-system -o name | grep "sidecar-injector.*${ISTIO_REVISION}" | head -1 | cut -d'/' -f2)
export ISTIO_GATEWAY_NAME=$(kubectl get deployment -n aks-istio-ingress -o name | grep "ingressgateway.*${ISTIO_REVISION}" | head -1 | cut -d'/' -f2)
```

## Deploy Kiali with Azure Monitor Managed Prometheus

### Step 1: Enable Azure Monitor Managed Prometheus

Before setting up Kiali, ensure that Azure Monitor managed Prometheus is enabled for your AKS cluster:

```shell
# Create an Azure Monitor workspace if you don't have one
export LOCATION=$(az group show -n $RESOURCE_GROUP --query location -o tsv)

az monitor account create \
  --name $WORKSPACE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Enable Azure Monitor managed Prometheus on your AKS cluster
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id $WORKSPACE_RESOURCE_ID

# Verify the integration is enabled
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER \
  --query azureMonitorProfile

# Check that ama-metrics DaemonSet is running
kubectl get pods -n kube-system -l rsName=ama-metrics
```

## Step 1.1: Configure Prometheus Scrape Configuration

Configure Prometheus to scrape Istio workload metrics by creating a custom scrape configuration:

```shell
# Create Prometheus scrape configuration for Istio workloads
kubectl apply -f ama-metrics-prometheus-config.yaml

# Restart ama-metrics DaemonSet to pick up the new configuration
kubectl rollout restart deployment/ama-metrics -n kube-system
```

### Step 2: Install Kiali Operator

```shell
# Add Kiali Helm repository
helm repo add kiali https://kiali.org/helm-charts
helm repo update

# Install Kiali Operator
helm upgrade --install \
    --namespace kiali-operator \
    --create-namespace \
    kiali-operator \
    kiali/kiali-operator

# Wait for operator to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kiali-operator -n kiali-operator --timeout=300s
```

### Step 3: Deploy AAD Authentication Proxy

The [AAD Auth Proxy](https://github.com/Azure/aad-auth-proxy) handles authentication between Kiali and Azure Monitor:

```shell
# Create the namespace first
kubectl create namespace aad-auth-proxy-ns

# Deploy AAD auth proxy using the template file
envsubst < aad-auth-proxy-template.yaml | kubectl apply -f -
```

## Step 4: Configure Azure RBAC

Grant the managed identity access to Azure Monitor:

```shell
# Grant Monitoring Data Reader role to the managed identity
az role assignment create \
    --assignee $CLIENT_ID \
    --role "Monitoring Data Reader" \
    --scope $WORKSPACE_RESOURCE_ID

# Verify role assignment
az role assignment list --assignee $CLIENT_ID --scope $WORKSPACE_RESOURCE_ID
```

## Step 5: Validate AAD Auth Proxy Connection to Azure Monitor

Before deploying Kiali, validate that the AAD auth proxy can successfully query Azure Monitor:

```shell
# Wait for AAD auth proxy to be ready
kubectl wait --for=condition=available deployment/aad-auth-proxy -n aad-auth-proxy-ns --timeout=300s

# Test Azure Monitor connectivity through the proxy
kubectl port-forward -n aad-auth-proxy-ns svc/aad-auth-proxy 8082:80 &
PID=$!
sleep 5

# Validate the connection
curl -s "http://localhost:8082/api/v1/query?query=up" | jq '.'

# Clean up
kill $PID
```

## Step 6: Deploy Kiali Custom Resource

Create the [Kiali Custom Resource](https://kiali.io/docs/configuration/kialis.kiali.io/) with Azure Monitor integration:

```shell
# Deploy Kiali using the custom resource template
envsubst < kiali-cr.yaml | kubectl apply -f -
```

## Step 7: Create External Service for Kiali

Create a LoadBalancer service to access Kiali from outside the cluster:

```shell
kubectl apply -f kiali-external-service.yaml -n aks-istio-system
```

## Step 8: Wait for Deployment

Wait for all components to be ready:

```shell
# Wait for AAD Auth Proxy
kubectl wait --for=condition=available deployment/aad-auth-proxy -n aad-auth-proxy-ns --timeout=300s

# Wait for Kiali deployment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kiali -n aks-istio-system --timeout=300s

# Wait for LoadBalancer to get external IP
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/kiali-external -n aks-istio-system --timeout=300s
```

## Step 9: Create Service Account for Authentication

Create a service account and generate a token for Kiali access:

```shell
# Create service account
kubectl create serviceaccount kiali-dashboard -n aks-istio-system

# Create cluster role binding using the Kiali-provided viewer role
kubectl create clusterrolebinding kiali-dashboard \
    --clusterrole=kiali-viewer \
    --serviceaccount=aks-istio-system:kiali-dashboard

# Generate access token (valid for 24 hours)
TOKEN=$(kubectl create token kiali-dashboard -n aks-istio-system --duration=24h)
echo "Kiali Access Token: $TOKEN"
```

## Step 10: Access Kiali Dashboard

Get the external IP and access Kiali:

```shell
# Get external IP and display access information
EXTERNAL_IP=$(kubectl get service kiali-external -n aks-istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo "=== Kiali Access Information ==="
echo "URL: http://$EXTERNAL_IP:20001"
echo "Authentication: Select 'Token'"
echo "Token: $TOKEN"
echo ""
echo "Copy the token above and use it to log into Kiali"
```

## Step 11: Generate Traffic for Visualization
To visualize service mesh traffic in Kiali, you need to generate traffic to your application:
```shell
for i in {1..100}; do 
  curl -s "http://${GATEWAY_URL_EXTERNAL}/productpage" > /dev/null
  sleep 0.2
done
```

#### Kiali Dashboard
>[!Note]
To learn about the full set of features supported by Kiali, see the [website](https://kiali.io/docs/features/)  

Navigate to the Kiali dashboard URL to visualize different aspects of your service mesh.   

![Kiali Dashboard showing mesh overview with namespaces and services](../../media/istio-addon-kiali-overview.png)

![Kiali Dashboard showing system components and their health status](../../media/istio-addon-kiali-integration.png)

![Kiali Dashboard showing detailed traffic flow graph between services](../../media/istio-addon-kiali-traffic-graph.png)

## Troubleshooting
### AAD Auth Proxy fails to start
Check if CLIENT_ID is correct and verify role assignment:
```shell
# Check if CLIENT_ID is correct
az aks show -g $RESOURCE_GROUP -n $CLUSTER --query identityProfile.kubeletidentity.clientId -o tsv

# Verify role assignment
az role assignment list --assignee $CLIENT_ID --scope $WORKSPACE_RESOURCE_ID
```

### Kiali shows "No metrics available"
Verify auth proxy is working:
```shell
# Verify auth proxy is working
kubectl get pods -n aad-auth-proxy-ns -l app=aad-auth-proxy
kubectl logs -n aad-auth-proxy-ns deployment/aad-auth-proxy
```

### LoadBalancer stuck in pending
Check available public IPs or use port-forward as an alternative:
```shell
# Check available public IPs
NODE_RG=$(az aks show -g $RESOURCE_GROUP -n $CLUSTER --query nodeResourceGroup -o tsv)
az network public-ip list -g $NODE_RG

# Alternative: Use port-forward for testing
kubectl port-forward -n aks-istio-system svc/kiali 20001:20001
```

### Check logs for issues
```shell
# Kiali logs
kubectl logs -n aks-istio-system deployment/kiali -f

# AAD Auth Proxy logs
kubectl logs -n aad-auth-proxy-ns deployment/aad-auth-proxy -f

# Kiali Operator logs
kubectl logs -n kiali-operator deployment/kiali-operator -f
```

## Clean up

To remove all components:

```shell
# Remove Kiali external service
kubectl delete service kiali-external -n aks-istio-system

# Remove Kiali Custom Resource
kubectl delete kiali kiali -n aks-istio-system

# Remove AAD Auth Proxy
kubectl delete deployment aad-auth-proxy -n aad-auth-proxy-ns
kubectl delete service aad-auth-proxy -n aad-auth-proxy-ns
kubectl delete namespace aad-auth-proxy-ns

# Remove service account
kubectl delete serviceaccount kiali-dashboard -n aks-istio-system
kubectl delete clusterrolebinding kiali-dashboard

# Remove Kiali Operator
helm uninstall kiali-operator -n kiali-operator
kubectl delete namespace kiali-operator

# Remove Azure role assignment
az role assignment delete --assignee $CLIENT_ID --scope $WORKSPACE_RESOURCE_ID
```