---
title: "Performance Tuning AKS for Network Intensive Workloads "
description: "Learn more about how to optimize network I/O performance on AKS nodes through benchmark and comparison."
date: 2025-07-15 # date is important. future dates will not be published
author:
- Anson Qian
- Alyssa Vu
categories:
- performance
- networking
---

## Background

As more intelligent applications are deployed and hosted on Azure Kubernetes Service (AKS), network I/O performance becomes increasingly critical to ensuring a seamless user experience. For example, an chatbot server running in an AKS cluster need handle high volumes of network traffic with low latency, while retrieving contextual data — such as conversation history and user feedback from a database or cache, and interacting with a LLM (Large Language Model) endpoint through prompt requests and streamed inference responses.

In this blog post, we share how we conducted simple benchmark to evaluate and compare network performance across various VM (Virtual Machine) SKU and series. We also provide recommendations on key kernel settings to help you explore the trade-offs between network performance and resource usage.

## Benchmark
Our methodology involves conducting tests and measurements to identify key factors affecting network performance for applications running on AKS. We simulated a common use case: a pair of pods communicating in TCP protocol across two different nodes within the same AKS cluster. We measured various performance metrics, including throughput, round-trip time (RTT), and retransmission rate in the presence of packet loss.

In our experiment, iperf3 was run as a container within Kubernetes pods on selected nodes to generate TCP streams simulating application traffic. All underlying Kubernetes nodes had identical hardware specifications: 48 CPU cores, 192 GB of memory, and were running Linux with kernel version 5. During each test, we also monitor cpu and memory usage of both client and server containers to make sure iperf3 is not resource constrainted.

## Hardware Matters Most

We compared the test results of Azure's older generation series [Dsv3](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv3-series?tabs=sizebasic) and newer generation series [Dsv6](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv6-series?tabs=sizebasic) on AKS, as well as AWS next-generation instances [M7i](https://aws.amazon.com/ec2/instance-types/m7i/) on EKS, and observated signifncant network performance difference:

1. Up to 35% higher throughput for Azure Dsv6 compared to Dsv3 and AWS M7i when tests were designed to maximize network bandwidth usage.

![image](/assets/images/network-perf-aks/single_stream_throughput.png)

2. Up to 50% lower RTT for Azure Dsv6 compared to Dsv3 and AWS M7i when tests are limited to the same network badnwdith usage.

![image](/assets/images/network-perf-aks/single_stream_rtt.png)

3. TCP retransmissions remained consistently at 0% on Azure Dsv6, matching AWS M7i and significantly outperforming Azure Dsv3

![image](/assets/images/network-perf-aks/single_stream_retransmits.png)

The primary reasons for the significant leap in network performance on Dsv6 is because of support [Jumbo Frames (MTU 9000)](https://learn.microsoft.com/en-us/azure/virtual-network/how-to-virtual-machine-mtu?tabs=linux) with [Microsoft Azure Network Adaptor (MANA)](https://learn.microsoft.com/en-us/azure/virtual-network/accelerated-networking-mana-overview)


![image](/assets/images/network-perf-aks/mtu.png)

A higher MTU (Maximum Transmission Unit) and MSS (Maximum Segment Size) allow TCP traffic to transmit more data per packet, reducing the total number of packets that need to be processed. This leads to fewer hardware interrupts, less buffering, and reduced overhead in data movement, ultimately improving overall network efficiency.

![image](/assets/images/network-perf-aks/cpu_usage.png)

We realized there is no way to fully abstract hardware from the application — fundamentally, application network performance is dictated by the capabilities of the underlying CPU, memory, and network interfaces on the physical host. Identifying the appropriate VM SKU and series is essential to ensure the application meets its networking performance requirements.
