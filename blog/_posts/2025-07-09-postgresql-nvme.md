---
title: "Boosting PostgreSQL performance on AKS"
description: "Unlock blazing fast PostgreSQL performance on AKS with CloudNativePG and Azure Container Storage, using local NVMe for significant boosts in throughput and latency."
date: 2025-07-09 # date is important. future dates will not be published
author: Eric Cheng # must match the authors.yml in the _data folder
categories: 
- general 
- developer
- storage
- databases
---

## Introduction

[PostgreSQL](https://www.postgresql.org/) is one of the most popular stateful
workloads on Azure Kubernetes Service (AKS). Thanks to the support of a vibrant
community, we now have a strong PostgreSQL operator ecosystem that makes it
easier for everyone to self-host PostgreSQL on Kubernetes.

One of the leading operators driving PostgreSQL adoption is
[CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg), an
open-source PostgreSQL operator built from the ground up for Kubernetes.
CloudNativePG embraces Kubernetes-native patterns for stateful workloads. It
offers built-in support for high availability, rolling updates, backup
orchestration, and automated failover---all using native Kubernetes resources.

This tight Kubernetes integration leads to more predictable behavior, easier
observability, and a smoother developer experience. CloudNativePG is also a
CNCF-hosted project, developed in the open with wide community participation,
and backed by upstream PostgreSQL contributors. For teams looking to run
production-grade PostgreSQL in Kubernetes without managing custom scripts or
sidecars, CloudNativePG provides a straightforward and maintainable approach
without retrofitting traditional PostgreSQL management practices into container
environments.

However, optimizing PostgreSQL infrastructure performance can still be
challenging. In this post, we'll demystify challenges on how storage impacts
PostgreSQL and share how we dramatically improved performance on AKS by using
local NVMe storage with [Azure Container
Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction).

## The big bottleneck: storage

PostgreSQL's performance is tightly bound to storage I/O. To operate optimally,
PostgreSQL performs frequent disk writes for transaction logs (WAL) and
checkpoints. Even in predominantly read-heavy workloads, any write
operations---including inserts, updates, and deletes---must wait for the storage
subsystem to confirm that the WAL has been safely persisted, and any delay in
storage throughput or latency directly affects query performance and database
responsiveness.

This is because PostgreSQL is designed with strong durability guarantees: every
transaction must be written to the Write-Ahead Log (WAL) before it is considered
committed. If the underlying storage is slow or experiences high latency, these
commit operations become a major bottleneck, causing application slowdowns and
increased response times.

Additionally, PostgreSQL periodically performs checkpoints, flushing dirty pages
from memory to disk to ensure data consistency and enable crash recovery. During
these checkpoints, large bursts of I/O can occur, and if the storage cannot keep
up, it can lead to increased query latency or even temporary stalls. Background
processes like autovacuum and replication also generate significant I/O, further
amplifying the dependency on fast, low-latency storage.

In high-concurrency environments, the situation is even more pronounced: with
many clients issuing transactions simultaneously, the database's ability to
process requests is often limited not by CPU or memory, but by how quickly it
can read from and write to disk. As a result, storage IOPS (input/output
operations per second) and latency become the primary factors that determine
PostgreSQL's throughput and overall performance, especially for write-heavy or
latency-sensitive workloads.

## Storage options on AKS

AKS supports a variety of storage options through the Azure Disk CSI driver.
Let's dive into a few of them:

1. **Premium SSD**: These general-purpose SSDs are widely used and support
    availability features like ZRS (Zone Redundant Storage) and fast
    snapshotting. They're ideal for many workloads, but IOPS and throughput are
    still constrained by the VM's limits on remote disk access.

2. **Premium SSD v2**: An evolution of Premium SSDs, this option decouples
    storage size from performance, letting you scale IOPS and throughput
    independently. With up to 80,000 IOPS and 1,200 MB/s throughput, they're
    more cost-efficient for I/O-intensive workloads.

3. **Ultra Disk**: Azure's highest-performing remote disk offering, Ultra Disk
    supports up to 400,000 IOPS and 10,000 MB/s. However, achieving this full
    performance requires very large VMs such as the
    [Standard_E112ibds_v5](https://learn.microsoft.com/en-us/azure/virtual-machines/ebdsv5-ebsv5-series#ebdsv5-series-nvme)
    because remote disk performance is constrained by the VM's vCPU count and
    remote disk controller limits. This means you're forced to pay for massive
    compute resources just to unlock storage performance—even if your workload
    doesn't need 112 vCPUs.

## Benchmarking: PostgreSQL performance with Azure Container Storage

This is where **local NVMe** storage fundamentally changes the game. Unlike
remote disks that scale performance with VM size, local NVMe drives deliver
their full performance regardless of vCPU count because they're physically
attached to the VM and bypass the remote disk controller entirely.

Consider this stark contrast:

- **Ultra Disk**: To get 400,000 IOPS, you need a 112-vCPU VM
  ([Standard_E112ibds_v5](https://learn.microsoft.com/en-us/azure/virtual-machines/ebdsv5-ebsv5-series#ebdsv5-series-nvme))
- **Local NVMe**: An 8-vCPU
  ([Standard_L8s_v3](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/storage-optimized/lsv3-series?tabs=sizestoragelocal#sizes-in-series))
  VM delivers 400,000 IOPS out of the box

That's **14x fewer vCPUs** for the same IOPS performance, dramatically reducing
your compute costs. The trade-off is that you're shifting data durability from
the storage layer to the application layer, relying on PostgreSQL's WAL-based
replication and backup orchestration instead of underlying storage persistence
(which we address in the next section).

Historically, Kubernetes couldn't easily use local NVMe disks due to their
ephemeral nature and lack of built-in abstraction. [Azure Container Storage
solves
this](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-container-storage-with-local-disk):
it aggregates local NVMe devices across nodes into a storage pool and exposes
them through a Kubernetes-compatible storage class. You can reference this class
directly when creating PersistentVolumeClaims.

> *Hmm, is this something I can do with the Azure Disks CSI driver?*
>
> Not quite, which is what makes [Azure Container
> Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction)
> unique! Azure Container Storage lets you use advanced block storage products
> such as local NVMe, temp SSDs, and [Azure Elastic
> SAN](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-container-storage-with-elastic-san)
> to create the PVCs you need to run stateful applications on Kubernetes.

### What about persistence?

Yes, local NVMe is ephemeral—data is lost if the node is deallocated or the
cluster shuts down. Azure Container Storage provides an annotation for volumes
that enables a **persistence-aware mode**, which helps Kubernetes treat these
ephemeral volumes more predictably. This doesn't change the nature of the
storage—it simply signals to the platform and your team that you're opting into
these trade-offs knowingly.

So how do you make use of it for something as critical as a database?

This is where application-level resilience comes in. PostgreSQL's Write-Ahead
Log (WAL) ensures data durability by recording every change before it's applied,
enabling point-in-time recovery even if the primary disk is lost. Modern
operators like [CloudNativePG](https://cloudnative-pg.io) leverage this by
providing PostgreSQL-native high availability (HA), replicating data across
nodes. We show you how to set up automatic backups to Azure Blob Storage in our
[official AKS PostgreSQL deployment
guide](https://learn.microsoft.com/en-us/azure/aks/postgresql-ha-overview)

While data on any single NVMe volume is not durable, WAL-based replication and
backup orchestration ensure that PostgreSQL can recover to a consistent state
and continue functioning even if a node goes down. This approach provides
insulation from underlying storage failures and allows you to balance
performance with resilience.

### Benchmark results

So why go through all this trouble? *Because the performance is worth it!* Using
local NVMe with Azure Container Storage can provide 15,000+ transactions per
second and <4.5ms average latency on Standard_L16s_v3 virtual machines.

![image](/assets/images/postgresql-nvme/chart.png)

> If you're curious about our exact benchmark procedure, you can read
> [CloudNativePG's official benchmarking
> documentation](https://cloudnative-pg.io/documentation/1.26/benchmarking/#pgbench).
>
> In a nutshell, we initialized the database via `kubectl cnpg pgbench
> postgres-cluster -n postgres --job-name pgbench-init -- -i -s 1000`. This
> command generates a database of 100,000,000 records using a scale factor of
> 1000. Then, we ran the benchmark command `kubectl cnpg pgbench
> postgres-cluster -n postgres --job-name pgbench -- -c 64 -j 4 -t 10000 -P`
> which runs the test with 64 concurrent clients, four worker threads, and
> 10,000 records per client (for a total of 64,000). The `-p` is a nice added
> touch to monitor the progress of the test live. This simulates a
> medium-to-high load on a production-like system, stressing both throughput and
> latency.

We also benchmarked our setup on larger L-series VM SKUs, and discovered
performance increased to 26,000 transactions per second with 2.3ms average
latency on Standard_L64s_v3.

At a technical level, PostgreSQL benefits from local NVMe because its
architecture involves frequent small writes (WAL), background checkpointing, and
page flushing---all of which are extremely sensitive to disk latency. Local NVMe
delivers consistent microsecond-scale latency and high IOPS, giving PostgreSQL
the I/O headroom it needs to scale under pressure.

We encourage you to benchmark PostgreSQL and Azure Container Storage
yourself. For your convenience, we're sharing our [setup
scripts](https://github.com/eh8/acstor-pgsql) if you want to give it a shot. We
encourage you to experiment with different virtual machines in your nodepool,
different PostgreSQL parameters, and other AKS features! Some caveats to
remember as you test different scenarios, particularly super large virtual
machines:

- Our benchmarking tool, pgbench, also stresses CPU and memory, so it's not
    purely I/O-bound.

- High availability via CloudNativePG introduces synchronization overhead that
    limits maximum throughput. Once storage IOPS exceed a certain threshold, HA
    and replication become the new bottlenecks.

- Those of you with sharp eyes might notice that we separate pgdata and the WAL
    onto different volumes when using Premium SSD/Premium SSD v2 and the Azure
    Disk CSI driver. This is a [recommended best
    practice](https://cloudnative-pg.io/documentation/current/storage/#volume-for-wal)
    from CloudNativePG, with one key reason being that this configuration
    doubles the total pool of IOPS by creating two separate disks. But with
    local NVMe-backed storage pools, all I/O is hitting the same set of NVMe
    drives, so separate volumes doesn't add performance.

## What's next

We're continuing to invest in simplifying and accelerating stateful workloads on
Kubernetes. In our next release of Azure Container Storage, we're reducing
PostgreSQL latency even further and increasing throughput, all while keeping the
developer experience seamless.

If you're running PostgreSQL on AKS and are looking to squeeze out more
performance without overpaying for compute, local NVMe + Azure Container Storage
might be the best setup you haven't tried yet.

Want to try everything out for yourself? Visit our newly renovated guide on
[deploying PostgreSQL in Azure Kubernetes Service with
CloudNativePG](https://learn.microsoft.com/en-us/azure/aks/postgresql-ha-overview),
as well as the [benchmarking scripts](https://github.com/eh8/acstor-pgsql) we
used for this blog post.
