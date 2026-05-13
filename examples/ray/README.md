# Running Ray on Azure Kubernetes Service (AKS)

This example demonstrates how to deploy and run a [Ray](https://www.ray.io/) application on AKS using the KubeRay operator.

## Prerequisites

- An AKS cluster (Kubernetes 1.26+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured to access your cluster
- [Helm](https://helm.sh/docs/intro/install/) 3.x installed

## Overview

Ray is an open-source framework for scaling AI and Python workloads. This example deploys:

1. The **KubeRay operator** to manage Ray clusters on Kubernetes
2. A **RayCluster** custom resource with a head node and worker nodes
3. A sample **Ray job** to verify the deployment

## Deploy the KubeRay operator

```bash
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

helm install kuberay-operator kuberay/kuberay-operator \
  --namespace kuberay-system \
  --create-namespace
```

Verify the operator is running:

```bash
kubectl get pods -n kuberay-system
```

## Deploy the RayCluster

```bash
kubectl apply -f ray-cluster.yaml
```

Wait for the cluster to be ready:

```bash
kubectl get rayclusters
kubectl get pods -l ray.io/cluster=ray-cluster
```

## Submit a sample job

```bash
kubectl apply -f ray-job.yaml
```

Check job status:

```bash
kubectl get rayjobs
kubectl logs -l job-name=ray-sample-job
```

## Clean up

```bash
kubectl delete -f ray-job.yaml
kubectl delete -f ray-cluster.yaml
helm uninstall kuberay-operator -n kuberay-system
kubectl delete namespace kuberay-system
```

## Resources

- [Ray documentation](https://docs.ray.io/)
- [KubeRay documentation](https://ray-project.github.io/kuberay/)
- [AKS documentation](https://learn.microsoft.com/azure/aks)
