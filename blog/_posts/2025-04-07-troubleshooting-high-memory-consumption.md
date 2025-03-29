---
title: "Troubleshooting high memory consumption in disk intensive Applications"
description: "Explore how Linux page caching inflates memory usage in Kubernetes and learn how to identify and manage it effectively."
date: 2025-04-07
author: Claudio Godoy
categories: general
---

Disk input and output operations are costly, and most operating systems implement `caching` strategies for reading and writing data to the filesystem. In the case of the [Linux Kernel](https://www.kernel.org/doc), it employs several strategies, such as the [Page Cache](https://www.kernel.org/doc/gorman/html/understand/understand013.html), whose primary goal is to store data read from the filesystem in `cache`, making it available in `memory` for future read operations.  

When analyzing metrics collected by [Prometheus](https://prometheus.io/docs/introduction/overview/) from a [Go](https://go.dev/) application running in a [pod](https://kubernetes.io/docs/concepts/workloads/pods/) on [Kubernetes](https://prometheus.io/docs/introduction/overview/), we identified a memory consumption much higher than expected, given that the application did nothing beyond writing random data to a few files. Through a series of analyses and research, we were able to relate the `page caching` behavior to the issue at hand.

In this article, we will walk through the steps taken to identify the issue and demonstrate how to reproduce and troubleshoot it effectively. By understanding the relationship between `page caching` behavior and the observed memory consumption, we aim to provide a clear and practical guide for addressing similar problems.

## Application  

If your application performs moderate file system write operations, you may encounter the same issue. In our case, we were using a `Golang` application that simply wrote random data to the file system via the [os](https://pkg.go.dev/os) package. This triggered the operating system to execute the [SYS_CALL](https://www.man7.org/linux/man-pages/man2/syscall.2.html) [write](https://www.man7.org/linux/man-pages/man2/pwritev.2.html) system call.

It's important to note that this problem isn't limited to `Golang`. Any language that relies on the [SYS_CALL](https://www.man7.org/linux/man-pages/man2/syscall.2.html) [write](https://www.man7.org/linux/man-pages/man2/pwritev.2.html) system call under the hood can exhibit similar behavior. So, while we’re using Golang as an example, this issue can also occur in other technologies.

## Cluster and observability tools

Our application was deployed on [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure//AKS/) running [Kubernetes version 1.30.10](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.30.md#v13010).

Below are the most relevant details about the cluster I'm using:

```json
"properties": {
        "kubernetesVersion": "1.30.10",
        "currentKubernetesVersion": "1.30.10",
        "agentPoolProfiles": [
            {
                "vmSize": "Standard_D4ds_v5",
                "osDiskSizeGB": 150,
                "osDiskType": "Ephemeral",
                "kubeletDiskType": "OS",
                "type": "VirtualMachineScaleSets",
                "mode": "System",
                "osType": "Linux",
                "osSKU": "Ubuntu",
                "nodeImageVersion": "AKSUbuntu-2204gen2containerd-202503.13.0",
            }
        ],
```

To collect metrics from the `AKS Cluster`, we utilized [Azure-managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview). For data analysis and to begin our investigation, we leveraged [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview).

However, it’s worth noting that you can use alternative tools or approaches to analyze metrics from your `pod` and `application`, as long as you can retrieve the same level of information we will discuss in the following sections.

## Identify the problem

First check the metric [Working_set](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#memory) of your `pod` in [Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview) using the following query in the [Explore tab](https://grafana.com/docs/grafana/latest/explore/get-started-with-explore/):

```sh
container_memory_working_set_bytes{pod="<YOUR-POD-NAME>"}
```

This metric is highly important, because the `Kubernetes` uses the [Working_set](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#memory) as a information to take certain decision, the best example is the [HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/).

First, ask yourself if this metric makes sense. In our case we had the following scenario:

![working_set_graph](/AKS/assets/images/tshoot-memory-consuption/working_set.png)

In this application's case the `working_set` is close to **~380 MB**, which is extremely high for this application.

To determine if this behavior is normal, compare the `working_set` with a more specific application-level metric. In `Golang`, the correct metric is:

```sh
go_memstats_heap_inuse_bytes{pod="YOUR-POD-NAME"}
```

The `go_memstats_heap_inuse_bytes` metric represents the number of bytes of memory currently in use by the heap in a `Go` application.

The figure above highlights the striking difference between the two metrics:

![go_heap](/AKS/assets/images/tshoot-memory-consuption/comparing_ws_heap.png)

The discrepancy is significant: approximately **380 MB** from the `pod` perspective versus only **~8 MB** from the application's perspective. This pattern strongly suggests a `page cache` issue, as discussed earlier in this article.

The next step is to understand the [Working_set](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#memory) metric in detail and perform a deeper investigation into the container to determine why the pod appears to be "using" **~380 MB** of memory.

### Working_set

[Working_set](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#memory) is the metric in [bytes](https://en.wikipedia.org/wiki/Byte) that indicates the amount of memory consumed by a pod. The documentation states that this metric is an estimate calculated by the operating system.

> Excerpt from the [official documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline): "In an ideal world, the `working_set` is the amount of memory in use that cannot be freed under memory pressure. However, the calculation varies depending on the host's operating system and often relies heavily on heuristics to produce an estimate."

Where does this metric come from? That was the question I asked after encountering this behavior.

The answer lies in the [Kubernetes metrics pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/):

![Kubernetes metrics architecture image](/AKS/assets/images/tshoot-memory-consuption/metrics_pipeline.png)

- [cAdvisor](https://github.com/google/cadvisor): [Daemon](https://www.man7.org/linux/man-pages/man7/daemon.7.html) for collecting, aggregating, and exposing container metrics included in Kubelet.

- [kubelet](https://kubernetes.io/docs/concepts/overview/components/#kubelet): Agent for managing container resources. Resource metrics are accessible using the `/metrics/resource` and `/stats` endpoints of the [kubelet](https://kubernetes.io/docs/concepts/overview/components/#kubelet) API.

- [Node level resource metrics](https://kubernetes.io/docs/reference/instrumentation/node-metrics): API provided by kubelet to discover and retrieve summarized statistics by available nodes through the `/metrics/resource` endpoint.

- [metrics-server](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#metrics-server): An additional cluster component that collects and aggregates resource metrics obtained from each [kubelet](https://kubernetes.io/docs/concepts/overview/components/#kubelet). It provides metrics for use by the [HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/), [VPA](https://github.com/kubernetes/autoscaler/blob/master/vertical-pod-autoscaler/README.md), and the `kubectl top` command.

- [Metrics API](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#metrics-api): Kubernetes API that supports access to CPU and memory used for autoscaling.

The `Prometheus` access CPU and memory metrics through the [Metrics API](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#metrics-api), which starts a communication chain between components reaching the [container runtime](https://kubernetes.io/docs/setup/production-environment/container-runtimes/).

### cAdvisor

[cAdvisor](https://github.com/google/cadvisor) is the component closest to the [container runtime](https://kubernetes.io/docs/setup/production-environment/container-runtimes), and it is responsible for collecting the [working_set](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/#memory), currently in version `v1.3`.

In the `setMemoryStats` function of the [container/libcontainer/handler.go](container/libcontainer/handler.go) file, the following calculation is performed:

```go
inactiveFileKeyName := "total_inactive_file"
if cgroups.IsCgroup2UnifiedMode() {
    inactiveFileKeyName = "inactive_file"
}

workingSet := ret.Memory.Usage
if v, ok := s.MemoryStats.Stats[inactiveFileKeyName]; ok {
    ret.Memory.TotalInactiveFile = v
    if workingSet < v {
        workingSet = 0
    } else {
        workingSet -= v
    }
}
ret.Memory.WorkingSet = workingSet
```

This section is important because this is where `cAdvisor` captures statistics from the [cgroup](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html) and calculates the `working_set`. Note that it subtracts the `inactive_file` statistic.

### Cgroups

[Cgroup](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html) is a feature of the Linux `kernel` that allows processes to be grouped hierarchically and controls the allocation of system resources to these groups in a configurable manner. With `cgroups`, it is possible to manage and limit resource usage such as:

- `CPU`: Define how much processing time each group of processes can use.
- `Memory`: Limit the amount of memory each group of processes can utilize.
- `Disk I/O`: Control the number of input/output operations each group can perform on storage devices.
- `Network`: Manage the network bandwidth available for each group of processes.

We can inspect the memory statistics of the `cgroup` of the `pod` we used as an example by following the steps below.

Connect to the `pod`: `kubectl exec disk-writer -it -- bash`.

Navigate to the directory of `cgroup` statistics: `cd /sys/fs/cgroup`.

List all memory-related files: `ls | grep -e memory.stat -e memory.current`.

```sh
memory.current
memory.stat
```

The value of `memory.current` represents the total amount of memory used by the cgroup, while `memory.stat` provides a detailed view of how this memory is distributed and managed.

Check the `memory.current` file, which is the total amount of memory allocated by the `cgroup`: `cat memory.current`.

```sh
10895486976 # ~= 10.895487 GB
```

This value is much higher than the `380 MB` reported earlier by the `working_set` metric.

Check the `inactive_file` in the `memory.stat` file: `cat memory.stat | grep inactive_file`.

```sh
inactive_file 10511630336 # ~= 10.5116303 GB 
```

In the previous paragraph, we observed that `cAdvisor` performs the subtraction of `inactive_file` to calculate the `working_set`.

If we subtract the value of `inactive_file` from the total memory in the `memory.current` file, we get a value close to the `380 MB` reported by `cAdvisor`. The question is: is `inactive_file` the only segment that cannot be freed under memory pressure? In reality, this may vary depending on the `Linux Distribution` and `Kernel Version`. For example, in the case of `Ubuntu`, there are a few other segments that are freed under memory pressure.

From the `memory.stat` file, I calculated the percentage distribution of the largest statistics in relation to `380 MB`, and the result was:

```sh
slab_reclaimable 361475376 # ~= 361 MB (94% of the 383 MB reported by the working_set) 
```

[slab_reclaimable](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html), as documented, refers to a memory segment that can be released under memory pressure. However, in this specific version of `cAdvisor`, This interpretation is technically inaccurate in this context.

### slab_reclaimable can be freed

As a proof of point that this memory segment can be freed we can perform a operation inside the `node` running our `pod` to free the `fs cache`.

> Don't reproduce the next steps in a production environment

First let's find which `node` our `pod` is running trough the command:

```sh
kubectl get pod -A -o wide | grep -i 'YOUR-POD-NAME'
```

In my case the result was:

```sh
NAME                                                    READY   STATUS      RESTARTS       AGE     IP             NODE                                NOMINATED NODE   READINESS GATES
disk-writer                                             1/1     Running     2 (5m7s ago)   127m    10.244.0.216   aks-agentpool-17949162-vmss000006   <none>           <none>
```

Next we have to connect to that `node`, this is a more complex task so please read the doc to get more details: [Connect to Azure Kubernetes Service (AKS) cluster nodes for maintenance or troubleshooting](https://learn.microsoft.com/en-us/azure//AKS/node-access).

Inside the node we can run the write `1` on file `/proc/sys/vm/drop_caches` that is going to trigger the `dropping cache`:

```sh
echo 1 > /proc/sys/vm/drop_caches
```

Now we can check for any side effects by looking at the same `Grafana Dashboard` used earlier to identify the problem:

![working_set_after_drop_cache](/AKS/assets/images/tshoot-memory-consuption/working_set_after_drop.png)

We can see a huge decrease in the `working_set` that happened right after I ran the `dropping cache` procedure.

## Workaround

The only effective workaround for high memory consumption in `Kubernetes` is to set realistic `resource limits and requests` on your `pods`. By configuring appropriate memory [limits and requests](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits) in the `Kubernetes` or specification, you can ensure that `Kubernetes` manages `memory allocation` more efficiently, mitigating the impact of excessive `caching` on. While this does not resolve the underlying behavior of the `Linux kernel's caching` strategy, it provides a practical approach to maintaining stable and predictable resource usage in your cluster.

## Conclusion  

A detailed analysis of memory consumption in applications performing disk write operations in Kubernetes revealed a specific behavior of the filesystem and the `Linux kernel`. The intensive use of `Page Cache` to optimize read and write operations can lead to high memory consumption, even after the writing operations have completed. This behavior is reflected in the `working_set` metric, which excludes inactive `cached` memory, resulting in discrepancies between actual consumption and what is reported by the metric.  

The study demonstrated that a significant portion of the allocated memory was related to **slab reclaimable** objects, which are data structures `cached` by the kernel to optimize memory allocation. These `cached` data structures can be freed when the system is under memory pressure, explaining the difference between the memory consumption observed directly in the `cgroup` and the values reported by Kubernetes metrics.  

Therefore, the high memory consumption behavior in applications writing to disk can be attributed to the operating system’s caching strategy. While this does not necessarily indicate a performance issue, understanding how Kubernetes and the Linux kernel manage memory is crucial for optimizing and properly monitoring resource usage in production environments.  
