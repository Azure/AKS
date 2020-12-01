# Monitoring AKS with Promethues

This example demonstrates how to setup monitoring for an AKS cluster using
[kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) as a starting point. Minor
updates are applied to customize the configuration for AKS.

## Prerequisites

- [kustomize](https://github.com/kubernetes-sigs/kustomize) v3.8.7
- kubectl

## Installation

``` sh
kustomize build github.com/Azure/AKS/examples/kube-prometheus | kubectl apply -f -
```
