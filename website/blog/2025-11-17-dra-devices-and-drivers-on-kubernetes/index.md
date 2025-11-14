---
title: "Delve into Dynamic Resource Allocation, devices, and drivers on Kubernetes"
date: "2025-11-17"
description: "An interactive and 'digestible' way to learn about DRA, followed up with a practical example utilizing NVIDIA's DRA drivers"
authors:
- sachi-desai
- jack-jiang
tags: ["ai"]
---

Dynamic Resource Allocation (DRA) is often mentioned in discussions about GPUs and specialized devices designed for high-performance AI and video processing jobs. But what exactly is it?

<!-- truncate -->

## Using GPUs in Kubernetes

Today, you need a few vendor-specific software components to even get started with a GPU node pool on Kubernetes - in particular, these are the Kubernetes device plugin and the GPU drivers. While the installation of GPU drivers makes sense, you might ask - why do we need a specific device plugin to be installed as well?

Since Kubernetes does not have native support for special devices like GPUs, the device plugin surfaces and makes these resources available to your application. The device plugin works by exposing the number of GPUs on a node, by taking in a list of allocatable resources through the device plugin API and passing this to the kubelet. The kubelet then tracks this set and inputs the count of arbitrary resource type on the node to API Server, for kube-scheduler to use in pod scheduling decisions.

![image](device-plugin-diagram.png)

However, there are some limitations with this device plugin approach. It only allows GPUs to be statically assigned to a workload, without any ability for fine-grained sharing, partitioning, nor hot-swapping/reconfiguring of the GPUs.

The introduction of DRA provides a path to addressing some of these limitations, by ensuring resources can by dynamically categorized, requested, and used in a cluster. The [Dynamic Resource Allocation API](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) generalizes the Persistent Volumes API for generic resources, like GPUs. It allows for resource adjustment based on real-time demand and proper configuration without manual intervention.

NVIDIA's DRA driver extends this capability for their GPUs, introducing _GPUs_ and _ComputeDomains_ as two types of resources users can manage through DRA handles.

:::warning

Dynamic resource allocation is currently an **alpha feature** and only enabled when the _DynamicResourceAllocation_ [feature gate](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/) and the _resource.k8s.io/v1alpha3_ [API group](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups-and-versioning) are enabled.

:::

## Let’s backtrack with a simpler scenario… I’m confused

Imagine that Kubernetes DRA is a working kitchen, and its staff is preparing a multi-course meal. In this example, the ingredients include:

- **Pods**: The individual dishes that need to be prepared
- **Nodes**: Various kitchen stations where the dishes are cooked
- **API Server**: The head chef, directing the entire operation
- **Scheduler**: The sous-chef, making sure each dish is cooked at the right station
- **Resource Quotas**: Portion sizes, ensuring each dish uses a specific amount of ingredients
- **Horizontal Pod Autoscaler (HPA)**: Dynamic serving staff, adjusting the number of dishes served based on customer demand

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
  - name: container0
    image: gpuDriverImage
    command: ["cmd0"]
    resources:
      claims:
      - name: gpu
  - name: container1
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

_Adapted from: [DRA for GPUs in Kubernetes](https://docs.google.com/document/d/1BNWqgx_SmZDi-va_V31v3DnuVwYnF2EmN7D-O_fB6Oo/edit?tab=t.0)_

Here's what each of the components are:

| Component                     | What does it do?                                                                                                                                                                                                       |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Resource Claims and Templates | _ResourceClaim API_ allows workloads to request specific resources, such as GPUs, by defining their requirements and a _ResourceClaimTemplate_ helps in creating these claims automatically when deploying workloads   |
| Device classes                | Predefined criteria for selecting and configuring devices. Each resource request references a _DeviceClass_                                                                                                            |
| Pod scheduling context        | Coordinates pod scheduling when _ResourceClaims_ need to be allocated and ensures that the resources requested by the pods are available and properly allocated                                                        |
| Resource slices               | Publish useful information about available CPU, GPU, memory resources in the cluster to help manage and track resource allocation efficiently                                                                          |
| Control plane controller      | When the DRA driver provides a control plane controller, it handles the allocation of resources in cooperation with the Kubernetes scheduler. This ensures that resources are allocated based on structured parameters |

The example above demonstrates GPU sharing within a pod, where two containers get access to one ResourceClaim object created for the pod.

The Kubernetes scheduler will try multiple times to identify the right node and let the DRA resource driver(s) know that the node is ready for resource allocation.
Then the _resourceClaim_ stages record that the resource has been allocated on a particular node, and the scheduler is signaled to run the pod. (This prevents pods from being scheduled onto “unprepared” nodes that cannot accept new resources.)
Leveraging the Named Resources model, the DRA resource driver can specify:

1. How to get a hold of a specific GPU type, and
1. How to configure the GPU that has been allocated to a pod and assigned to a node.

In the place of arbitrary resource count, an entire object now represents the choice of resource. This object is passed to the scheduler at node start time and may stream updates if resources become unhealthy.

Pulling this all together, the key components of DRA look like:

![image](dra-driver-diagram.png)

## Vendor specific drivers

Vendors can provide driver packages that extend the base DRA capabilities to interact with their own resources. We will take a look at NVIDIA's [DRA drivers](https://github.com/NVIDIA/k8s-dra-driver-gpu), and explore how that allows for flexible and dynamic allocation of their GPUs.  

## Seeing NVIDIA's DRA driver in action

Now, let’s see how NVIDIA's [open-source k8s DRA driver](https://github.com/NVIDIA/k8s-dra-driver/tree/main) works on a Kubernetes cluster. We'll walk through:

1. Setting up your cluster and DRA drivers
1. Verifying your drivers are installed properly
1. Running a sample workload to illustrate a GPU being flexibly assigned

:::warning

The following is an **experimental** demo using an Azure Kubernetes Service cluster; the open-source k8s DRA resource driver is under active development and **not yet supported for production use**.

:::

### Before you begin

- If you don't have a cluster, create one using the [Azure CLI](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli), [Azure PowerShell](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-powershell), [Azure portal](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-portal?tabs=azure-cli), or IaaC tool of your choice. Here's an example of creating one using the Azure CLI. Note that the cluster should be on Kubernetes v.134 or later to have the DRA feature gate enabled.

   ```azurecli-interactive
   az aks create --name myAKSCluster --resource-group myResourceGroup --location <region>  --kubernetes-version 1.34
- Your GPU node pool should be provisioned with an [NVIDIA GPU enabled VM size](https://learn.microsoft.com/en-us/azure/aks/use-nvidia-gpu?tabs=add-ubuntu-gpu-node-pool#options-for-using-nvidia-gpus). 
   - Make sure you also [skip GPU driver installation](https://learn.microsoft.com/en-us/azure/aks/use-nvidia-gpu?tabs=add-ubuntu-gpu-node-pool#skip-gpu-driver-installation), as we install the drivers via the NVIDIA GPU operator in this tutorial.

   ```azurecli-interactive
   az aks nodepool add --cluster-name myAKSCluster --resource-group myResourceGroup --name gpunodepool  --node-count 1 --gpu-driver none --node-vm-size Standard_NC6s_v3 (or alternative NVIDIA GPU SKU)
   ```

### Get the credentials for your cluster

Get the credentials for your AKS cluster using the [`az aks get-credentials`](https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-get-credentials) command. The following example command gets the credentials for the _myAKSCluster_ in the _myResourceGroup_ resource group:

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### Verify DRA is enabled

You can confirm whether or not DRA is enabled on your cluster by checking `deviceclasses` and `resourceslices`.

Check `deviceclasses` via `kubectl get deviceclasses` or check `resourceslices` via `kubectl get resourceslices`.

The results for both should look similar to:

   ```bash
   No resources found
   ```

If DRA isn't enabled on your cluster, you may instead get a response similar to `error: the server doesn't have a resource type "deviceclasses"/"resourceslices"`.

### Install the NVIDIA GPU operator

Set up your GPU operator, ensure GPUs are schedulable, and GPU workloads can be run successfully.

> [!NOTE]
> Make sure you use a version of the GPU operator that matches or exceeds the version you specify when installing the DRA driver.

1. Install the GPU operator. We will be using the DRA drivers to manage our GPUs, so we also want to ensure we disable the Kubernetes device plugin during install. We will use an `operator-install.yaml` to parameters we'd like the operator to be installed with.

   - Create `operator-install.yaml` like so:

     ```yaml
     devicePlugin:
      enabled: false
     driver:
        enabled: true
      toolkit:
        env:
          # Limits containers running in _unprivileged_ mode from requesting access to arbitrary GPU devices 
          - name: ACCEPT_NVIDIA_VISIBLE_DEVICES_ENVVAR_WHEN_UNPRIVILEGED
            value: "false"
     ```

   - Install the GPU operator

       ```bash
       helm install --wait --generate-name -n gpu-operator \
       --create-namespace nvidia/gpu-operator \
       --version=v25.10.0 \
       -f operator-install.yaml
       ```

1. Make sure all your GPU operator components are running and ready via `kubectl get pod -n gpu-operator`. The result should look similar to:

    ```bash
    NAME                                                              READY   STATUS      RESTARTS   AGE
    gpu-feature-discovery-t9xs5                                       1/1     Running     0          2m9s
    gpu-operator-1761843468-node-feature-discovery-gc-6648dd8449tbx   1/1     Running     0          2m27s
    gpu-operator-1761843468-node-feature-discovery-master-597bhvwmm   1/1     Running     0          2m27s
    gpu-operator-1761843468-node-feature-discovery-worker-mvbbt       1/1     Running     0          2m27s
    gpu-operator-f8577988-p2k9x                                       1/1     Running     0          2m27s
    nvidia-driver-daemonset-tgf78                                     1/1     Running     0          1m30s
    nvidia-container-toolkit-daemonset-sqchb                          1/1     Running     0          2m10s
    nvidia-cuda-validator-f7g97                                       0/1     Completed   0          77s
    nvidia-dcgm-exporter-6lbxc                                        1/1     Running     0          2m9s
    nvidia-device-plugin-daemonset-v74ww                              1/1     Running     0          2m9s
    nvidia-mig-manager-jsnkr                                          1/1     Running     0          16s
    nvidia-operator-validator-h8s5n                                   1/1     Running     0          2m10s
    ```

## Installing NVIDIA DRA drivers

The recommended way to install the driver is via Helm. Ensure you have Helm updated to the [correct version](https://helm.sh/docs/topics/version_skew/#supported-version-skew).

1. Add the Helm chart that contains the DRA driver.

   ```azurecli-interactive
   helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
   ```

1. Create a `dra-install.yaml` to specify parameters during the installation.

   ```yaml
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

   1. Install the DRA driver.

   ```azurecli-interactive
   helm install nvidia-dra-driver-gpu nvidia/nvidia-dra-driver-gpu \
          # Ensure you select an appropriate version (https://github.com/NVIDIA/k8s-dra-driver-gpu/releases)
          --version="25.8.0" \
          --create-namespace \
          --namespace nvidia-dra-driver-gpu \
          -f dra-install.yaml \
   ```

### Verify your installation

Once setup, double check whether all DRA driver components are ready and running:

```bash
$ kubectl get pod -n nvidia-dra-driver-gpu
NAME                                               READY   STATUS    RESTARTS   AGE
nvidia-dra-driver-gpu-kubelet-plugin-[...]         1/1     Running   0          61m
```

`deviceclasses` and `resourceslices` should also recognize the new GPU devices. You can use `kubectl get deviceclasses` or `kubectl get resourceslices` to confirm.

### Run a GPU workload using DRA drivers

You can run some sample workloads to confirm that DRA drivers are installed and behave as expected.

1. Create a namespace that houses the resources for our sample workloads.

   ```bash
   kubectl create namespace dra-gpu-share-test
   ```

1. Create a new `ResourceClaimTemplate` that is used to create `ResourceClaims` of 1 GPU for associated workloads. Save this manifest as `my-rct.yaml`.

   ```yaml
   apiVersion: resource.k8s.io/v1
   kind: ResourceClaimTemplate
   metadata:
     namespace: dra-gpu-share-test
     name: single-gpu
   spec:
     spec:
       devices:
         requests:
         - name: gpu
           exactly:
             count: 1
             deviceClassName: gpu.nvidia.com
   ```

1. Create a pod manifest, `dra-rct-pod.yaml`, that takes advantage of our `ResourceClaimTemplate`. We spin up a pod that holds two containers, `ctr0` and `ctr1`. Both containers reference the same `ResourceClaim` and therefore share access to the same GPU device.

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     namespace: dra-gpu-share-test
     name: pod
     labels:
       app: pod
   spec:
     containers:
     - name: ctr0
       image: ubuntu:22.04
       command: ["bash", "-c"]
       args: ["nvidia-smi -L; trap 'exit 0' TERM; sleep 9999 & wait"]
       resources:
         claims:
         - name: shared-gpu
     - name: ctr1
       image: ubuntu:22.04
       command: ["bash", "-c"]
       args: ["nvidia-smi -L; trap 'exit 0' TERM; sleep 9999 & wait"]
       resources:
         claims:
         - name: shared-gpu
     resourceClaims:
     - name: shared-gpu
       resourceClaimTemplateName: single-gpu
     tolerations:
     - key: "nvidia.com/gpu"
       operator: "Exists"
       effect: "NoSchedule"
   ```

1. Fetch the containers' logs to check the GPU UUID for both containers

   ```bash
   kubectl logs pod -n dra-gpu-share-test --all-containers --prefix
   ```

1. The output should look similar to:

   ```bash
   [pod/pod/ctr0] GPU 0: NVIDIA H100 NVL (UUID: GPU-c552c7e1-3d44-482e-aaaf-507944ab75f7)
   [pod/pod/ctr1] GPU 0: NVIDIA H100 NVL (UUID: GPU-c552c7e1-3d44-482e-aaaf-507944ab75f7)
   ```

The results show us that the GPU UUID for both containers matches, confirming that both containers are accessing the same GPU device.

## Next steps

- Further validate your installation of the DRA drivers with [sample workloads](https://github.com/NVIDIA/k8s-dra-driver-gpu/wiki/Installation#validate-installation)
- Learn more about [NVIDIA DRA drivers](https://github.com/NVIDIA/k8s-dra-driver-gpu)

## Questions?

Connect with the AKS team through our [GitHub discussions](https://github.com/Azure/AKS/discussions) or [share your feedback and suggestions](https://github.com/Azure/AKS/issues).
