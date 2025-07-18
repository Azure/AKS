# Kiali Dashboard Integration with Istio-based service mesh add-on for AKS

This document contains instructions on how to integrate Kiali dashboard with Istio-based service mesh add-on for Azure Kubernetes Service (AKS) to visualize and monitor your service mesh traffic.

## Objectives
* Deploy Kiali dashboard to visualize Istio service mesh traffic
* Configure Prometheus to collect metrics from Istio
* Set up external access to the Kiali dashboard
* Demonstrate traffic visualization for a sample application

> [!Note]  
> [Kiali](https://kiali.io/) is not officially supported by Microsoft, but can be used with AKS Istio add-on as a third-party integration.

## Before you begin
* [Set environment variables](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-addon#set-environment-variables)
    ```shell
    export CLUSTER=<cluster-name>
    export RESOURCE_GROUP=<resource-group-name>
    ```
* [Install](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-addon#install-istio-add-on) Istio-based service mesh add-on on your cluster.
    ```shell
    az aks mesh enable -g $RESOURCE_GROUP -n $CLUSTER
    ```
* [Enable external ingress gateway](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-ingress#enable-external-ingress-gateway)
    ```shell
    az aks mesh enable-ingress-gateway -g $RESOURCE_GROUP -n $CLUSTER --ingress-gateway-type external
    ```
* [Enable sidecar injection](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-addon#enable-sidecar-injection) on the default namespace. 
    ```shell
    revision=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query 'serviceMeshProfile.istio.revisions[0]' -o tsv)
    kubectl label namespace default istio.io/rev=$revision
    ```
* Install demo app
    ```shell
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/bookinfo/platform/kube/bookinfo.yaml
    ```

    Confirm several deployments and services are created on your cluster. For example:
    ```console
    service/details created
    serviceaccount/bookinfo-details created
    deployment.apps/details-v1 created
    service/ratings created
    serviceaccount/bookinfo-ratings created
    deployment.apps/ratings-v1 created
    service/reviews created
    serviceaccount/bookinfo-reviews created
    deployment.apps/reviews-v1 created
    deployment.apps/reviews-v2 created
    deployment.apps/reviews-v3 created
    service/productpage created
    serviceaccount/bookinfo-productpage created
    deployment.apps/productpage-v1 created
    ```
    ```shell
    kubectl get pods
    ```
    Ensure each pod has 2/2 containers in the `Ready` state
    ```console
    NAME                              READY   STATUS    RESTARTS   AGE
    details-v1-558b8b4b76-2llld       2/2     Running   0          2m41s
    productpage-v1-6987489c74-lpkgl   2/2     Running   0          2m40s
    ratings-v1-7dc98c7588-vzftc       2/2     Running   0          2m41s
    reviews-v1-7f99cc4496-gdxfn       2/2     Running   0          2m41s
    reviews-v2-7d79d5bd5d-8zzqd       2/2     Running   0          2m41s
    reviews-v3-7dbcdcbc56-m8dph       2/2     Running   0          2m41s
    ```

* Configure ingress gateway and virtual service
    ```shell
    kubectl apply -f gateway.yaml
    kubectl apply -f virtualservice.yaml
    ```
* Validate that the sample application is accessible.  
    ```shell
    # Set environment variables for external ingress host and ports:
    export INGRESS_HOST_EXTERNAL=$(kubectl -n aks-istio-ingress get service aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export INGRESS_PORT_EXTERNAL=$(kubectl -n aks-istio-ingress get service aks-istio-ingressgateway-external -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    export GATEWAY_URL_EXTERNAL=$INGRESS_HOST_EXTERNAL:$INGRESS_PORT_EXTERNAL
    ```
    Retrieve the external address of the sample application:
    ```shell
    echo "http://$GATEWAY_URL_EXTERNAL/productpage"
    ```
    Use `curl` to confirm the sample application is accessible:
    ```shell
    curl -s "http://${GATEWAY_URL_EXTERNAL}/productpage" | grep -o "<title>.*</title>"
    ```
    The expected output is:
    ```console
    <title>Simple Bookstore App</title>
    ```

## Steps

### Option 1: OSS Prometheus
- **Guide**: [oss-prometheus](oss-prometheus.md)

### Option 2: Azure Monitor Managed Prometheus
- **Guide**: [azure-managed-prometheus](azure-managed-prometheus.md)