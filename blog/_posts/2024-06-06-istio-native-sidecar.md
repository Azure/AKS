---
title: "Introducing Native Sidecar Support for Istio addon on AKS"
description: "This blog talks about native sidecar support for Istio addon on AKS."
date: 2024-06-06
author: Fuyuan Bie
categories: mesh
---

## Overview

We're excited to announce the public preview of native sidecar support for Istio on Azure Kubernetes Service (AKS). This blog post will guide you through the fundamentals of Kubernetes native sidecars, the integration of native sidecar support in Istio 1.20 and beyond, the benefits of this feature, how to enable it, and a demo showcasing its advantages.

## Understanding Kubernetes Native Sidecars

In Kubernetes, the sidecar pattern is used to extend the functionality of applications running in pods. Sidecar containers are responsible for auxiliary tasks such as logging, proxying, and monitoring. Typically, managing sidecar lifecycle required special configurations, which could be complex and error-prone. Kubernetes native sidecar support addresses these challenges by making sidecar management a built-in feature, simplifying the process and enhancing reliability.

## Native Sidecar Support in Istio 1.20+

With the release of Istio 1.20, native sidecar support has been introduced, offering a streamlined approach to managing sidecar proxies. This integration reduces the overhead and complexity associated with sidecar injection, providing:

* Improved Performance: Optimized resource utilization and reduced latency.
* Simplified Configuration: Easier and more reliable configuration process.
* Operational Efficiency: Efficient management of sidecar lifecycles, including updates and scaling.

## Try it out!

### Enabling Istio Native Sidecar Support in AKS

Currently, native sidecar support is a preview feature on Istio addon for AKS.  To enable this feature, you need to explicitly enroll an Azure preview feature named `IstioNativeSidecarModePreview`. Once registered, all clusters under the current subscription will be using Istio native sidecar.

```bash
az feature register --namespace Microsoft.ContainerService --name IstioNativeSidecarModePreview
```

It will take a few minutes to finish registration. Run the following command to check registration status:

```bash
az feature show --namespace Microsoft.ContainerService --name IstioNativeSidecarModePreview
```

Once the registration status shows `Registered`, let's refresh feature registration for AKS.

```bash
az provider register --namespace Microsoft.ContainerService
```

### Create an AKS cluster with Istio add-on

```bash
az group create \
  --name native_sidecar_test_rg \
  --location eastus

az aks create \
  --resource-group native_sidecar_test_rg \
  --name native_sidecar_test \
  --kubernetes-version 1.29 \
  --enable-asm \
  --revision asm-1-21 \
  --location eastus

az aks get-credentials \
  --resource-group native_sidecar_test_rg \
  --name native_sidecar_test \
  --overwrite-existing
```

### Deploy a sample application

Let's deploy a sample application to test Istio native sidecar.
```bash
kubectl label namespace default istio.io/rev=asm-1-21 --overwrite
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/httpbin/httpbin.yaml
```

Check httpbin pod:

```bash
kubectl get pods -o "custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name"
```

We can see `istio-proxy` is an init container. A native sidecar is an init container.

```bash
NAME                      INIT                     CONTAINERS
httpbin-598f48c6d-nwx67   istio-init,istio-proxy   httpbin
```

### Experiment lifecycle management

One advantage of native sidecar is that the sidecar lifecyle is properly managed by Kubernetes. Let's do an experiment.

1. Restart httpbin deployment

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

   We can see, when the pod starts, istio-proxy as an init container starts before the application container. It gives enough time for istio-proxy to warm up before serving actual traffic.

   istio-proxy used 9 seconds to get ready.

   ```log
   2024-06-04T05:07:02.138613Z    info    cache    returned workload trust anchor from cache    ttl=23h59m59.861388298s
   2024-06-04T05:07:10.904779Z    info    Readiness succeeded in 9.015247842s
   2024-06-04T05:07:10.905752Z    info    Envoy proxy is ready
   ```

   Events show application container was created 10 seconds after istio-proxy container was created.

   | LAST SEEN | TYPE | REASON | OBJECT | MESSAGE |
   |-----------|------|--------|--------|---------|
   | 2m38s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container istio-proxy |
   | 2m38s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container istio-init |
   | 2m28s | Normal | Created | pod/httpbin-9c5fdf746-hzmsf | Created container httpbin |
   | 2m28s | Normal | Started | pod/httpbin-9c5fdf746-hzmsf | Started container httpbin |
   

   At the termination time, sidecar get killed before the application container.  This gives sidecar time to drain inflight traffic before terminating the application container.

   ```log
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

This feature is made possible through the collaborative efforts of the AKS traffic team, AKS Add-on team and the Istio community. Special thanks to Niranjan Shankar, Shashank Barsin, Dennis Menge.

For more detailed information, you can refer to the [Istio-based service mesh add-on for Azure Kubernetes Service](https://learn.microsoft.com/en-us/azure/aks/istio-native-sidecar). If you have any question with regard to this preview feature, please leave us an issue here: https://github.com/Azure/AKS/issues.

