---
title: "Introducing Native Sidecar Support for Istio addon on AKS"
description: "Explore native sidecar support for the Istio add-on in Azure Kubernetes Service (AKS). Learn its benefits, how to enable it, and see a practical demo."
date: 2024-06-06
author: Fuyuan Bie
categories:
  - networking
  - addons
---

We're excited to announce the public preview of native sidecar support for Istio add-on for Azure Kubernetes Service (AKS). This blog post will guide you through the fundamentals of Kubernetes native sidecars, the integration of native sidecar support in Istio add-on, the benefits of this feature, how to enable it, and a demo showcasing its advantages.

## Understanding Kubernetes Native Sidecars

In Kubernetes, the sidecar pattern is used to extend the functionality of applications running in pods. Sidecar containers are responsible for auxiliary tasks such as logging, proxying, and monitoring. Typically, managing sidecar lifecycle required special configurations, which could be complex and error-prone. Developers must understand the lifecycle interactions of containers within a Kubernetes pod to avoid unexpected behaviors. They cannot safely assume that sidecars will be ready before their application or expect a specific shutdown order. Additionally, for jobs, the primary job container must terminate the sidecars.

Starting from Kubernetes v1.28, native sidecar support becomes a builtin feature. On AKS, starting from v1.29, this feature is turned on.

Read more about this feature from [Kubernetes blog](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/).

## Native Sidecar Support in Istio 1.20+

With the release of Istio 1.20, native sidecar support has been introduced, offering a streamlined approach to managing sidecar proxies. This integration reduces the overhead and complexity associated with sidecar injection, providing efficient management of sidecar life cycles.

Read more about Istio native sidecar support from [Istio blog](https://istio.io/latest/blog/2023/native-sidecars/).

## Where Native Sidecar Does not Help

While native sidecar support addresses many challenges, it does not assist with egress traffic as much as with ingress traffic. This is because within the lifecycle of a pod, application containers are terminated after sidecar containers, leaving no effective way to notify the application container that the pod is being terminated before the native sidecar is stopped. Consequently, in-flight egress traffic from the application container may experience disruptions during pod restarts.

## Try it out!

### Enabling Istio Native Sidecar Support in AKS

Since this is currently a preview feature, we need to follow [these instructions](https://learn.microsoft.com/azure/aks/istio-native-sidecar#before-you-begin) to register `IstioNativeSidecarModePreview` preview feature.

### Create an AKS cluster with Istio add-on

Create a new AKS cluster and connect to it. Kubernetes 1.29+ is required in order to enable the native sidecar feature.

```bash
az group create \
  --name native-sidecar-test-rg \
  --location eastus

az aks create \
  --resource-group native-sidecar-test-rg \
  --name native-sidecar-test \
  --kubernetes-version 1.29 \
  --enable-asm \
  --revision asm-1-21 \
  --location eastus

az aks get-credentials \
  --resource-group native-sidecar-test-rg \
  --name native-sidecar-test \
  --overwrite-existing
```

### Deploy a sample application

Let's deploy a sample application to test Istio native sidecar.

```bash
kubectl label namespace default istio.io/rev=asm-1-21 --overwrite
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/httpbin/httpbin.yaml
```
Wait for the pod to be in "Running" status then check application pod.

```bash
kubectl get pods -o "custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
```

We can see `istio-proxy` now becomes an init container. A native sidecar is an init container.

```text
NAME                      INIT                     CONTAINERS
httpbin-598f48c6d-nwx67   istio-init,istio-proxy   httpbin
```

### Experiment lifecycle management

One benefit of native sidecar support is that Kubernetes properly manages the sidecar lifecycle. Let's conduct an experiment to demonstrate this.

1. Restart application deployment

   ```bash
   kubectl rollout restart deployment httpbin
   ```

2. Check pod events and istio-proxy logs

   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   ```

   | LAST SEEN | TYPE | REASON | OBJECT | MESSAGE |
   |-----------|------|--------|--------|---------|
   | 2m39s | Normal | SuccessfulCreate | replicaset/httpbin-9c5fdf746 | Created pod: httpbin-9c5fdf746-hzmsf |
   | 2m39s | Normal | ScalingReplicaSet | deployment/httpbin | Scaled up replica set httpbin-9c5fdf746 to 1 |
   | 2m38s | Normal | Created | pod/httpbin-9c5fdf746-hzmsf | Created container istio-init |
   | 2m38s | Normal | Created | pod/httpbin-9c5fdf746-hzmsf | Created container istio-proxy |
   | 2m38s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container istio-proxy |
   | 2m38s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container istio-init |
   | 2m28s | Normal | Created | pod/httpbin-9c5fdf746-hzmsf | Created container httpbin | 
   | 2m28s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container httpbin |
   | 2m27s | Normal | Killing | pod/httpbin-598f48c6d-nwx67 | Stopping container istio-proxy |
   | 2m27s | Normal | SuccessfulDelete | replicaset/httpbin-598f48c6d | Deleted pod: httpbin-598f48c6d-nwx67 |
   | 2m27s | Normal | Killing | pod/httpbin-598f48c6d-nwx67 | Stopping container httpbin |

   We can see, when the pod starts, istio-proxy as an init container starts before the application container. It gives enough time for istio-proxy to warm up before serving traffic.

   Check sidecar logs.

   ```bash
   POD_ID=$(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
   kubectl logs $POD_ID -c istio-proxy
   ```

   Sidecar container istio-proxy used 9 seconds to get ready.

   ```text
   2024-06-04T05:07:02.138613Z    info    cache    returned workload trust anchor from cache    ttl=23h59m59.861388298s
   2024-06-04T05:07:10.904779Z    info    Readiness succeeded in 9.015247842s
   2024-06-04T05:07:10.905752Z    info    Envoy proxy is ready
   ```

   Events show application container was created 10 seconds after istio-proxy container was created. That is 1 second after the istio-proxy sidecar became ready.

   | LAST SEEN | TYPE | REASON | OBJECT | MESSAGE |
   |-----------|------|--------|--------|---------|
   | 2m38s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container istio-proxy |
   | 2m38s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container istio-init |
   | 2m28s | Normal | Created | pod/httpbin-9c5fdf746-hzmsf | Created container httpbin |
   | 2m28s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container httpbin |

   At the termination time, sidecar get killed before the application container.  This gives sidecar time to drain inflight traffic before terminating the application container.

   ```text
   2024-06-04T05:36:58.999684Z    info    handling /drain, starting drain
   2024-06-04T05:36:58.999753Z    info    Agent draining proxy
   2024-06-04T05:36:59.579419Z    info    Status server has successfully terminated
   2024-06-04T05:36:59.579514Z    info    Agent draining Proxy for termination
   2024-06-04T05:36:59.579521Z    info    Agent already drained, exiting immediately
   2024-06-04T05:36:59.579525Z    info    Agent has successfully terminated
   ```
   
   From events, we can see application container is killed after istio-proxy sidecar.

   | LAST SEEN | TYPE | REASON | OBJECT | MESSAGE |
   |-----------|------|--------|--------|---------|
   | 2m27s | Normal | Killing | pod/httpbin-598f48c6d-nwx67 | Stopping container istio-proxy |
   | 2m27s | Normal | SuccessfulDelete | replicaset/httpbin-598f48c6d | Deleted pod: httpbin-598f48c6d-nwx67 |
   | 2m27s | Normal | Killing | pod/httpbin-598f48c6d-nwx67 | Stopping container httpbin |

## Conclusion

The integration of native sidecar support in Istio 1.20 and its inclusion in the AKS Istio addon marks a significant advancement in simplifying and enhancing service mesh deployment and management. This feature provides substantial benefits, including improved performance, simplified configuration, and operational efficiency. We are committed to providing state-of-the-art features that empower our users to build resilient and scalable applications on AKS.

## Credits

This feature was made possible through the collaborative efforts of the AKS traffic team, the AKS Add-on team, and the Istio community. Special thanks to Niranjan Shankar, Shashank Barsin and all other AKS traffic team members for the collaboration; Robbie Zhang for the help given from AKS CCP and Add-on team; and Brian Redmond for his guidance on this blog and last but not least Paul Yu for the review.

If you have any question with regard to this preview feature, please leave us an issue here: https://github.com/Azure/AKS/issues.
