---
title: "Autoscale KAITO inference workloads on AKS using KEDA"
date: "2025-12-11"
description: "Autoscale your KAITO inference workloads using KEDA"
authors: ["andy-zhang"]
tags: ["ai", "kaito"]
---

[Kubernetes AI Toolchain Operator](https://github.com/Azure/kaito/tree/main) (KAITO) is an operator that automates the AI/ML model inference or tuning workload in a Kubernetes cluster. With the [v0.8.0 release](https://github.com/Azure/kaito/releases/tag/v0.8.0), KAITO has introduced intelligent autoscaling for inference workloads as an alpha feature.

## Overview

This blog outlines the steps to enable intelligent autoscaling based on the service monitoring metrics for KAITO inference workloads by using the following components and features:

- [KEDA](https://github.com/kedacore/keda)

  - Kubernetes-based Event Driven Autoscaling component
- [keda-kaito-scaler](https://github.com/kaito-project/keda-kaito-scaler)
  - A dedicated KEDA external scaler, eliminating the need for external dependencies such as Prometheus.
- KAITO `InferenceSet` Custom Resource Definition (CRD) and controller
  - This new CRD and controller were built on top of the KAITO workspace for intelligent autoscaling, introduced as an alpha feature in KAITO version `v0.8.0`

### Architecture

 ![keda-kaito-scaler-arch](keda-kaito-scaler-arch.png)

## Prerequisites

- Install KEDA

> The following example demonstrates how to install KEDA using Helm chart. For instructions on installing KEDA through other methods, please refer to the guide [deploying-keda](https://github.com/kedacore/keda#deploying-keda).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
```

- Install keda-kaito-scaler

```bash
helm repo add keda-kaito-scaler https://kaito-project.github.io/keda-kaito-scaler/charts/kaito-project
helm upgrade --install keda-kaito-scaler -n kaito-workspace keda-kaito-scaler/keda-kaito-scaler --create-namespace
```

## Enable this feature on KAITO

This feature is available starting from KAITO `v0.8.0`, and the InferenceSet controller must be enabled during the KAITO installation.

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
    - optional, specifies the metric name collected from the vLLM pod, which is used for monitoring and triggering the scaling operation, default is `vllm:num_requests_waiting`
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

In just a few seconds, the KEDA KAITO scaler will automatically create the `scaledobject` and `hpa` objects. After a few minutes, once the inference pod is running, the KEDA KAITO scaler will begin scraping metric values from the inference pod, and the status of the `scaledobject` and `hpa` objects will be marked as ready.

```bash
# kubectl get scaledobject
NAME           SCALETARGETKIND                  SCALETARGETNAME   MIN   MAX   READY   ACTIVE    FALLBACK   PAUSED   TRIGGERS   AUTHENTICATIONS           AGE
phi-4-mini     kaito.sh/v1alpha1.InferenceSet   phi-4-mini        1     5     True    True     False      False    external   keda-kaito-scaler-creds   10m

# kubectl get hpa
NAME                    REFERENCE                   TARGETS      MINPODS   MAXPODS   REPLICAS   AGE
keda-hpa-phi-4-mini     InferenceSet/phi-4-mini     0/10 (avg)   1         5         1          11m
```

That's it! Your KAITO workloads will now automatically scale based on the number of waiting inference requests(`vllm:num_requests_waiting`).

In below example, when `vllm:num_requests_waiting` exceeds the threshold (10s) for more than 60 seconds, KEDA will scale up a new `InferenceSet/phi-4-mini` replica.

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
