---
title: "AKS configurable scheduler profiles (preview)"
description: "Optimize AKS scheduling with configurable scheduler profiles that improve GPU utilization and align pod placement to your critical workloads at scale."
date: 2026-04-23
authors: [colin-mixon]
tags: [ai, performance, scheduler, best-practices, cost]
---

Thoughtful scheduling strategies can resolve pervasive challenges like resource utilization. The default scheduler was primarily designed for general-purpose workloads and out-of-box pod scheduling that can be restrictive if you want to bin pack nodes since the hard and soft constraints for pod scheduling do not align with scheudling pods with nodes of higher utilization. The scheduler selects the optimal node for queued pod(s) based on several constraints, including (but not limited to):

1. Resource requirements (CPU, memory)
2. Node affinity/anti-affinity
3. Pod affinity/anti-affinity
4. Taints and tolerations

Out of the available nodes, the scheduler then filters out nodes that don't meet the requirements to identify the node that is most optimal for the pod(s). Today, the AKS default scheduler lacks the flexibility for users to change which criteria should be prioritized, and ignored, in the scheduling cycle on a per workload basis. This means the default scheduling criteria, and their fixed priority order, are not suitable for workloads that demand co-locating pods with their persistent volumes for increased data locality, optimizing GPU utilization for machine learning, or enforcing strict zone-level distribution for microservices. This rigidity often forces users to either accept suboptimal placement or manage a separate custom scheduler, both of which increase operational complexity.

**[AKS Configurable Scheduler Profiles][concepts-scheduler-configuration] reduces operational complexity by providing extensibility and control.** Now, customers can define their own scheduling logic by selecting specific policies, altering parameter weight, changing policy priority, adding additional policy parameters, and changing policy evaluation point (i.e. PreFilter, Filter, Score) without deploying a second scheduler. On AKS, customers have mentioned that AKS Configurable Scheduler Profiles allows them to increase resiliency without operational overhead of YAML wrangling or reduce cluster costs without adopting a secondary scheduler. Additionally, our AI and HPC customers have batch workloads that have benefitted from improved bin-packing and increased GPU utilization.

In this blog you will learn how to configure AKS Configurable Scheduler Profiles for three increased node utilization:

1. [How to increase CPU utilization](#increase-gpu-utilization-by-bin-packing-gpu-backed-nodes)
2. [How to increase GPU utilization](#increase-gpu-utilization-by-bin-packing-gpu-backed-nodes)

Lastly, you will find [best practices](#best-practices-and-configuration-considerations) to help guide how you consider both individual plugin configurations, your custom scheduler configuration, and your Deployment design holistically.

<!-- truncate -->

## AKS Configurable Scheduler Profiles

AKS Configurable Scheduler Profiles uses a Custom Resource Definition (CRD) that lets users define custom scheduler profiles. A dedicated controller continuously reconciles these user-defined configurations with the underlying kube-scheduler deployment, validating changes and applying them transparently. If a configuration causes the scheduler to become unhealthy, the controller automatically rolls back to the last known good state to ensure cluster stability.

![Configurable Scheduler Profiles Diagram](CONFIG_SCHEDULER_PROFILES.png)

A scheduler profile is a set of one or more in-tree scheduling plugins and configurations that dictate how to schedule a pod. Previously, the scheduler configuration wasn't accessible to users. Starting from Kubernetes version 1.33, you can now configure and set a scheduler profile for the AKS scheduler on your cluster. AKS supports 18 in-tree Kubernetes [scheduling plugins][supported-in-tree-scheduling-plugins]. The plugins can be generally grouped into three categories:

1. Scheduling constraints and order-based plugins
2. Node selection constraints scheduling plugins
3. Resource and topology optimization scheduling plugins

Below you will find example configurations for common workload objectives.

:::note
Adjust VM SKUs in `NodeAffinity`, shift utilization curves or weights, and use the right zones for your cluster(s) in the configurations below.
:::

### Increase GPU Utilization by Bin Packing GPU-backed Nodes

The AKS default scheduler scores nodes for workload placement based on a _LeastAllocated_ strategy, to spread across the nodes in a cluster. However, this behavior can result in inefficient resource utilization, as nodes with higher allocation are not favored. You can use `NodeResourcesFit` to control how pods are assigned to nodes based on available resources (CPU, GPU, memory, etc.), including favoring nodes with high resource utilization, within the set configuration.

For example, scheduling pending jobs on nodes with a higher relative GPU utilization, users can reduce costs and increase GPU Utilization while maintaining performance.

**This scheduler configuration maximizes GPU efficiency for larger batch jobs by consolidating smaller jobs onto fewer nodes and lowering the operational cost of underutilized resources without sacrificing performance.**

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
              scoringStrategy:
                type: MostAllocated
                resources:
                  - name: cpu
                    weight: 1
                  - name: nvidia.com/gpu
                    weight: 3
          - name: NodeResourcesBalancedAllocation
            args:
              resources:
                - name: nvidia.com/gpu
                  weight: 1
```


### ResourceToCapacity


**This scheduler configuration ensures workloads needing large memory footprints are placed on nodes that provide sufficient RAM and maintain proximity to their volumes, enabling fast, zone‑aligned PVC binding for optimal data locality.**

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
                  - name: memory
                    weight: 5
                  - name: cpu
                    weight: 1
                  - name: ephemeral-storage
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

## Next Steps: Optimize and test with AKS Configurable Scheduler Profiles

With AKS Configurable Scheduler Profiles, teams gain fine-grained control over pod placement strategies like bin-packing, topology distribution, and resource-based scoring that directly address the challenges of resilience and resource utilization for web-distributed workloads and AI workloads. By leveraging these advanced scheduling plugins, AKS users can ensure their workloads make full use of available GPU capacity, reduce idle time, and avoid costly overprovisioning. This not only improves ROI but also accelerates innovation by allowing more jobs to run concurrently and reliably.

- For best practices using the kube-scheduler visit [kube-scheduler best practices][best-practices-advanced-scheduler]
- Configure your workload specific scheduler using the [AKS Configurable Scheduler][concepts-scheduler-configuration]
- If additional capabilities or ML frameworks are needed to schedule and queue batch workloads, you can [install and configure Kueue on AKS][kueue-overview] to ensure efficient, policy-driven scheduling in AKS clusters.

[concepts-scheduler-configuration]: https://learn.microsoft.com/azure/aks/concepts-scheduler-configuration
[kueue-overview]: https://learn.microsoft.com/azure/aks/kueue-overview
[best-practices-advanced-scheduler]: https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler
[scheduling-framework/#interfaces]: https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/#interfaces
[memory-optimized-vm]: https://learn.microsoft.com/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist#memory-optimized
[supported-in-tree-scheduling-plugins]: https://learn.microsoft.com/azure/aks/concepts-scheduler-configuration#supported-in-tree-scheduling-plugins
