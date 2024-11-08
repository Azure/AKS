---
title: "Delve into Dynamic Resource Allocation, devices, and drivers on Kubernetes"
description: "An interactive and 'digestible' way to learn about DRA"
date: 2024-11-13
author: Sachi Desai
categories: ai
---

Dynamic Resource Allocation (DRA) is often mentioned in discussions about GPUs and specialized devices designed for high-performance AI and video processing jobs. But what exactly is it?

## Using GPUs in Kubernetes

Today, you need a few vendor-specific software components to even get started with a GPU node pool on Kubernetes - in particular, these are the Kubernetes device plugin and the GPU drivers. While the installation of GPU drivers makes sense, you might ask - why do we need a specific device plugin to be installed as well? 

Since Kubernetes does not have native support for special devices like GPUs, the device plugin surfaces and makes these resources available to your application. The device plugin works by exposing the number of GPUs on a node, by taking in a list of allocatable resources through the device plugin API and passing this to the kubelet. The kubelet then tracks this set and inputs the count of arbitrary resource type on the node to API Server, for kube-scheduler to use in pod scheduling decisions. 

![image](AKS/assets/images/dra-devices-drivers-on-kubernetes/device-plugin-diagram.png)

However, there are some limitations with this device plugin approach, namely:

1.	Granular selection of node resource type can only be made using several node attributes and labels
2.	Without a loopback mechanism, pods can be scheduled on “unprepared” nodes that aren’t ready to accept new resources

As a result, DRA was introduced to address some of these limitations, by ensuring applications receive an adequate number of resources at the right time. The [Dynamic Resource Allocation API](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) generalizes the Persistent Volumes API for generic resources, like GPUs. It allows for resource adjustment based on real-time demand and proper configuration without manual intervention.
> [!NOTE]
> Dynamic resource allocation is currently an **alpha feature** and only enabled when the *DynamicResourceAllocation* [feature gate](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/) and the *resource.k8s.io/v1alpha3* [API group](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups-and-versioning) are enabled.

## Let’s backtrack with a simpler scenario…I’m confused

Imagine that Kubernetes DRA is a working kitchen, and its staff is preparing a multi-course meal. In this example, the ingredients include:

* **Pods**: The individual dishes that need to be prepared
* **Nodes**: Various kitchen stations where the dishes are cooked
* **API Server**: The head chef, directing the entire operation
* **Scheduler**: The sous-chef, making sure each dish is cooked at the right station
* **Resource Quotas**: Portion sizes, ensuring each dish uses a specific amount of ingredients
* **Horizontal Pod Autoscaler (HPA)**: Dynamic serving staff, adjusting the number of dishes served based on customer demand

The instructions for this DRA recipe are then to:

1. **Prep**: Start by defining the recipes (Pods) and gathering all ingredients (resources like CPU and memory). Each recipe is assigned to a station (Node) by the head chef (API Server) through the sous-chef (Scheduler).
2. **Cooking**: The stations (Nodes) start cooking the dishes (Pods) as directed. The head chef ensures everything is progressing smoothly and the dishes are being prepared according to the recipes.
3. **Portion Control**: Use Resource Quotas to manage the portion sizes of each dish. This ensures that no single dish uses up too many ingredients, maintaining a balanced kitchen.
4. **Dynamic Serving**: The HPA acts like a waiter, monitoring the number of customers (resource usage metrics) and adjusting the number of dishes prepared (Pod count) dynamically. If more customers arrive, more dishes are prepared; if the demand decreases, fewer dishes are made.
5. **Serving the Meal**: The kitchen operates efficiently, with each dish receiving the right amount of attention and resources needed to ensure a delightful dining experience for the customers.

Just like in a restaurant kitchen, Kubernetes DRA makes sure your applications (dishes) get the right number of resources (ingredients) at the right time, providing an efficient resource management experience in the complex environment.

## Now, we can dig into the nitty-gritty

DRA involves several key components to efficiently manage resources within a cluster, shown in the following sample resource driver:

```bash
apiVersion: resource.k8s.io/v1alpha3
kind: DeviceClass
name: resource.example.com
spec:
  selectors:
  - cel:
      expression: device.driver == "resource-driver.example.com"
---
apiVersion: resource.k8s.io/v1alpha1
kind: ResourceClaimTemplate
metadata:
  name: gpu-template
spec:
  spec:
    resourceClassName: resource.example.com

–--
apiVersion: v1
kind: Pod
metadata:
  name: pod
spec:
  containers:
  - name: ctr0
    image: gpuDriverImage
    command: ["cmd0"]
    resources:
      claims:
      - name: gpu
  - name: ctr1
    image: gpuDriverImage
    command: ["cmd0"]
    resources:
      claims:
      - name: gpu
  resourceClaims:
  - name: gpu
    source:
      resourceClaimTemplate: gpu-template
```

*Adapted from: [DRA for GPUs in Kubernetes](https://docs.google.com/document/d/1BNWqgx_SmZDi-va_V31v3DnuVwYnF2EmN7D-O_fB6Oo/edit?tab=t.0)*

Here's what each of the components are:

| Component	| What does it do? |
| -- | -- |
| Resource Claims and Templates |	_ResourceClaim API_ allows workloads to request specific resources, such as GPUs, by defining their requirements and a _ResourceClaimTemplate_ helps in creating these claims automatically when deploying workloads |
| Device classes	| Predefined criteria for selecting and configuring devices. Each resource request references a _DeviceClass_ |
| Pod scheduling context	| Coordinates pod scheduling when _ResourceClaims_ need to be allocated and ensures that the resources requested by the pods are available and properly allocated |
| Resource slices	| Publish useful information about available CPU, GPU, memory resources in the cluster to help manage and track resource allocation efficiently |
| Control plane controller	| When the DRA driver provides a control plane controller, it handles the allocation of resources in cooperation with the Kubernetes scheduler. This ensures that resources are allocated based on structured parameters |

The example above demonstrates GPU sharing within a pod; two containers get access to one ResourceClaim object created for this pod.

The Kubernetes scheduler will try multiple times to identify the right node and let the DRA resource driver(s) know that the node is ready for resource allocation.
Then the _resourceClaim_ stages record that the resource has been allocated on a particular node, and the scheduler is signaled to run the pod. (This prevents pods from being scheduled onto “unprepared” nodes that cannot accept new resources.)
Leveraging the Named Resources model, the DRA resource driver can specify:

1.	How to get a hold of a specific GPU type, and 
2.	How to configure the GPU that has been allocated to a pod and assigned to a node.
   
In the place of arbitrary resource count, an entire object now represents the choice of resource. This object is passed to the scheduler at node start time and may stream updates if resources become unhealthy.

Now you might be wondering, how does the DRA resource driver interact with Kubernetes components other than the scheduler?

Let's take the cluster auto-scaler (CAS), for instance. CAS keeps up with application demands by “reading” the current cluster state to identify pending pods (those unable to be scheduled) due to resource constraints. Then, CAS determines if scaling up the number of nodes will help to get the pod scheduled and running. Through this existing model, CAS cannot “write” or interact with a resource driver to choose a specific type of node for this pod.
Thus, one of the jobs of the DRA resource driver is to “translate” the resource vendor’s parameters into Resource Claim built-in parameters that have a defined type supported by Kubernetes. (This does not introduce any changes to CAS or its current performance.)

Pulling this all together, the key components of DRA look like:

![image](AKS/assets/images/dra-devices-drivers-on-kubernetes/dra-driver-diagram.png)

## Seeing DRA in action

Now, let’s see how the [open-source k8s DRA driver](https://github.com/NVIDIA/k8s-dra-driver/tree/main) works with NVIDIA GPUs on an AKS cluster, specifically how it can provide:
* Exclusive access to a single GPU when multiple pods ask for it
* Shared access within a pod with multiple containers, and
* Shared access across pods requesting that single GPU.

> [!NOTE]
> This is an **experimental** demo; the open-source k8s DRA resource driver is under active development and not yet supported for production use on Azure Kubernetes Service.
