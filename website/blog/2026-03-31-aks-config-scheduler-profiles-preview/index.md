---
title: "AKS Configurable Scheduler Profiles (preview)"
description: "Optimize GPU and CPU utilization and align pod placement to your critical workloads at scale with Configurable Scheduler Profiles on AKS to optimize node cost."
date: 2026-03-31
authors: [colin-mixon]
tags: [ai, performance, scheduler, best-practices, cost]
---

On average, Kubernetes clusters reach [10% CPU utilization][cast-ai-k8s-cost-report] and most Kubernetes containers use less than [25% of their requested CPU][datadog-state-of-containers]. This data signals that underutilized resources are materially contributing to increased infrastructure cost. While there are many factors that impact node utilization, as a core component of the Kubernetes control plane, the kube-scheduler has a big influence on node utilization. With the introduction of Configurable Scheduler Profiles on AKS, customers now have the opportunity to increase their node utilization across CPU and GPU resources and optimize their costs with access to fine-grained pod scheduling strategies.

[Configurable Scheduler Profiles on AKS][concepts-scheduler-configuration] allows customers to increase node utilization by configuring their own scheduling logic: enabling specific policies, adjusting policy priorities, tuning parameter weights, and choosing when each policy runs (for example, during PreFilter, Filter, or Score).

This blog details how the default Kubernetes scheduler places pods, limitations, and provides best-practice recommendations to increase node utilization for your workloads using Configurable Scheduler Profiles on AKS.

1. [How does kube-scheduler work?](how-does-the-default-kubernetes-scheduler-place-pods)
2. [How to increase AKS cluster CPU utilization with RequestedToCapacityRatio](#increase-aks-cluster-cpu-utilization)
3. [How to increase AKS cluster GPU and CPU utilization with MostAllocated](#increase-aks-cluster-gpu-utilization)

<!-- truncate -->

![Diagram showing increased node utilization with the node bin packing scheduler profile](./hero-image.png)

## How does the default Kubernetes scheduler place pods?

The Kubernetes scheduler operates in two cycles: a synchronous scheduling cycle and an asynchronous binding cycle. The scheduling cycle has two sub-phases, filtering and scoring, and only manages one pod at a time. 
1. **Filtering** phase removes unsuitable nodes based on hard and soft constraints.
2. **Scoring** phase calculates a score for the remaining nodes; ultimately, the most suitable node has the highest score.

Once a node is selected, the binding cycle can process multiple pods in parallel. During this phase, the scheduler attempts to bind the pod to the chosen node. If binding a pod to a node fails, the scheduler tries the node with the next highest score. 

![Diagram of the kube-scheduler workflow showing pods entering the scheduling cycle and binding cycle to assign a pod on a node](./kube-scheduler-scheduling-phases-diagram.png)

When filtering and scoring nodes, for the pending pod, the default scheduler considers several hard and soft constraints with predefined weights, including (but not limited to):

1. Resource requirements (CPU, memory)
2. Node affinity/anti-affinity
3. Pod affinity/anti-affinity
4. Taints and tolerations
5. TopologySpreadConstraints

### Limitations of the default Kubernetes scheduler

The default scheduler is primarily designed for general-purpose workloads that prioritizes nodes with the most avaialable resources using the _LeastAllocated_ scoring strategy. This spreads pods across nodes, even when they could safely be packed more densely. While this works well for many services, the default scheduling criteria, and their fixed priority order, are not suitable for workloads that demand optimizing GPU and CPU utilization. In these scenarios, spreading pods across nodes can lead to fragmented resources, underutilized GPUs, and increased infrastructure cost.

Today, the default scheduler on AKS lacks the flexibility for users to change which criteria should be prioritized, or ignored, in the scheduling cycle on a per cluster basis. This rigidity often forces users to either accept suboptimal placement or manage a separate custom scheduler, both of which increase operational complexity. Starting with Kubernetes v1.33, AKS introduces Configurable Scheduler Profiles, enabling customized scheduler behavior without maintaining a separate scheduler. Now, users can adjust the `NodeResourcesFit` plugin from the default configuration to favor nodes with higher utilization to achieve more efficient bin‑packing and reduce infrastructure cost.

## Configurable Scheduler Profiles on AKS

[Configurable Scheduler Profiles on AKS][concepts-scheduler-configuration] allows customers to benefit from the extensibility of the [scheduling framework][scheduling-framework-interfaces] while reducing the operational overhead of adopting a second scheduler or defining a custom scheduler. Configurable Scheduler Profiles uses a Custom Resource Definition (CRD) that lets users define custom scheduler profiles with their own scheduling logic. A dedicated controller continuously reconciles these user-defined configurations with the underlying kube-scheduler deployment, validating changes and applying them transparently. If a configuration causes the scheduler to become unhealthy, the controller automatically rolls back to the last known good state to ensure cluster stability. This means incorrect plugins or values will not be applied.

![Architecture diagram showing how Configurable Scheduler Profiles use a CRD and controller to reconcile user-defined profiles with the kube-scheduler deployment](./config-scheduler-profiles.png)

A profile is a set of one or more in-tree scheduling plugins and configurations that dictate how to schedule a pod. AKS supports 18 in-tree Kubernetes [scheduling plugins][supported-in-tree-scheduling-plugins]. 

## Increase Node Utilization and Operator Control

Configurable Scheduler Profiles using the `NodeResourcesFit` plugin shows a visible consolidation pattern that differs from the default scheduler's logic. As a result, platform engineers gain more control and resources are used more efficiently when using AKS.
![Table showing increased node utilization with the node bin packing scheduler profiles versus the pod distribution using the default scheduler](./default-config-scheduler-comparison.png)

### Increase AKS Cluster CPU Utilization

Scoring Strategy - RequestedToCapacityRatio

For example, this bin packing strategy allows users to configure a target utilization of 85%.

AKS recommends using the scoring strategy `RequestedToCapacityRatio` because it provides a more granular scoring approach allowing users to define an ideal utilization curve for their respective nodes. 
**This scheduler configuration ensures nodes are not oversaturated.**

:::note
Adjust resource weights, utilization thresholds, and plugin parameters to match your VM SKUs, workload patterns, and cluster topology.
:::

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
            disabled:
              - name: PodTopologySpread
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

### Increase AKS Cluster GPU Utilization

Additionally, customers running GPU-dependent applications like batch jobs will benefit from improved bin-packing and increased GPU utilization. For example, scheduling jobs on nodes with a higher relative GPU utilization can reduce costs while maintaining performance.

**This scheduler configuration maximizes provisioned GPU resource by consolidating smaller jobs onto fewer nodes, lowering the operational cost of underutilized resources without sacrificing performance.**

:::note
Adjust resource weights, utilization thresholds, and plugin parameters to match your VM SKUs, workload patterns, and cluster topology.
:::

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
            disabled:
              - name: PodTopologySpread
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

### FAQ

1. Which Bin packing strategy does AKS recommend to increase node utilization? AKS recommends using the scoring strategy `RequestedToCapacityRatio` because it provides a more granular scoring approach allowing users to define an ideal utilization curve for their respective nodes. For example, this bin packing strategy allows users to configure a target utilization of 85%.
2. How does Configurable Scheduler Profiles  interact with autoscalers such as Node Auto Provisioning (NAP), Cluster Autoscaler (CAS), and Vertical Pod Autoscaler (VPA)? These componenents are  complimentary to each other. Configurable Scheduler Profiles influences how pods are placed on nodes, while autoscalers make scaling decisions based on resource utilization and pending pods.
    - **Node Auto Provisioning (NAP)** is triggered when pods are unscheduable. If a suitable node already exists, that pod will be scheduled with the defined Configurable Scheduler Profile. If no suitable node exists, NAP provisions new capacity, after which the pod is scheduled according to the selected profile.
    - **Cluster Autoscaler (CA)** maanages node scale-up and scale-down. On scale-up, CA is triggered when there aren't any suitable nodes available for the pending pod. Using the Configurable Scheduler Profiles ensure nodes are only scaled when provisioned resources are no longer suitable. On scale-down, CA is triggered when nodes fall below utilization thresholds, the default is 50%. As active nodes are packed more efficiently, underutilized nodes become easier candidates for removal.
    - **VPA** optimizes resource utilization patterns in pods. As pods are recreated with updated CPU and memory requests, they are scheduled using the configured scheduler profile, allowing placement decisions to reflect the new resource requirements.
4. What if a resource is omitted in the `scoringStrategy` like `memory`? If a resource is omitted in the `scoringStrategy`, then that resource will not be considered in the filter or scoring cycles of the defined Configurable Scheduler Profile. If that resource should be considered, but with a reduced influence on the final score, it can be included with reduced weight.


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
[datadog-state-of-containers]: https://www.datadoghq.com/state-of-containers-and-serverless/
[cast-ai-k8s-cost-report]: https://cast.ai/reports/kubernetes-cost-benchmark/
