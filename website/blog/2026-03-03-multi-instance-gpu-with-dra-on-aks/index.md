---
title: "Running more with less: Multi-instance GPU (MIG) with Dynamic Resource Allocation (DRA) on AKS"
date: "2026-03-03"
description: "Learn how to use DRA to allocate right-sized GPU node partitions for your GPU-accelerated workloads on Azure Kubernetes Service (AKS)"
authors: ["sachi-desai", "jack-jiang"]
tags: ["gpu", "performance", "operations"]
---

GPUs power a wide range of production Kubernetes workloads across industries. For example, media platforms rely on them for video encoding/transcoding, financial services firms run quantitative risk simulations, and research groups process and visualize large datasets. In each of these scenarios, GPUs significantly improve job throughput, yet individual workloads often consume only a portion of the available device.

By default, Kubernetes schedules GPUs as entire units; when a workload requires only a fraction of a GPU, the remaining capacity can remain unused. Over time, this leads to lower hardware utilization and higher infrastructure costs within a cluster.

Multi-instance GPU (MIG) combined with dynamic resource allocation (DRA) helps address this challenge. MIG partitions a physical GPU into isolated instances with dedicated compute and memory resources, while DRA enables those instances to be provisioned and bound dynamically through Kubernetes resource claims. Rather than treating a GPU as an indivisible resource, the cluster can allocate right-sized GPU paritions to multiple workloads at the same time!

<!-- truncate -->

:::note
To learn more about dynamic resource allocation on AKS, visit our previous blog on getting started with NVIDIA GPU Operator: https://blog.aks.azure.com/2025/11/17/dra-devices-and-drivers-on-kubernetes)
:::

In this post, we walk through how to configure MIG with the NVIDIA GPU Operator on AKS, enable the NVIDIA DRA driver, define the necessary Kubernetes resource abstractions, and deploy a workload that consumes a MIG-backed GPU instance.

## Prepare your AKS cluster

Starting with your AKS cluster running *Kubernetes version `1.34` or above*, you can confirm whether DRA is enabled on your cluster by looking for `deviceclasses` and `resourceslices`.

Check `deviceclasses` via `kubectl get deviceclasses` or check `resourceslices` via `kubectl get resourceslices`.

At this point, the results for both commands should look similar to:

```output
No resources found
```

If DRA isn't enabled on your cluster (for example, if it is running an earlier Kubernetes version than `1.34`), you may instead see an error like:

```output
error: the server doesn't have a resource type "deviceclasses"/"resourceslices"
```

### Set up NVIDIA GPU Operator

We’ll leverage the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html) manage the driver lifecycle. When creating the GPU node pool, specify `--gpu-driver none` to prevent preinstalled drivers from conflicting with the operator-managed stack and ensure consistent configuration across nodes.

Next, install the NVIDIA GPU Operator with MIG enabled and the legacy Kubernetes device plugin disabled. We consolidate these configuration settings in a YAML file named `operator-install.yaml` as follows:

```bash
mig:
  strategy: single
devicePlugin:
 enabled: false
driver:
   enabled: true
toolkit:
   env:
     # Limits containers running in unprivileged mode from requesting access to arbitrary GPU devices 
     - name: ACCEPT_NVIDIA_VISIBLE_DEVICES_ENVVAR_WHEN_UNPRIVILEGED
       value: "false"
```

Note: In this setup, the traditional NVIDIA device plugin is purposely disabled so that GPU resources are not managed through the static model. Instead, the NVIDIA DRA driver serves as the authority for device discovery, enabling dynamic, claim-based management of MIG-backed GPU resources.

The single strategy partitions each GPU into uniform partitions. After preparing and saving the configuration file, install the operator with Helm:

```bash
$ helm install --wait \
--generate-name -n gpu-operator \
--create-namespace nvidia/gpu-operator \
--version=v25.10.0 \
-f operator-install.yaml
```

Now, the operator has installed the GPU driver, configured single-strategy MIG, and prepared the node pool for GPU partitioning.

## Install the NVIDIA DRA driver

DRA introduces a more flexible device management model in Kubernetes; instead of statically advertising a fixed number of GPUs, DRA allows workloads to create and bind resource claims dynamically.

The NVIDIA DRA driver installation enables GPU resources and points to the driver root managed by the operator, as shown in the following configuration file named `dra-install.yaml`:

```bash
gpuResourcesEnabledOverride: true
 resources-computeDomains:
   enabled: false # We'll be using GPUs, not compute domains.
 controller:
   affinity:
     nodeAffinity:
       requiredDuringSchedulingIgnoredDuringExecution:
         nodeSelectorTerms:
         - matchExpressions:
           - key: kubernetes.azure.com/mode
             operator: In
             values:
             - system   # Makes sure system nodes are utilized 
 nvidiaDriverRoot: "/run/nvidia/driver"
```

Using the above settings, install the NVIDIA DRA driver in a dedicated namespace:

```bash
helm install nvidia-dra-driver-gpu nvidia/nvidia-dra-driver-gpu \
--version="25.8.1" \
--create-namespace \ 
--namespace nvidia-dra-driver-gpu \
-f dra-install.yaml 
```

### Verify MIG configuration

Before scheduling workloads, confirm that the AKS node recognizes the GPU and that MIG is active. Inspecting the node should show that a GPU is present and that MIG capability and strategy are correctly applied. You should see indicators such as `nvidia.com/mig.capable=true` and `nvidia.com/mig.strategy=single`, along with a successful MIG configuration state.

```bash
kubectl describe node aks-gpunp-12340814-vmss000000 | grep "gpu"
Name:               aks-gpunp-12340814-vmss000000
                    agentpool=gpunp
                    kubernetes.azure.com/agentpool=gpunp
                    kubernetes.io/hostname=aks-gpunp-12340814-vmss000000
                    nvidia.com/gpu-driver-upgrade-state=upgrade-done
                    nvidia.com/gpu.compute.major=9
                    nvidia.com/gpu.compute.minor=0
                    nvidia.com/gpu.count=1 # GPUs are recognized
```


```bash
$ kubectl describe node aks-gpunp-12340814-vmss000000 | grep "mig"
                    nvidia.com/gpu.deploy.mig-manager=true
                    nvidia.com/mig.capable=true
                    nvidia.com/mig.config=all-disabled
                    nvidia.com/mig.config.state=success
                    nvidia.com/mig.strategy=single
```

Your AKS cluster should now be ready to expose MIG-enabled GPU partitions as dynamically allocatable devices!

## Define a DeviceClass

DRA introduces a `DeviceClass` abstraction that allows Kubernetes to select devices based on accelerator and characteristics. In this case, we define a class that selects NVIDIA GPUs:

```bash
apiVersion: resource.k8s.io/v1
kind: DeviceClass
metadata:
  name: nvidia-mig
spec:
  selectors:
  - cel:
      expression: "device.driver == 'gpu.nvidia.com'"
```

This definition tells AKS that any request referencing `nvidia-mig` should resolve to devices managed by the NVIDIA GPU driver.


```bash
kubectl get deviceclass
```

```output
NAME                                        AGE
compute-domain-daemon.nvidia.com            ...
compute-domain-default-channel.nvidia.com   ...
gpu.nvidia.com                              ...
mig.nvidia.com                              ... 
nvidia-mig                                  1m31s
```

## Create a MIG ResourceClaimTemplate

Instead of requesting `nvidia.com/gpu: 1` in a pod spec, workloads will now reference a `ResourceClaimTemplate`, which describes the device requirement declaratively. We'll apply a MIG `ResourceClaimTemplate` to the AKS cluster as follows:

```bash
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: mig-gpu-1g
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: nvidia-mig
          count: 1
```

This abstraction decouples workloads from physical device details. A job does not need to know which GPU or which partition it receives - it just declares its need for a device from the `nvidia-mig` class.

### Deploy a sample MIG workload

To validate the setup, we can deploy a GPU-accelerated workload requesting a MIG partition. Our example below uses a TensorFlow sample and generally mirrors how a data processing or video transcoding job can consume a resource partition in production environments:


```bash
apiVersion: batch/v1
kind: Job
metadata:
  name: samples-tf-mnist-demo
  labels:
    app: samples-tf-mnist-demo
spec:
  template:
    metadata:
      labels:
        app: samples-tf-mnist-demo
    spec:
      restartPolicy: OnFailure
      tolerations:
      - key: "sku"
        operator: "Equal"
        value: "gpu"
        effect: "NoSchedule"
      containers:
      - name: samples-tf-mnist-demo
        image: mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu
        imagePullPolicy: IfNotPresent
        args: ["--max_steps", "500"]
        resources:
          claims:
          - name: gpu
      resourceClaims:
      - name: gpu
        resourceClaimTemplateName: mig-gpu-1g
```

After deploying this job, we can check its status and the usage of the `mig-gpu-1g` resource claim template we previously created:

```bash
kubectl get Job 
```

```output
NAME                    STATUS    COMPLETIONS   DURATION   AGE
samples-tf-mnist-demo   Running   0/1           2m59s      2m59s
```

```bash
kubectl get resourceclaimtemplate
```

```output
NAME         AGE
mig-gpu-1g   11s
```

The key difference from traditional GPU scheduling is the use of `resources.claims` and `resourceClaimTemplateName`: Kubernetes coordinates with the DRA driver to provision and bind a MIG partition dynamically. Now when multiple jobs are submitted, each can receive its own isolated piece, allowing parallel execution on the same physical GPU.

## A more elastic GPU future on AKS

GPUs in Kubernetes have traditionally been scheduled as indivisible units. By enabling MIG and DRA on AKS, you move toward a model where accelerators are elastic, shareable, and first-class resources in the control plane. For organizations running parallel workloads that only partially utilize GPU capacity, this shift unlocks immediate cost efficiency and operational benefits.

If you are already operating GPU-enabled node pools on AKS and notice underutilization, implementing MIG with Dynamic Resource Allocation is a highly impactful architectural improvement you can make. It allows you to run more workloads on the same hardware while maintaining predictability and cloud-native operational simplicity.
