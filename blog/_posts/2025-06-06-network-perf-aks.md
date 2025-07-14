---
title: "Performance Tuning AKS for Network Intensive Workloads "
description: "Learn more about how to optimize network I/O performance on AKS nodes through benchmark and comparison."
date: 2025-06-06 # date is important. future dates will not be published
   - Anson Qian
   - Alyssa Vu
categories:
- performance
- networking
---

## Background

As more intelligent applications are deployed and hosted on Azure Kubernetes Service (AKS), network I/O performance becomes increasingly critical to ensuring a seamless user experience. For example, an chatbot server running in an AKS cluster need handle high volumes of network traffic with low latency, while retrieving contextual data — such as conversation history and user feedback from a database and interacting with a LLM (Large Language Model) endpoint through prompt requests and streamed inference responses.

In this blog post, we share how we conducted simple benchmark tests to evaluate and maximize network performance across various VM (Virtual Machine) SKU, size and series options. We also provide recommendations on key kernel settings to help you explore the trade-offs between network performance and resource usage.

## Benchmark
Our methodology involves conducting tests and comparisons to identify key factors affecting network performance for applications running on AKS. We simulated a common use case: a pair of pods communicating in TCP protocol across two different nodes within the same AKS cluster. We measured various performance metrics, including throughput, round-trip time (RTT), and retransmission rate in the presence of packet loss.

In our experiment, iperf3 was run as a container within Kubernetes pods on selected nodes to generate TCP streams simulating application traffic. All underlying Kubernetes nodes had identical hardware specifications: 48 CPU cores, 192 GB of memory, and were running Linux with kernel version 5.

