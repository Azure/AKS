---
title: "Deploying GPU workloads on AKS on bare metal"
date: 2026-06-09
description: "Run NVIDIA GPU workloads on AKS on bare metal using the NVIDIA GPU Operator, the preinstalled Azure Linux driver, and a sample CUDA workload."
authors: [pradeep-gayam]
tags: [aks-on-baremetal, gpu, ai, kubernetes]
---

AI and machine learning workloads are moving to the edge, and many customers already have NVIDIA GPU investments in their on-premises infrastructure that they want to put to work. With the recent [public preview of AKS on bare metal](/2026/06/02/aks-baremetal-public-preview), you can now run those GPU-accelerated applications on the same Kubernetes platform you use in Azure — right next to the data and applications they serve.

This post walks through deploying NVIDIA GPU workloads on AKS on bare metal: verifying the bundled driver, installing the NVIDIA GPU Operator, validating the install, and running a sample CUDA workload.

<!-- truncate -->

## NVIDIA driver and CUDA toolkit

AKS on bare metal ships with Azure Linux 3.0, which includes NVIDIA driver **580.105.08**. This driver branch (R580) supports NVIDIA data center GPUs from the Maxwell architecture onward (compute capability 5.0 and later), including the A100, A2, A10, A16, A30, T4, V100, L4, L40, H100, H200, and B200 families.

To verify that the bundled driver recognizes the installed GPU, run:

```bash
nvidia-smi
```

If the command completes without errors and lists your GPU, you're ready to deploy the GPU Operator. If the GPU isn't operational with the bundled driver, contact Microsoft Support.

## Deploying the NVIDIA GPU Operator

The [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) automates the deployment and lifecycle management of the NVIDIA software stack required to provision GPUs on Kubernetes, including the driver, the NVIDIA container toolkit, the NVIDIA device plugin, and node feature discovery.

Because the driver is already installed on the host, disable the Operator's automatic driver installation by setting `driver.enabled=false`. Deploy the Operator with Helm:

```bash
helm install --wait --generate-name \
    -n gpu-operator --create-namespace \
    nvidia/gpu-operator \
    --version=v26.3.2 \
    --set driver.enabled=false
```

This command deploys all the components required for running GPU workloads. Before moving on, confirm that every pod in the `gpu-operator` namespace is in the `Running` or `Completed` state:

```bash
kubectl get pods -n gpu-operator
```

## Validating the GPU Operator

Once all pods are healthy, inspect the logs of the `cuda-validation` init container in the `nvidia-operator-validator` pod to confirm that GPU workloads are schedulable:

```bash
kubectl logs -n gpu-operator -l app=nvidia-operator-validator -c cuda-validation
```

A successful run indicates that the driver, container toolkit, device plugin, and CUDA runtime are all working together on the node.

## Running a sample GPU workload

With the GPU Operator installed and validated, you can run GPU workloads on the cluster. For a lightweight check, NVIDIA publishes a set of [sample GPU workloads](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html#verification-running-sample-gpu-applications), including the CUDA vectorAdd test.

Alternatively, deploy the Microsoft TensorFlow MNIST sample (`mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu`), a short TensorFlow training job that trains a small model against the MNIST dataset on the GPU. This workload exercises image pull, GPU scheduling, dataset processing, and GPU-backed training in a single run. Follow the procedure in the [AKS GPU documentation](https://learn.microsoft.com/azure/aks/use-nvidia-gpu#run-a-gpu-enabled-workload).

Successful completion of the sample workload confirms that the AKS on bare metal cluster is ready for GPU-accelerated workloads.

## What's next

The same managed Kubernetes platform you use in the cloud now extends to GPU-equipped edge hardware. From here, you can layer on the broader AKS AI ecosystem — for example, see our companion series on [AI inference on AKS Arc](/2026/04/07/ai-inference-on-aks-arc-part-1) — to bring richer inference and training workflows to the edge.

To request access to AKS on bare metal, see the [public preview announcement](/2026/06/02/aks-baremetal-public-preview).
