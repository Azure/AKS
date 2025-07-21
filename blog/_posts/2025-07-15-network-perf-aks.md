---
title: "Performance Tuning AKS for Network Intensive Workloads "
description: "Learn more about how to optimize network performance on AKS nodes through benchmark and comparison."
date: 2025-07-15 # date is important. future dates will not be published
authors:
- Anson Qian
- Alyssa Vu
categories:
- performance
- networking
---

## Background

As more intelligent applications are deployed and hosted on Azure Kubernetes Service (AKS), network performance becomes increasingly critical to ensuring a seamless user experience. For example, an chatbot server running in an AKS cluster need handle high volumes of network traffic with low latency, while retrieving contextual data — such as conversation history and user feedback from a database or cache, and interacting with a LLM (Large Language Model) endpoint through prompt requests and streamed inference responses.

In this blog post, we share how we conducted simple benchmark to evaluate and compare network performance across various VM (Virtual Machine) SKU and series. We also provide recommendations on key kernel settings to help you explore the trade-offs between network performance and resource usage.

## Benchmark
Our methodology involves conducting tests and measurements to identify key factors affecting network performance for applications running on AKS. We simulated a common use case: a pair of pods communicating in TCP protocol across two different nodes within the same AKS cluster. We measured various performance metrics, including throughput, round-trip time (RTT), and retransmission rate in the presence of packet loss at high bandwidth usge.

In our experiment, iperf3 was run as a container within Kubernetes pods on selected nodes to generate single or multiple TCP streams simulating application traffic. All underlying Kubernetes nodes had identical hardware specifications: 48 CPU cores, 192 GB of memory, and were running Linux 5.X kernenls. During each test, we also monitor cpu and memory usage of both client and server containers to make sure iperf3 is not resource constrained.

## Hardware Matters Most

We compared the test results of Azure's older generation series [Dsv3](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv3-series?tabs=sizebasic) and newer generation series [Dsv6](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv6-series?tabs=sizebasic) on AKS, as well as AWS next-generation instances [M7i](https://aws.amazon.com/ec2/instance-types/m7i/) on EKS, and observated signifncant network performance difference:

Up to 35% higher throughput for Azure Dsv6 compared to Dsv3 and AWS M7i when trying to maximize network bandwidth usage.

![image](/assets/images/network-perf-aks/sku_throughput.png)


Up to 3x~6x lower RTT for Azure Dsv6 compared to Dsv3 and AWS M7i when tests are limited to the same network badnwdith usage.

![image](/assets/images/network-perf-aks/sku_rtt.png)

TCP retransmissions remained consistently at 0% on Azure Dsv6, matching AWS M7i while significantly outperforming Azure Dsv3.

![image](/assets/images/network-perf-aks/sku_retran.png)

The primary reasons for the significant leap in network performance on Dsv6 is because the next-generation network interface [Microsoft Azure Network Adaptor (MANA)](https://learn.microsoft.com/en-us/azure/virtual-network/accelerated-networking-mana-overview) support [Jumbo Frame](https://en.wikipedia.org/wiki/Jumbo_frame) and [MTU 9000](https://learn.microsoft.com/en-us/azure/virtual-network/how-to-virtual-machine-mtu?tabs=linux).

A higher MTU (Maximum Transmission Unit) and MSS (Maximum Segment Size) allow TCP traffic to transmit more data per packet, reducing the total number of packets that need to be processed by network interface and OS kernenl. This leads to fewer hardware interrupts, less buffering, and reduced overhead in data movement, ultimately improving overall network efficiency.

![image](/assets/images/network-perf-aks/sku_mtu.png)

We realized there is no way to fully abstract hardware from the application — fundamentally, application network performance is dictated by the capabilities of the underlying CPU, memory, and network interfaces on the physical host. Identifying the appropriate VM SKU and series is essential to ensure the application meets its networking performance requirements.

![image](/assets/images/network-perf-aks/sku_cpu_usage.png)

The MTU on Azure Dsv6-series VMs is not set to 9000 by default. You can manually adjust the MTU for a specific network interface using the following Linux command:
```bash
ip link set $device mtu 9000
```
To enable Jumbo Frames across all nodes in an AKS cluster, you can deploy a [example daemonset](https://github.com/Azure/telescope/blob/c217665271666131cc4c78ee391db967a808fa48/modules/kustomize/mtu/overlays/azure/patch.yaml#L16). In addition, you can optimize MTU settings dynamically using [Path MTU Discovery](https://learn.microsoft.com/en-us/azure/virtual-network/how-to-virtual-machine-mtu?tabs=linux#path-mtu-discovery)


## Kernel Settings Tuning

If migrating to a newer VM SKU or series like Dsv6 isn’t a viable short-term option due to capacity constraints or compatibility concerns, kernel-level tuning remains a practical path to improving network performance. In our testing, we explored several tuning parameters and found that adjusting the ring buffer size on the network interface card (NIC) had the most significant impact. As shown below, increasing the NIC receive buffer size from the default 1024 bytes to 2048 bytes on a Dsv3 VM resulted in a noticeable improvement in network throughput. 

![image](/assets/images/network-perf-aks/buffer_throughput.png)

We also observed reductions in both TCP retransmission rate and round-trip time (RTT) under a combined bandwidth load of 15 Gbps. The benefit was especially pronounced when traffic was split across three parallel TCP streams, each operating at 5 Gbps.
![image](/assets/images/network-perf-aks/buffer_rtt.png) 

TCP retransmissions often occur when the sender or receiver buffer is too small to handle surge of packets, resulting in packet drops. This is commonly indicated by errors like rx_no_buffer, which signal that the network interface card (NIC) couldn't allocate enough buffer space for incoming packets. To improve performance on existing VMs like Dsv3, adjusting the NIC ring buffer settings can be an effective tuning approach.

![image](/assets/images/network-perf-aks/buffer_retran.png)

It’s important to note that increasing the NIC ring buffer size has memory usage implications. Allocating larger buffers means the operating system reserves more memory specifically for handling network traffic, which reduces the amount of memory available for user-space applications. For example, doubling the receive buffer size from 1024 to 2048 bytes per descriptor across multiple queues and interfaces can lead to a non-trivial increase in kernel memory usage — especially on systems with high network concurrency or multiple high-throughput NICs. While this tradeoff can significantly improve network performance, especially under high load, it should be balanced against the memory demands of the application workload running on the same VM.

## Conclusion

Achieving optimal network performance on AKS requires a combination of choosing the right VM SKU and series  and fine-tuning kernel-level parameters. By understanding the trade-offs and evaluating different options, AKS users can unlock meaningful improvements in network performance and application responsiveness. In the future, we plan to expand our benchmarks to include newer Linux 6.x kernels, which incorporate recent [networking enhancements](https://conferences.computer.org/sc-wpub/pdfs/SC-W2024-6oZmigAQfgJ1GhPL0yE3pS/555400a775/555400a775.pdf). We also intend to analyze both inbound and outbound networking performance on AKS and explore further optimization strategies.