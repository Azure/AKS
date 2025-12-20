---
title: "Autoscale KAITO inference workloads on AKS using KEDA"
date: "2025-12-11"
description: "Autoscale KAITO inference workloads dynamically to handle varying numbers of waiting inference service requests."
authors: ["andy-zhang", "sachi-desai"]
tags: ["ai", "kaito"]
---

## Overview

[Kubernetes AI Toolchain Operator](https://github.com/Azure/kaito/tree/main) (KAITO) is an operator that simplifies and automates AI/ML model inference, tuning, and RAG in a Kubernetes cluster. With the recent [v0.8.0 release](https://github.com/Azure/kaito/releases/tag/v0.8.0), KAITO has introduced intelligent autoscaling for inference workloads as an alpha feature! In this blog, we'll guide you through setting up event-driven autoscaling for vLLM inference workloads.

<!-- truncate -->

## Introduction

LLM inference service is a basic and widely-used feature in KAITO, as the number of waiting inference requests increases, it is necessary to scale more inference instances in order to prevent blocking inference requests. On the other hand, if the number of waiting inference requests declines, we should consider reducing inference instances to improve GPU resource utilization. Kubernetes Event-driven Autoscaling (KEDA) is a good fit for inference pod autoscaling since it enables event-driven, fine-grained scaling based on external metrics and triggers, it supports a wide range of event sources (like custom metrics), allowing pods to scale precisely in response to workload demand. This flexibility and extensibility make KEDA ideal for dynamic, cloud-native applications that require responsive and efficient autoscaling.

This blog outlines the steps to enable intelligent autoscaling based on the service monitoring metrics for KAITO inference workloads by using the following components and features:

- [Kubernetes-based Event Driven Autoscaling(KEDA)](https://github.com/kedacore/keda)

- [keda-kaito-scaler](https://github.com/kaito-project/keda-kaito-scaler)
  - A dedicated KEDA external scaler, eliminating the need for external dependencies such as Prometheus.
- KAITO `InferenceSet` Custom Resource Definition(CRD) and controller
  - This new CRD and controller were built on top of the KAITO workspace for intelligent autoscaling, introduced as an alpha feature in KAITO version `v0.8.0`

### Architecture

 ![keda-kaito-scaler-arch](keda-kaito-scaler-arch.png)

## Prerequisites

### Install KEDA

- option#1: enable managed KEDA addon
For instructions on enabling KEDA addon on AKS, you could refer to the guide [Install KEDA add-on on AKS](https://learn.microsoft.com/en-us/azure/aks/keda-deploy-add-on-cli)

- option#2: install KEDA using Helm chart

> The following example demonstrates how to install KEDA 2.x using Helm chart. For instructions on installing KEDA through other methods, please refer to the guide [deploying-keda](https://github.com/kedacore/keda#deploying-keda).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace kube-system
```

### Install keda-kaito-scaler

> Ensure that keda-kaito-scaler is installed within the same namespace as KEDA.

```bash
helm repo add keda-kaito-scaler https://kaito-project.github.io/keda-kaito-scaler/charts/kaito-project
helm upgrade --install keda-kaito-scaler -n kube-system keda-kaito-scaler/keda-kaito-scaler
```

After a few seconds, a new deployment `keda-kaito-scaler` would be started.

```bash
# kubectl get deployment keda-kaito-scaler -n kube-system
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
keda-kaito-scaler   1/1     1            1           28h
```

### Enable InferenceSet controller in KAITO

The InferenceSet CRD and controller were introduced as an **alpha** feature in KAITO version `v0.8.0`. Built on top of the KAITO workspace, InferenceSet supports the scale subresource API for intelligent autoscaling. To use InferenceSet, the InferenceSet controller must be enabled during the KAITO installation.

```bash
export CLUSTER_NAME=kaito

helm repo add kaito https://kaito-project.github.io/kaito/charts/kaito
helm repo update
helm upgrade --install kaito-workspace kaito/workspace \
  --namespace kaito-workspace \
  --create-namespace \
  --set clusterName="$CLUSTER_NAME" \
  --set featureGates.enableInferenceSetController=true \
  --wait
```

## Quickstart

### Create a KAITO InferenceSet for running inference workloads

- The following example creates an InferenceSet for the phi-4-mini model, using annotations with the prefix `scaledobject.kaito.sh/` to supply parameter inputs for the KEDA KAITO scaler:

  - `scaledobject.kaito.sh/auto-provision`
    - required, specifies whether KEDA KAITO scaler will automatically provision a ScaledObject based on the `InferenceSet` object
  - `scaledobject.kaito.sh/metricName`
    - optional, specifies the metric name collected from the vLLM pod, which is used for monitoring and triggering the scaling operation, default is `vllm:num_requests_waiting`, you could find all vllm metrics in [vLLM Production Metrics](https://docs.vllm.ai/en/stable/usage/metrics/#general-metrics)
  - `scaledobject.kaito.sh/threshold`
    - required, specifies the threshold for the monitored metric that triggers the scaling operation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kaito.sh/v1alpha1
kind: InferenceSet
metadata:
  annotations:
    scaledobject.kaito.sh/auto-provision: "true"
    scaledobject.kaito.sh/metricName: "vllm:num_requests_waiting"
    scaledobject.kaito.sh/threshold: "10"
  name: phi-4-mini
  namespace: default
spec:
  labelSelector:
    matchLabels:
      apps: phi-4-mini
  replicas: 1
  nodeCountLimit: 5
  template:
    inference:
      preset:
        accessMode: public
        name: phi-4-mini-instruct
    resource:
      instanceType: Standard_NC24ads_A100_v4
EOF
```

In just a few seconds, the KEDA KAITO scaler will automatically create the `scaledobject` and `hpa` objects. After a few minutes, once the inference pod is running, the KEDA KAITO scaler will begin scraping [metric values](https://docs.vllm.ai/en/stable/usage/metrics/#general-metrics) from the inference pod, and the status of the `scaledobject` and `hpa` objects will be marked as ready.

```bash
# kubectl get scaledobject
NAME           SCALETARGETKIND                  SCALETARGETNAME   MIN   MAX   READY   ACTIVE    FALLBACK   PAUSED   TRIGGERS   AUTHENTICATIONS           AGE
phi-4-mini     kaito.sh/v1alpha1.InferenceSet   phi-4-mini        1     5     True    True     False      False    external   keda-kaito-scaler-creds   10m

# kubectl get hpa
NAME                    REFERENCE                   TARGETS      MINPODS   MAXPODS   REPLICAS   AGE
keda-hpa-phi-4-mini     InferenceSet/phi-4-mini     0/10 (avg)   1         5         1          11m
```

That's it! Your KAITO workloads will now automatically scale based on the average number of waiting inference requests(`vllm:num_requests_waiting`) across all workloads associated with `InferenceSet/phi-4-mini` in the cluster.

In the example below, if `vllm:num_requests_waiting` exceeds the threshold (10) for over 60 seconds, KEDA will scale up by adding a new replica to `InferenceSet/phi-4-mini`. Conversely, if `vllm:num_requests_waiting` remains below the threshold (10) for more than 300 seconds, KEDA will scale down the number of replicas.

```yaml
Every 2.0s: kubectl describe hpa
Name:                                                     keda-hpa-phi-4-mini
Namespace:                                                default
Labels:                                                   app.kubernetes.io/managed-by=keda-operator
                                                          app.kubernetes.io/name=keda-hpa-phi-4-mini
                                                          app.kubernetes.io/part-of=phi-4-mini
                                                          app.kubernetes.io/version=2.18.1
                                                          scaledobject.keda.sh/name=phi-4-mini
Annotations:                                              scaledobject.kaito.sh/managed-by: keda-kaito-scaler
CreationTimestamp:                                        Tue, 09 Dec 2025 03:35:09 +0000
Reference:                                                InferenceSet/phi-4-mini
Metrics:                                                  ( current / target )
  "s0-vllm:num_requests_waiting" (target average value):  58 / 10
Min replicas:                                             1
Max replicas:                                             5
Behavior:
  Scale Up:
    Stabilization Window: 60 seconds
    Select Policy: Max
    Policies:
      - Type: Pods  Value: 1  Period: 300 seconds
  Scale Down:
    Stabilization Window: 300 seconds
    Select Policy: Max
    Policies:
      - Type: Pods  Value: 1  Period: 600 seconds
InferenceSet pods:  2 current / 2 desired
Conditions:
  Type            Status  Reason            Message
  ----            ------  ------            -------
  AbleToScale     True    ReadyForNewScale  recommended size matches current size
  ScalingActive   True    ValidMetricFound  the HPA was able to successfully calculate a replica count from external metric s0-vllm:num_requests_waiting(&Lab
elSelector{MatchLabels:map[string]string{scaledobject.keda.sh/name: phi-4-mini,},MatchExpressions:[]LabelSelectorRequirement{},})
  ScalingLimited  True    ScaleUpLimit      the desired replica count is increasing faster than the maximum scale rate
Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  33s   horizontal-pod-autoscaler  New size: 2; reason: external metric s0-vllm:num_requests_waiting(&LabelSelector{MatchLabels:ma
p[string]string{scaledobject.keda.sh/name: phi-4-mini,},MatchExpressions:[]LabelSelectorRequirement{},}) above target
```

## Summary

The LLM inference service in KAITO needs to scale inference instances dynamically to handle varying numbers of waiting requests: scaling up to prevent blocking when requests increase, and scaling down to optimize GPU usage when requests decrease. With the newly introduced InferenceSet CRD and KEDA KAITO scaler, configuring this setting in KAITO has become much simpler.

We're just getting started and would love your feedback. To learn more about KAITO inference workloads auto scaling, AI model deployment on AKS, check out the following links:

## Resources

- [KEDA Auto-Scaler for inference workloads](https://kaito-project.github.io/kaito/docs/keda-autoscaler-inference)
- [KAITO InferenceSet](https://github.com/kaito-project/kaito/blob/main/docs/proposals/20250918-introduce_inferenceset_autoscaling.md)
- [vLLM Production Metrics](https://docs.vllm.ai/en/stable/usage/metrics/#general-metrics)
