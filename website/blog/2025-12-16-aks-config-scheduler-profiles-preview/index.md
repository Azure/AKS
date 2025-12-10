---
title: "Announcing Azure Configurable Scheduler Profiles: Optimize resource ROI with fine grained scheduling strategies."
description: "Avoid scheduling inefficiencies and improve GPU utilization with AKS Configurable Scheduler Profiles"
date: 2025-12-16
authors: 
   - Colin Mixon
categories: 
- operations
- ai
tags:
  - AI
  - performance
  - Scheduler
---
# Avoid scheduling inefficiencies and improve GPU utilizaiton with AKS Configurable Scheduler Profiles (Preview)
Thoughtful scheduling strategies can resolve pervasive challenges across web-distributed workloads and AI workloads like resiliency and resource utilization. But the default scheduler was primarily designed for general-purpose workloads and out-of-box pod scheduling. The scheduler ultimately selects the optimal node for pod(s) based on several criteria, including (but not limited to):

1. Resource requirements (CPU, memory)
2. Node affinity/anti-affinity
3. Pod affinity/anti-affinity
4. Taints and tolerations

The criteria, and their respective priority in the scheduling cycle, are not suitable for advanced use cases that might require custom scheduling strategies. Nor, does the default scheduler enable user customization for fine-grain pod placement control while avoiding managing a second custom scheduler. For example, users running batch jobs might prefer collocating on a few nodes for better performance or cost-sensitive workloads might benefit from node binpacking to minimize idle node costs.

To support these advanced use cases, and to give users more control, use [AKS Configurable Scheduler Profiles][https://learn.microsoft.com/en-us/azure/aks/concepts-scheduler-configuration] to tailor a scheduler to their specific workload requirements using node bin-packing, preemption, and 16 other scheduling plugins that can optimize ROI​, improve gpu utilization, improve data locality, or increase resliency.

In this blog you will learn how to configure the AKS Configurable Scheduler Profiles for [bin packing GPU-backed nodes][#increase-gpu-utilization-by-bin-packing-gpu-backed-nodes], [distributing pods across topologies][#increase-reselieince-by-distributing-pods-across-topology-domains], and [placing jobs on memory-optimized, pvc-ready nodes][#reduce-latency-with-memory‑optimized-pvc‑aware-scheduling]. Lastly, you will find [Best Practices and Configuration Considerations][#best-practice-and-configuration-considerations] to help guide how you consider both individual plugin configurations, your custom scheduler configuration, and your Deployment design holistically.

## AKS Configurable Scheduler Profiles
A scheduler profile is a set of one or more in-tree scheduling plugins and configurations that dictate how to schedule a pod. Previously, the scheduler configuration wasn't accessible to users. Starting from Kubernetes version 1.33, you can now configure and set a scheduler profile for the AKS scheduler on your cluster. 

AKS supports 18 in-tree Kubernetes scheduling plugins that allow pods to be placed on user-specified nodes, ensure pods are matched with specific storage resources, and more. The plugins can be generally grouped into the following categories:

1. Scheduling constraints and order-based plugins
2. Node selection constraints scheduling plugins
3. Resource and topology optimization scheduling plugins

Below you will find example configurations for some of the most common workload objectives. 
:::note
Adjust VM SKUs in NodeAffinity, shift utilization curves or weights, and use the right zones for your cluster(s) in the configurations below.
:::

### Increase GPU Utilization by Bin Packing GPU-backed Nodes
You can use `NodeResourceFit` to control how pods are assigned to nodes based on available resources (CPU, memory, etc.), including favoring nodes with high resource utilization, within the set configuration. 

For example, scheduling pending jobs on nodes with a higher relative GPU utilization, users can reduce costs and increase GPU Utilization while maintaining performance. 

**This scheduler configuration maximizes GPU efficiency for larger batch jobs by cobsolidating smaller jobs onto fewer nodes and lowering the operational cost of underutilized resources without sacrificing performance.**
```yaml
apiVersion: aks.azure.com/v1alpha1
kind: SchedulerConfiguration
metadata:
  name: upstream
spec:
  rawConfig: |
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
  - schedulerName: gpu-node-binpacking-scheduler
    plugins:
      multiPoint:
        enabled:
          - name: ImageLocality
          - name: NodeResourceFit
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
### Increase reselieince by distributing pods across topology domains
`PodTopologySpread` is a scheduling strategy that seeks to distribute pods evenly across failure domains (such as availability zones or regions) to ensure high availability and fault tolerance in the event of zone or node failures. 

For example, spreading replicas across distinct zones safeguards availability during an AZ outage, while a softer host‑level rule prevents scheduling deadlocks when cluster capacity is uneven.

**This configuration is effective for highly‑available stateless services (web/API, gateways) or distributed messaging clusters, like Kafka brokers, that rely on the availability of multiple replicas.**
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
    - schedulerName: pod-distribution-scheduler
      pluginConfig:
          - name: PodTopologySpread
            args:
              defaultingType: List
              defaultConstraints:
                - maxSkew: 2
                  topologyKey: topology.kubernetes.io/zone
                  whenUnsatisfiable: DoNotSchedule
                - maxSkew: 1
                  topologyKey: kubernetes.io/hostname
                  whenUnsatisfiable: ScheduleAnyway
```
### Reduce latency with memory‑optimized, PVC‑aware scheduling
Use `VolumeBinding` to ensure pods are placed on nodes where _PersistentVolumeClaim's_ (PVC) can bind to _PersistentVolume's_ (PV). `VolumeZone` validates that nodes and volumes satisfy zonal requirements to avoid cross-zone storage access.

For example, combine `VolumeBinding` and `VolumeZone` plugins, with `NodeAffinity` and `NodeResourcesFit` with `RequestedToCapacityRatio`, to influence pod placement on [Azure memory-optimized SKUs][https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist#memory-optimized], while ensuring PVC's bind quickly in the target zone to minimize cross‑zone traffic and latency.

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
      - schedulerName: mem-optimized-node-scheduler
        plugins:
          multiPoint:
            enabled:
              - name: NodeAffinity
              - name: NodeResourcesFit
              - name: VolumeBinding
              - name: VolumeZone
        pluginConfig:
          - name: NodeAffinity
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: NodeAffinityArgs
              addedAffinity:
                preferredDuringSchedulingIgnoredDuringExecution:
                  - weight: 100
                    preference:
                      matchExpressions:
                        - key: topology.kubernetes.io/zone
                          operator: In
                          values: [westus3-1, westus3-2, westus3-3]
                  - weight: 80
                    preference:
                      matchExpressions:
                        - key: node.kubernetes.io/instance-type
                          operator: In
                          values:
                            - Standard_E16s_v5
                            - Standard_E32s_v5
          - name: VolumeBinding
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: VolumeBindingArgs
              bindTimeoutSeconds: 300
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
                      score: 4
                    - utilization: 60
                      score: 8
                    - utilization: 80
                      score: 10
                    - utilization: 90
                      score: 6
                    - utilization: 100
                      score: 0
```

## Best Practices and Configuration Considerations
As a reminder, there are many parameters the scheduler considers across the [scheduling cycle][https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/#interfaces] before a pod is placed on a node that impacts how a pod is assigned. This section is meant to help guide how you consider both individual plugin configurations, your custom scheduler configuration, and your Deployment design holistically.

1. Ensure the intended deployment is assigned to the _correct_ scheduler profile.
2. Ensure the customer scheduler profile complements the implementation of Deployments, StorageClasses, and PersistentVolumeClaim's. Misalignment can lead to pending pods and degraded workload performance, even when the scheduler is functioning as expected.
3. Ensure their are enough nodes in each zone to accommodate your deployment replicas and ensure your AKS node pool spans the right availability zones. If not, pods may remain in a pending state.
4. Use namespaces to separate workloads which improves your ability to validate or troubleshoot.
5. Assign `priorityClassName` for workloads that should preempt others, this is critical if you use the DefaultPreemption plugin.
6. If you use the `ImageLocality` plugin, use DaemonSets or node pre-pulling for latency-sensitive images, otherwise the benefit may be minimal.
7. If your cluster is large, a low `PercentageOfNodesToScore` speeds scheduling by reducing the number of nodes scored, _but_ it may reduce optimal placement.
8. If you enable a plugin in the `plugins:multipoint` section but do not define it in `pluginConfig:`, AKS uses the default configuration for that plugin.
9. For `NodeResourcesFit`, the ratio matters more than absolute values. So CPU:Memory:Storage = 3:1:2, which means CPU is 3× more influential than memory, and storage is 2x more influential than memory in the scoring phase.
10. Pair `PodTopologySpread` with pod disruption budget's (PDB) and multi‑replica strategies for HA during upgrades.

## Next Steps: Try out AKS Configurable Scheduler

With AKS Configurable Scheduler Profiles, teams gain fine-grained control over pod placement strategies like bin-packing, topology distribution, and resource-based scoring that directly address the challenges of resielince and resource utilization for web-distributed workloads and AI workloads. By leveraging these advanced scheduling plugins, AKS users can ensure their workloads make full use of available GPU capacity, reduce idle time, and avoid costly overprovisioning. This not only improves ROI but also accelerates innovation by allowing more jobs to run concurrently and reliably. 

- For best practices using the kube-scheduler visit [kube-scheduler best practices][https://learn.microsoft.com/en-us/azure/aks/operator-best-practices-advanced-scheduler]
- Configure your workload specific scheduler using the [AKS Configurable Scheduler][https://learn.microsoft.com/en-us/azure/aks/concepts-scheduler-configuration]
- If additional capabilities or ML frameworks are needed to schedule and queue batch workloads, you can [install and configure Kueue on AKS][https://learn.microsoft.com/en-us/azure/aks/kueue-overview] to ensure efficient, policy-driven scheduling in AKS clusters.
