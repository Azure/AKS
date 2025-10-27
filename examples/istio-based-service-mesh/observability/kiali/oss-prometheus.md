# Kiali with OSS Prometheus

This guide shows how to set up Kiali dashboard with OSS Prometheus for Istio service mesh visualization on AKS.

> [!Important]
> Complete the [prerequisites and setup](README.md) before following this guide.

## Deploy Kiali with OSS Prometheus

### 1. Deploy Prometheus for Kiali
Kiali requires Prometheus to collect and query metrics from your service mesh.

```shell
# Create a namespace for Prometheus
kubectl create namespace prometheus

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace prometheus \
  -f prometheus-values.yaml

# Verify the Prometheus pods are running
kubectl get pods -n prometheus
```

### 2. Install Kiali
> [!Important]
> This guide uses anonymous authentication for simplicity. For production deployments, implement appropriate authentication methods to secure your kiali dashboard from unauthorized access.
```shell
# Create namespace for Kiali
kubectl create namespace kiali-operator

# Add Kiali Helm repository (requires Helm 3)
helm repo add kiali https://kiali.org/helm-charts
helm repo update

# Install Kiali operator
helm install \
  --namespace kiali-operator \
  kiali-operator kiali/kiali-operator \
  -f kiali-values.yaml

# Wait for the Kiali operator to deploy Kiali
kubectl wait --for=condition=available deployment/kiali-operator -n kiali-operator --timeout=120s
sleep 30
kubectl wait --for=condition=available deployment/kiali -n kiali-operator --timeout=300s
```
```shell
# Check the Kiali CR exists:
kubectl get kialis -n kiali-operator  
```
```console
NAME    AGE
kiali   3m5s
```
```shell
#Verify all Kiali pods are running
kubectl get pods -n kiali-operator  
```
```console
NAME                              READY   STATUS    RESTARTS   AGE
kiali-6cf5bfd56d-2gmp4            1/1     Running   0          2m58s
kiali-operator-6cb48ccc78-lm8vp   1/1     Running   0          3m12s
```
### 3. Create an External Service for Kiali
Create a LoadBalancer service to access Kiali from outside the cluster:
```shell
kubectl apply -f kiali-external-service.yaml -n kiali-operator
```
Retrieve the external IP for Kiali:
```shell
kubectl get svc kiali-external -n kiali-operator

export KIALI_EXTERNAL_IP=$(kubectl get svc kiali-external -n kiali-operator -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```
```console
NAME            TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)      AGE
kiali-external  LoadBalancer   10.0.25.123   20.240.112.45   20001:32456/TCP   45s
```
You can now access the Kiali dashboard at ```http://${KIALI_EXTERNAL_IP}:20001```

### 4. Kiali Dashboard Visualization
#### Generate Traffic for Visualization
To visualize service mesh traffic in Kiali, you need to generate traffic to your application:
```shell
for i in {1..100}; do 
  curl -s "http://${GATEWAY_URL_EXTERNAL}/productpage" > /dev/null
  sleep 0.2
done
```

#### Kiali Dashboard
>[!Note]
>To learn about the full set of features supported by Kiali, see the [website](https://kiali.io/docs/features/)  

Navigate to ```http://${KIALI_EXTERNAL_IP}:20001``` in your browser to access the Kiali dashboard to visualize different aspects of your service mesh.   

![Kiali Dashboard showing mesh overview with namespaces and services](../../media/istio-addon-kiali-overview.png)

![Kiali Dashboard showing system components and their health status](../../media/istio-addon-kiali-integration.png)

![Kiali Dashboard showing detailed traffic flow graph between services](../../media/istio-addon-kiali-traffic-graph.png)

## Troubleshooting
### No traffic showing in Kiali graph
1. Verify that Prometheus is collecting Istio metrics:
    ```shell
    # Port forward to Prometheus UI
    kubectl port-forward svc/prometheus-server -n prometheus 9090:80
    ```
    Open ```http://localhost:9090``` in your browser and query ```istio_requests_total```. If data is present, Prometheus is collecting metrics correctly.

2. Check if your application pods have Istio sidecar injected:
    ```shell
    kubectl get pods -n default
    ```
    Each pod should show 2/2 containers (your application + istio-proxy).

3. Verify sidecar injection by checking for istio-proxy containers:
    ```shell
    kubectl get pods -n default -o jsonpath='{.items[*].spec.containers[*].name}' | grep istio-proxy
    ```

4. Check Kiali logs for any errors:
    ```shell
    kubectl logs -l app=kiali -n kiali-operator
    ```

### Kiali dashboard not accessible
If you can't access the Kiali dashboard through the external service:
1. Verify the external service is properly created:
    ```shell
    kubectl get svc kiali-external -n kiali-operator
    ```
2. Check if the service is properly selecting the Kiali pods:

    ```shell
    kubectl describe svc kiali-external -n kiali-operator
    ```

3. Try accessing Kiali through port-forwarding as an alternative:

    ```shell
    kubectl port-forward svc/kiali -n kiali-operator 20001:20001
    ```
    Then access Kiali at http://localhost:20001

## Clean up
To remove Kiali and its components:
```shell
# Delete the Kiali external service
kubectl delete service kiali-external -n kiali-operator

# Uninstall Kiali
helm uninstall kiali-operator -n kiali-operator
kubectl delete namespace kiali-operator

# Uninstall Prometheus
helm uninstall prometheus -n prometheus
kubectl delete namespace prometheus
```
