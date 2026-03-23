---
title: "AKS Configurable Scheduler Profiles (preview)"
description: "Optimize GPU and CPU utilization and align pod placement to your critical workloads at scale with Configurable Scheduler Profiles on AKS to optimize node cost."
date: 2026-03-31
authors: [colin-mixon]
tags: [ai, performance, scheduler, best-practices, cost]
---

Data shows most Kubernetes clusters only use an average of 10% cpu utilization. While there are many factors that impact node utilization, as a core componenet of the Kuberenetes control plane, the kube-scheduler has a big influence on the utilization of nodes. With the introduction of Configurable Scheduler Profiles on AKS, customers now have the opportunity to increase their node utilization across CPU and GPU resources and optimize their costs with access to fine-grain pod scheduling strategies.

[Configurable Scheduler Profiles on AKS][concepts-scheduler-configuration] allows customers to increase node utilization by configuring their own scheduling logic: enabling specific policies, adjusting policy priorities, tuning parameter weights, and choosing when each policy runs (for example, during PreFilter, Filter, or Score).

This blog provides examples of two different scheduler profiles and details the benefits of each to increase node utilization for AKS clusters:

1. [How to increase AKS cluster GPU and CPU utilization with MostAllocated](#increase-aks-cluster-gpu-utilization)
2. [How to increase AKS cluster CPU utilization with RequestedToCapacityRatio](#increase-aks-cluster-cpu-utilization)

<!-- truncate -->

![Diagram showing increased node utilization with the node bin packing scheduler profile](./hero-image.png)

## How does the default Kubernetes scheduler place pods?

The Kubernetes scheduler operates across two cycles, a synchronous scheduling cycle and an asynchronous binding cycle. The scheduling cycle has two sub-phases: filtering and scoring, and only manages one pod at a time. The filter phase removes unsuitable nodes based on hard constraints and the scoring phase calculates a score to the remaining nodes based on the soft contstraints, utlimately the most suitable node has the highest score. The binding cycle can manage multiple pods in parallel. If a pod binding to a node fails, the node with the next highest score is tried. The scheduler filters and scores the optimal node for a pending pod based on several hard and soft constraints, including (but not limited to):

1. Resource requirements (CPU, memory)
2. Node affinity/anti-affinity
3. Pod affinity/anti-affinity
4. Taints and tolerations
5. TopologySpreadConstraints

The default scheduler was primarily designed for general-purpose workloads and out-of-the-box pod scheduling that can be restrictive if you want to bin pack nodes since the hard and soft constraints for pod scheduling do not align with scheduling pods with nodes of higher utilization. The Kubernetes default scheduler scores nodes for workload placement based on a _LeastAllocated_ strategy, to spread across the nodes in a cluster. However, this behavior can result in inefficient resource utilization, as nodes with higher allocation are not favored. You can use `NodeResourcesFit` to control how pods are assigned to nodes based on available resources (CPU, GPU, memory, etc.), including favoring nodes with high resource utilization, within the set configuration.

![Diagram of the kube-scheduler workflow showing pods entering the scheduling cycle and binding cycle to assign a pod on a node](./kube-scheduler-scheduling-phases-diagram.png)

Today, the default scheduler on AKS lacks the flexibility for users to change which criteria should be prioritized, and ignored, in the scheduling cycle on a per cluster basis. This means the default scheduling criteria, and their fixed priority order, are not suitable for workloads that demand optimizing GPU utilization for batch jobs. This rigidity often forces users to either accept suboptimal placement or manage a separate custom scheduler, both of which increase operational complexity. Starting from Kubernetes version 1.33, you can now configure and optimize a scheduler profile for your AKS cluster using Configurable Scheduler Profiles.

## Configurable Scheduler Profiles on AKS

[Configurable Scheduler Profiles on AKS][concepts-scheduler-configuration] allows customers to benefit from the extensibility of the [scheduling framework][scheduling-framework-interfaces] while reducing the operational overhead of adopting a second scheduler or defining a custom scheduler. Configurable Scheduler Profiles uses a Custom Resource Definition (CRD) that lets users define custom scheduler profiles with their own scheduling logic. A dedicated controller continuously reconciles these user-defined configurations with the underlying kube-scheduler deployment, validating changes and applying them transparently. If a configuration causes the scheduler to become unhealthy, the controller automatically rolls back to the last known good state to ensure cluster stability. This means incorrect plugins or values will not be applied.

![Architecture diagram showing how Configurable Scheduler Profiles use a CRD and controller to reconcile user-defined profiles with the kube-scheduler deployment](./config-scheduler-profiles.png)

A profile is a set of one or more in-tree scheduling plugins and configurations that dictate how to schedule a pod. AKS supports 18 in-tree Kubernetes [scheduling plugins][supported-in-tree-scheduling-plugins], which can be generally grouped into three categories:

1. Scheduling constraints and order-based plugins
2. Node selection constraints scheduling plugins
3. Resource and topology optimization scheduling plugins

:::note
Adjust resource weights, utilization thresholds, and plugin parameters to match your VM SKUs, workload patterns, and cluster topology.
:::

## Increase Node Utilization and Operator Control

Configurable Scheduler Profiles using the `NodeResourcesFit` plugin shows a visible consolidation pattern that differs from the default scheduler's logic. As result, platform engineers gain more control and resources are used more efficiently when using AKS.
![Table showing increased node utilization with the node bin packing scheduler profiles versus the pod distribution using the default scheduler](./default-config-scheduler-comparison.png)

### Increase AKS Cluster GPU Utilization

Additionally, customers running GPU-dependent applications like batch jobs will benefit from improved bin-packing and increased GPU utilization. For example, scheduling jobs on nodes with a higher relative GPU utilization, can reduce costs while maintaining performance.

**This scheduler configuration maximizes provisioned GPU resource by consolidating smaller jobs onto fewer nodes, lowering the operational cost of underutilized resources without sacrificing performance.**

```yaml
apiVersion: aks.azure.com/v1alpha1
kind: SchedulerConfiguration
metadata:
  name: upstream
spec:
  rawConfig: |
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
    profiles:
      - schedulerName: gpu-node-binpacking-scheduler
        plugins:
          multiPoint:
            enabled:
              - name: ImageLocality
              - name: NodeResourcesFit
              - name: NodeResourcesBalancedAllocation
        pluginConfig:
          - name: NodeResourcesFit
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeResourcesFitArgs
              scoringStrategy:
                type: MostAllocated
                resources:
                  - name: cpu
                    weight: 1
                  - name: nvidia.com/gpu
                    weight: 5
```

### Increase AKS Cluster CPU Utilization

Scoring Strategy - RequestedToCapacityRatio
**This scheduler configuration ensures nodes are not oversaturated.**

```yaml
apiVersion: aks.azure.com/v1alpha1
kind: SchedulerConfiguration
metadata:
  name: upstream
spec:
  rawConfig: |
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
    profiles:
      - schedulerName: cpu-binpacking-scheduler
        plugins:
          multiPoint:
            enabled:
              - name: NodeResourcesFit
        pluginConfig:
          - name: NodeResourcesFit
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeResourcesFitArgs
              scoringStrategy:
                type: RequestedToCapacityRatio
                resources:
                  - name: cpu
                    weight: 8
                  - name: memory
                    weight: 1
                requestedToCapacityRatio:
                  shape:
                    - utilization: 0
                      score: 0
                    - utilization: 30
                      score: 8
                    - utilization: 50
                      score: 10
                    - utilization: 85
                      score: 10
                    - utilization: 90
                      score: 3
                    - utilization: 100
                      score: 0
```

### FAQ

1. How does this interact with autoscalers such as Node Auto Provisioning (NAP), Cluster Autoscaler (CAS), and Vertical Pod Autoscaler (VPA)?
2. What if I don't use a resource in the scoringStrategy? Then that resource will not be considered in the filter or scoring cycles of the defined Configurable Scheduler Profile.
3. Which scoringStrategy does AKS recommend to increase node utilization? AKS recommends using the RequestedToCapacityRatio strategy because it provides a more granular scoring approach allowing users to define an ideal utilization curve for their respective nodes.

## Next Steps: Optimize Azure resources and test Configurable Scheduler Profiles on AKS

With Configurable Scheduler Profiles, teams gain fine-grained control over pod placement strategies like bin-packing, topology distribution, and resource-based scoring that directly addresses challenges related to application resilience and resource utilization for their AKS clusters. By leveraging these scheduling plugins, AKS users can ensure their workloads make full use of available GPU capacity, reduce idle costs, and avoid costly overprovisioning. This not only improves ROI but also accelerates development by allowing more jobs to run concurrently and reliably.

- For best practices using the kube-scheduler visit [kube-scheduler best practices][best-practices-advanced-scheduler]
- Increase node utilization using [Configurable Scheduler Profiles][node-bin-packing-configurations]
- If additional capabilities or ML frameworks are needed to schedule and queue batch workloads, you can [install and configure Kueue on AKS][kueue-overview] to ensure efficient, policy-driven scheduling in AKS clusters.

[concepts-scheduler-configuration]: https://learn.microsoft.com/azure/aks/concepts-scheduler-configuration
[kueue-overview]: https://learn.microsoft.com/azure/aks/kueue-overview
[best-practices-advanced-scheduler]: https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler
[scheduling-framework-interfaces]: https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/#interfaces
[supported-in-tree-scheduling-plugins]: https://learn.microsoft.com/azure/aks/concepts-scheduler-configuration#supported-in-tree-scheduling-plugins
[node-bin-packing-configurations]: https://learn.microsoft.com/azure/aks/configure-node-binpack-scheduler?tabs=new-cluster
