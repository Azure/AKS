---
title: "Boosting PostgreSQL performance on AKS"
description: "Unlock high-performance PostgreSQL on AKS with CloudNativePG and Azure Container Storage using local NVMe for big throughput/latency improvements."
date: 2025-06-16 # date is important. future dates will not be published
author: Eric Cheng # must match the authors.yml in the _data folder
categories: 
# - general 
# - general
# - operations
# - networking
# - security
- developer
# - add-ons
---

## Introduction

[PostgreSQL](https://www.postgresql.org/) is one of the most popular stateful workloads on Azure Kubernetes
Service (AKS). Thanks to a vibrant community, there's now a robust operator ecosystem, making it easy to self-host PostgreSQL on Kubernetes across all major cloud platforms.

One of the key enablers of this momentum is
[CloudNativePG](https://cloudnative-pg.io), an open-source PostgreSQL
operator built from the ground up for Kubernetes. CloudNativePG embraces
Kubernetes-native patterns for stateful workloads. It offers built-in
support for high availability, rolling updates, backup orchestration,
and automated failover---all using native Kubernetes resources.

This tight integration leads to more predictable behavior, easier
observability, and a smoother developer experience. CloudNativePG is
also a CNCF-hosted project, developed in the open with wide community
participation, and backed by upstream PostgreSQL contributors. For teams
looking to run production-grade PostgreSQL in Kubernetes without
managing custom scripts or sidecars, CloudNativePG provides a clean, maintainable approach without retrofitting
traditional PostgreSQL management practices into container environments.

However, optimizing PostgreSQL performance can still be challenging. In
this post, we'll demystify challenges on how storage impacts PostgreSQL
and share how we dramatically improved performance on AKS by using local
NVMe storage with [Azure Container Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction).

## The big bottleneck: storage

PostgreSQL's performance is tightly bound to storage I/O. To operate
optimally, PostgreSQL performs frequent disk writes for transaction logs
(WAL) and checkpoints, even during read-heavy workloads. Any delay in
storage throughput or latency directly affects query performance and
database responsiveness.

## Storage options on AKS

AKS supports a variety of storage options through the Azure Disk CSI
driver. Let's dive into a few of them:

1. **Premium SSD**: These general-purpose SSDs are widely used and support availability
    features like ZRS (Zone Redundant Storage) and fast snapshotting.
    They're ideal for many workloads, but IOPS and throughput are still
    constrained by the VM's limits on remote disk access.

2. **Premium SSD v2**: An evolution of Premium SSDs, this option decouples storage size
    from performance, letting you scale IOPS and throughput
    independently. With up to 80,000 IOPS and 1,200 MB/s throughput,
    they're more cost-efficient for I/O-intensive workloads.

3. **Ultra Disk**: Azure's highest-performing remote disk offering, Ultra Disk supports
    up to 400,000 IOPS and 10,000 MB/s. However, this raw performance
    can only be utilized on select VM sizes that can keep up with
    it, like the [Standard_E112ibds_v5](https://learn.microsoft.com/en-us/azure/virtual-machines/ebdsv5-ebsv5-series). Most workloads can't unlock this full potential due to VM throughput bottlenecks.

## Benchmarking: PostgreSQL performance with Azure Container Storage

All of these remote disks still hit a ceiling: the IOPS limit of the
VM's remote disk controller. That's where **local NVMe** storage comes
in.

Local NVMe drives are physically attached to the VM, bypassing remote
I/O limitations. Even a modest 8-core VM can deliver up to 400,000 IOPS
immediately because there's no network overhead.

Historically, Kubernetes couldn't easily use local NVMe disks due to
their ephemeral nature and lack of built-in abstraction. Azure Container
Storage solves this: it aggregates local NVMe devices across nodes into
a storage pool and exposes them through a Kubernetes-compatible storage
class. You can reference this class directly when creating
PersistentVolumeClaims.

### What about persistence?

Yes, local NVMe is ephemeral---data is lost if the node is deallocated
or the cluster shuts down. So how do you make use of it for something as
critical as a database?

Modern operators like [CloudNativePG](https://cloudnative-pg.io) enable
PostgreSQL-native high availability (HA), allowing you to replicate data
across nodes. While data on any single NVMe volume is not durable,
replication ensures that PostgreSQL continues to function even if a node
goes down.

Azure Container Storage also provides an annotation for volumes that
enables a **persistence-aware mode**, which helps Kubernetes treat these
ephemeral volumes more predictably. This doesn't change the nature of
the storage---it simply signals to the platform and your team that
you're opting into these trade-offs knowingly.

### Benchmark results

So why go through all this trouble? *Because the performance is worth it!* Using local NVMe with Azure
Container Storage as shown in our [official AKS PostgreSQL deployment
guide](https://learn.microsoft.com/en-us/azure/aks/postgresql-ha-overview)
can provide 15,000+ transactions per second and <4.5ms average latency
on Standard_L16s_v3 virtual machines.

![image](/assets/images/postgresql-nvme/graph.png)

We also benchmarked our setup on larger L-series VM SKUs, and discovered
performance increased to 26,000 transactions per second with 2.3ms
average latency on Standard_L64s_v3.

At a technical level, PostgreSQL benefits from local NVMe because its
architecture involves frequent small writes (WAL), background
checkpointing, and page flushing---all of which are extremely sensitive
to disk latency. Local NVMe delivers consistent microsecond-scale
latency and high IOPS, giving PostgreSQL the I/O headroom it needs to
scale under pressure.

We encourage you to set benchmark PostgreSQL and Azure Container Storage
yourself. For your convenience, we're sharing our [setup
scripts](https://github.com/eh8/acstor-pgsql) if you want to give it a
shot. We encourage you to experiment with different virtual machines in
your nodepool, different PostgreSQL parameters, and other AKS features!
Some caveats to remember as you test different scenarios, particularly
super large virtual machines:

- Our benchmarking tool, pgbench, also stresses CPU and memory, so
    it's not purely I/O-bound.

- High availability via CloudNativePG introduces synchronization
    overhead that limits maximum throughput. Once storage IOPS exceed a
    certain threshold, HA and replication become the new bottlenecks.

- Those of you with sharp eyes might notice that we separate pgdata
    and the WAL onto different volumes when using Premium SSD/Premium
    SSD v2 and the Azure Disk CSI driver. This is a [recommended best
    practice](https://cloudnative-pg.io/documentation/current/storage/#volume-for-wal)
    from CloudNativePG, with one key reason being that this
    configuration doubles the total pool of IOPS by creating two
    separate disks. But with local NVMe-backed storage pools, all I/O is
    hitting the same set of NVMe drives, so separate volumes doesn't add
    performance.

## What's next

We're continuing to invest in simplifying and accelerating stateful
workloads on Kubernetes. In our next release of Azure Container Storage,
we're reducing PostgreSQL latency even further and increasing
throughput---while keeping the developer experience seamless.

If you're running PostgreSQL on AKS and are looking to squeeze out more
performance without overpaying for compute, local NVMe + Azure Container
Storage might be the best setup you haven't tried yet.
