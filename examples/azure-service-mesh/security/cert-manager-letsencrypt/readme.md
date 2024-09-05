# Cert-Manager Let's Encrypt Integration with Istio-based service mesh add-on

This document contains instructions on how to integrate Istio-based service mesh add-on for AKS with cert-manager and obtain let's encrypt certificates for setting up secure ingress gateways. 

## Objectives
* Deploy bookinfo demo app, expose a secure HTTPS service using simple TLS.
* Demonstrate HTTPS connections for Azure Service Mesh workloads using cert-manager and let's encrypt as the certificate authority.

## Before you begin
* [Install](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-addon#install-istio-add-on) Istio-based service mesh add-on on your cluster.
```shell
az aks mesh enable -g <rg-name> -n <cluster-name>
```
* [Enable external ingressgateway](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-ingress#enable-external-ingress-gateway)
```shell
az aks mesh enable-ingress-gateway -g <rg-name> -n <cluster-name> --ingress-gateway-type external
```
* [Enable sidecar injection](https://learn.microsoft.com/en-us/azure/aks/istio-deploy-addon#enable-sidecar-injection) on the default namespace. 
```shell
revision=$(az aks show --resource-group <rg-name> --name <cluster-name> --query 'serviceMeshProfile.istio.revisions[0]' -o tsv)
kubectl label namespace default istio.io/rev=$revision
```

## Steps
### 1. Setup DNS record
Set up a DNS record for the `EXTERNAL-IP` address of the external ingressgateway service with your cloud provider. In this example, we are setting up the DNS record for `4.153.8.39` with `test.dev.azureservicemesh.io`.

Run the following command to retrieve the external IP address of the ingress gateway:
```shell
kubectl get svc -n aks-istio-ingress
```

```console
NAME                                TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   10.0.59.31   4.153.8.39    15021:30786/TCP,80:30626/TCP,443:30236/TCP   8m44s
```

Verify/wait until `dig +short A test.dev.azureservicemesh.io` returns the configured IP address that is `4.153.8.39` in this example.

### 2. Install demo app
```shell
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/bookinfo/platform/kube/bookinfo.yaml
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
### 3. Configure ingress gateway and virtual service
Before deploying the `virtualservice` and `gateway` resources, make sure to update the host name to match your own DNS name.
```shell
kubectl apply -f gateway.yaml
kubectl apply -f virtualservice.yaml
```

> [!NOTE]  
> In the gateway definition, `credentialName` must match the `secretName` in the `certificate` resource which will be created later in the example and selector must refer to the external ingress gateway by its label, in which the key of the label is `istio` and the value is `aks-istio-ingressgateway-external`.

### Validate http request to productpage service

Send an HTTP request to access the productpage service
```shell
curl -vs http://test.dev.azureservicemesh.io/productpage | grep -o "<title>.*</title>"
```

this should print `<title>Simple Bookstore App</title>`

### 4. Create the shared configmap
Create a ConfigMap with the name `istio-shared-configmap-<asm-revision>` in the `aks-istio-system` namespace to set `ingressService` and `ingressSelector`. For example, if your cluster is running asm-1-21 revision of mesh, then the ConfigMap needs to be named as istio-shared-configmap-asm-1-21. Mesh configuration has to be provided within the data section under mesh.

```shell
kubectl apply -f configmap.yaml
```

> [!Note]  
> Kubernetes ingress for Istio-based service mesh is an `allowed` feature. More details on configuration options [here](https://learn.microsoft.com/en-us/azure/aks/istio-support-policy#allowed-supported-and-blocked-customizations)  
> cert-manager is not supported by Microsoft, more info can be found [here](https://cert-manager.io/)

### 5. Install cert-manager
```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.2/cert-manager.yaml
```
this installs cert-manager in its own namespace `cert-manager`

#### Validate cert-manager pods
```shell
kubectl get po -n cert-manager
```
```console
NAME                                     READY   STATUS    RESTARTS   AGE
cert-manager-6fd987499c-xmf44            1/1     Running   0          72s
cert-manager-cainjector-5b94bd6f-jw644   1/1     Running   0          72s
cert-manager-webhook-575479ff47-d87pf    1/1     Running   0          72s
```

### 6. Setup cluster-issuer and Certificate resources
Set your email address in `cluster-issuer.yaml` that you'd like to register with ACME server.
```shell
kubectl apply -f cluster-issuer.yaml
kubectl apply -f certificate.yaml
```
This should create k8s secret `bookinfo-certs` in `aks-istio-ingress` ns as requested by the certificate resource created above.

```shell
kubectl get secret -n aks-istio-ingress
```

```console
NAME                                                                TYPE                 DATA   AGE
bookinfo-certs                                                      kubernetes.io/tls    2      70s
sh.helm.release.v1.asm-igx-aks-istio-ingressgateway-external.v112   helm.sh/release.v1   1      3m19s
sh.helm.release.v1.asm-igx-aks-istio-ingressgateway-external.v113   helm.sh/release.v1   1      80s
```

### Validate https request to productpage service
Verify that the productpage can be accessed via the HTTPS endpoint

```shell
curl -v https://test.dev.azureservicemesh.io/productpage | grep -o "<title>.*</title>"
```
this should print `<title>Simple Bookstore App</title>`

## Troubleshooting
1. Verify that the DNS record has propagated
```dig +short A test.dev.azureservicemesh.io``` should return the configured ip address ```4.153.8.39``` in the example.

2. Check certificate resource readiness.
```shell
kubectl get certificate -n aks-istio-ingress
```
```console
NAME                         READY   SECRET           AGE
bookinfo-letsencrypt-certs   False   bookinfo-certs   2m5s
```
In case certificate resource is not ready as above, check the resources provisioned by cert-manager in order to solve the ACME challenge. Below is the chain of resources created by cert-manager.

```shell
kubectl describe certificate bookinfo-letsencrypt-certs -n aks-istio-ingress
```
```console
Name:         bookinfo-letsencrypt-certs
Namespace:    aks-istio-ingress
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
...
Events:
  Type    Reason     Age   From                                       Message
  ----    ------     ----  ----                                       -------
  Normal  Issuing    14m   cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal  Generated  14m   cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "bookinfo-letsencrypt-certs-hpjst"
  Normal  Requested  14m   cert-manager-certificates-request-manager  Created new CertificateRequest resource "bookinfo-letsencrypt-certs-1"
```

3. Check certificaterequest resource readiness.
```shell
kubectl describe certificaterequest bookinfo-letsencrypt-certs-1 -n aks-istio-ingress
```
```console
Name:         bookinfo-letsencrypt-certs-1
Namespace:    aks-istio-ingress
Labels:       <none>
Annotations:  cert-manager.io/certificate-name: bookinfo-letsencrypt-certs
              cert-manager.io/certificate-revision: 1
              cert-manager.io/private-key-secret-name: bookinfo-letsencrypt-certs-hpjst
API Version:  cert-manager.io/v1
Kind:         CertificateRequest
...
Events:
  Type    Reason              Age    From                                                Message
  ----    ------              ----   ----                                                -------
  Normal  WaitingForApproval  6m57s  cert-manager-certificaterequests-issuer-selfsigned  Not signing CertificateRequest until it is Approved
  Normal  WaitingForApproval  6m57s  cert-manager-certificaterequests-issuer-vault       Not signing CertificateRequest until it is Approved
  Normal  WaitingForApproval  6m57s  cert-manager-certificaterequests-issuer-venafi      Not signing CertificateRequest until it is Approved
  Normal  WaitingForApproval  6m57s  cert-manager-certificaterequests-issuer-acme        Not signing CertificateRequest until it is Approved
  Normal  WaitingForApproval  6m57s  cert-manager-certificaterequests-issuer-ca          Not signing CertificateRequest until it is Approved
  Normal  cert-manager.io     6m57s  cert-manager-certificaterequests-approver           Certificate request has been approved by cert-manager.io
  Normal  OrderCreated        6m57s  cert-manager-certificaterequests-issuer-acme        Created Order resource aks-istio-ingress/bookinfo-letsencrypt-certs-1-507153367
  ```

4. Check order resource readiness.
```shell
kubectl describe order bookinfo-letsencrypt-certs-1-507153367 -n aks-istio-ingress
```
```console
Name:         bookinfo-letsencrypt-certs-1-507153367
Namespace:    aks-istio-ingress
Labels:       <none>
Annotations:  cert-manager.io/certificate-name: bookinfo-letsencrypt-certs
              cert-manager.io/certificate-revision: 1
              cert-manager.io/private-key-secret-name: bookinfo-letsencrypt-certs-hpjst
...
Events:
  Type    Reason   Age   From                 Message
  ----    ------   ----  ----                 -------
  Normal  Created  11m   cert-manager-orders  Created Challenge resource "bookinfo-letsencrypt-certs-1-507153367-692923294" for domain "test.dev.azureservicemesh.io"
```

5. Check challenge resource readiness.
```shell
kubectl describe challenge bookinfo-letsencrypt-certs-1-507153367-692923294 -n aks-istio-ingress
```
```console
Name:         bookinfo-letsencrypt-certs-1-507153367-692923294
Namespace:    aks-istio-ingress
Labels:       <none>
Annotations:  <none>
API Version:  acme.cert-manager.io/v1
Kind:         Challenge
...
Status:
  Presented:   true
  Processing:  true
  Reason:      Waiting for HTTP-01 challenge propagation: wrong status code '404', expected '200'
  State:       pending
Events:
  Type    Reason     Age   From                     Message
  ----    ------     ----  ----                     -------
  Normal  Started    16m   cert-manager-challenges  Challenge scheduled for processing
  Normal  Presented  15m   cert-manager-challenges  Presented challenge using HTTP-01 challenge mechanism
```
Status: You can refer to the 'Reason' field to further diagnose the root cause.  

In the above example, HTTP-01 challenge propagation failed as `test.dev.azureservicemesh.io/.well-known/acme-challenge/hGsAXbL_uHSCL2tAvkh34d0AUmwuCfAge-ThVX0QfIA` could not be resolved and resulted in `404` instead of `200`.

6. Check ingress resource.
cert-manager configures an ingress resource, sets up a node port service automatically to route the ACME challenge requests.
```shell
kubectl describe ing -n aks-istio-ingress
```
```console
Name:             cm-acme-http-solver-2lczl
Labels:           acme.cert-manager.io/http-domain=2715880231
                  acme.cert-manager.io/http-token=1047727680
                  acme.cert-manager.io/http01-solver=true
Namespace:        aks-istio-ingress
Address:          
Ingress Class:    istio
Default backend:  <default>
Rules:
  Host                          Path  Backends
  ----                          ----  --------
  test.dev.azureservicemesh.io  
                                /.well-known/acme-challenge/hGsAXbL_uHSCL2tAvkh34d0AUmwuCfAge-ThVX0QfIA   cm-acme-http-solver-sddqg:8089 (10.244.0.24:8089)
Annotations:                    nginx.ingress.kubernetes.io/whitelist-source-range: 0.0.0.0/0,::/0
Events:                         <none>
```

Once the certificate has been served, all temporary resources are cleaned up automatically.