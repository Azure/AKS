---
title: "Azure Container Storage v2.1.0: Now GA with Elastic SAN"
description: "Explore what’s new in Azure Container Storage v2.1.0 with Elastic SAN integration, modular on-demand installation, and enhanced node selector support."
date: 2026-04-08 # date is important. future dates will not be published
authors:
  - saurabh-sharma
tags:
  - general
  - developer
  - storage
  - databases
---

Stateful workloads on Kubernetes continue to demand not only faster performance but also larger scale and more streamlined operational simplicity. [Azure Container Storage v2.1.0](https://learn.microsoft.com/azure/storage/container-storage/container-storage-introduction) is now generally available with three headline improvements:

**Elastic SAN (ESAN) integration**: consolidate hundreds of persistent volumes under a single managed ESAN, bypassing VM disk-attachment limits

**Modular on-demand installation**: deploy only the components your chosen storage type requires, reducing install time and cluster footprint

**Node selector support**: control where Azure Container Storage components run so you can optimize resource usage across node pools

<!-- truncate -->

![Azure Container Storage v2.1.0 architecture overview](./acstorv2-architecture.png)

## Why Elastic SAN for Kubernetes storage

[Elastic SAN](https://learn.microsoft.com/azure/storage/elastic-san/) is a managed, shared block storage service that provides a central pool of capacity and performance including IOPS and throughput. From this pool, you create multiple volumes and attach them to many compute resources.

Below are example ESAN “base capacity” sizes and the ESAN-level provisioned performance you get from that base size (because ESAN scales SAN IOPS + throughput linearly with base TiB). Specifically, each 1 TiB of base capacity adds 5,000 IOPS and 200 MB/s throughput; additional/capacity-only TiB does not increase IOPS or throughput.

| Base capacity (TiB) | ESAN provisioned IOPS | ESAN provisioned throughput |
| --- | --- | --- |
| 1 | 5,000 | 200 MB/s |
| 2 | 10,000 | 400 MB/s |
| 5 | 25,000 | 1,000 MB/s |
| 50 | 250,000 | 10,000 MB/s |
| 200 | 1,000,000 | 40,000 MB/s |

Here are the key advantages we see customers looking for:

**Scalability beyond VM disk limits**: ESAN uses iSCSI over TCP/IP for volume connectivity, which bypasses traditional VM disk attachment constraints (for example, limits such as 64 disks per VM). On AKS Linux nodes, iSCSI sessions aren't constrained by the same disk-attachment limits, so you can attach significantly more PVs per node. This is a key differentiator for high-volume PV scenarios.

**Cost efficiency through storage consolidation**: Elastic SAN provisions capacity at the TiB level, enabling you to consolidate hundreds (or thousands) of smaller GiB-scale PVs under a single SAN. This reduces overprovisioning and lowers management overhead. Use the [ESAN pricing calculator](https://azure.microsoft.com/pricing/calculator/?msockid=386fb3dcdad3644830f9a576dbe16569) for a cost estimation of your storage requirements.

**Fast attach/detach for burst scale scenarios**: iSCSI session establishment is fast and avoids disk-centric attachment throttling patterns, which matters during burst scale when dozens to hundreds of pods come and go quickly.

**Simplified management with an on-ramp to open-source flexibility**: Azure Container Storage v2 is designed so you install only the components needed for the selected storage type. The SAN CSI Driver is also planned to be open sourced to give customers flexibility in how they orchestrate storage.

## Which workloads benefit most

Elastic SAN with Azure Container Storage is a strong fit for stateful workloads that combine many volumes with elastic provisioning needs. Here are a few workload patterns we’ve seen align well:

**Database as a service (DBaaS) and multi-tenant database platforms**: Many customers run containerized databases such as PostgreSQL and beyond on AKS, either as DBaaS offerings or shared, multi-tenant platforms. In these scenarios, storage choices have a direct impact on scalability, performance, durability, and day‑to‑day operability.
Common requirements include:

- Scaling database instances efficiently while keeping infrastructure overhead under control
- Fast provisioning and attachment of many PVs, especially in multi-tenant or bursty environments
- Avoiding monolithic installs when only a single storage backend is needed
  
**Large-scale developer environments and per-user volumes**: Another pattern is per-user or per-project environments where each user instance maps to a PV. One example described in planning is a large environment with many pods across multiple clusters, where daily burst creation can stress volume provisioning and attachment if implemented as thousands of independent disks. Elastic SAN enables consolidating volumes under a SAN and accelerating provisioning/attachment flows compared to disk-per-PV approaches.

For using ESAN with Azure Container Storage, see the [configure Elastic SAN documentation](https://learn.microsoft.com/azure/storage/container-storage/use-container-storage-with-elastic-san?tabs=cli).

## On-demand installation model

Azure Container Storage v2.1.0 supports a lightweight, modular installation model. You can enable Azure Container Storage first, then choose a backing storage type when you need it, deploying only the components required for that storage type. You can also add, update, or remove storage components after the initial setup. It supports two installation flows:

**Flow A**: Enable Azure Container Storage and choose storage type upfront
If you know which storage type (local NVMe/Elastic SAN) you want to use upfront, enable Azure Container Storage with your preferred storage type so the relevant driver and a default StorageClass can be configured.

**Flow B**: Enable Azure Container Storage first, then add storage type later
If you want to keep the initial install lightweight, you can enable Azure Container Storage first and then create a StorageClass of your preferred storage type which triggers installation of the respective CSI driver when you need it.

For detailed steps, see the [on-demand installation documentation](https://learn.microsoft.com/azure/storage/container-storage/install-container-storage-aks?pivots=azurecli).

## Node selector support for component placement

In production clusters, running every component on every node usually isn’t the goal. You might have:

- a dedicated node pool optimized for storage-heavy workloads
- GPU pools where you want to minimize background DaemonSet footprint
- mixed compute/storage topologies where placement matters

Azure Container Storage v2.1.0 adds node selector support so you can control where Azure Container Storage components run, helping optimize performance and resource usage. The local CSI drivers can be deployed only in selected node pools by configuring node affinity based on the agentpool label. The following example shows a StorageClass configuration:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
  annotations:
    storageoperator.acstor.io/nodeAffinity: |
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.azure.com/agentpool
            operator: In
            values: [mygpu,mygpu2]
provisioner: localdisk.csi.acstor.io
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

For more details on configuring component placement, see the [node selector documentation](https://learn.microsoft.com/en-us/azure/storage/container-storage/manage-local-container-storage-interface-driver-placement).

## Practical guidance

- Validate scale targets in your environment: very high PV density scenarios should be tested with your workload’s I/O patterns and cluster topology.

- Use node selectors to align component placement with your node pool strategy (for example, dedicated storage pools or mixed pools).

- Consolidate where it makes sense: Elastic SAN is most compelling when you have many PVs and want centralized capacity/performance management.

## Getting started with Azure Container Storage v2.1.0

Ready to run your stateful workloads using Azure Container Storage v2.1.0? Here are your next steps:

- New to Azure Container Storage? Start with our [comprehensive documentation](https://learn.microsoft.com/azure/storage/container-storage/container-storage-introduction)

- Want to use Azure Elastic SAN as storage type? Follow [the step-by-step guide](https://learn.microsoft.com/azure/storage/container-storage/use-container-storage-with-elastic-san?tabs=cli)

- Want to use local NVMe as storage type? Follow [the step-by-step guide](https://learn.microsoft.com/azure/storage/container-storage/use-container-storage-with-local-disk)

- Deploying specific workloads? Check out our updated deployment guide for [PostgreSQL](https://learn.microsoft.com/azure/aks/postgresql-ha-overview)

- Want the open-source local CSI driver? Visit our [GitHub repository](https://github.com/Azure/local-csi-driver) for installation instructions

- Have questions or feedback? Reach out to our team at [AskContainerStorage@microsoft.com](mailto:AskContainerStorage@microsoft.com)
