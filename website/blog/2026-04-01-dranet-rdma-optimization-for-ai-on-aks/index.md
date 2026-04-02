---
title: "Optimizing RDMA performance for AI workloads on AKS with DRANET"
date: "2026-04-01"
description: "Use DRANET with Dynamic Resource Allocation (DRA) to achieve topology-aware GPU and InfiniBand NIC scheduling on AKS, delivering up to 4.5x better NCCL collective performance through NUMA alignment and placement group awareness."
authors: ["anson-qian"]
tags: ["ai", "gpu", "networking", "performance"]
---

Large-scale AI training on Kubernetes depends on high-throughput, low-latency GPU-to-GPU communication. On Azure's ND GB300-v6 VMs, each node exposes four NVIDIA GB300 GPUs and four 800 Gb/s InfiniBand NICs spread across two NUMA domains. Scheduling a workload onto the wrong NIC -- one on a different NUMA node than the GPU -- can silently degrade collective performance by 4.5x or more.

[DRANET](https://github.com/anson627/dranet) is an open-source DRA network driver that discovers InfiniBand-only RDMA devices, exposes their topology as Kubernetes DRA attributes, and injects only the allocated `/dev/infiniband/uverbsN` devices into each container. Combined with the NVIDIA GPU DRA driver, it enables topology-aware co-scheduling of GPUs and NICs without requiring privileged containers.

In this post, we walk through how DRANET works on AKS with ND GB300-v6 nodes, demonstrate three NUMA placement scenarios, and show the benchmark results.

<!-- truncate -->

## The problem: NUMA-blind scheduling hurts RDMA performance

On an ND GB300-v6 node, the hardware topology looks like this:

| Resource | Count | Detail |
|---|---|---|
| GPU | 4x NVIDIA GB300 | 288 GB HBM3E each, NVLink-18 all-to-all |
| NIC | 4x Mellanox ConnectX | 800 Gb/s InfiniBand each |
| NUMA nodes | 2 | 2 GPUs + 2 NICs per NUMA node |

The NUMA topology (from `nvidia-smi topo -m`) reveals the affinity relationships:

|      | GPU0 | GPU1 | GPU2 | GPU3 | NIC0 | NIC1 | NIC2 | NIC3 |
|------|------|------|------|------|------|------|------|------|
| GPU0 | X    | NV18 | NV18 | NV18 | NODE | NODE | SYS  | SYS  |
| GPU1 | NV18 | X    | NV18 | NV18 | NODE | NODE | SYS  | SYS  |
| GPU2 | NV18 | NV18 | X    | NV18 | SYS  | SYS  | NODE | NODE |
| GPU3 | NV18 | NV18 | NV18 | X    | SYS  | SYS  | NODE | NODE |

GPUs 0-1 and NICs 0-1 share NUMA node 0. GPUs 2-3 and NICs 2-3 share NUMA node 1. A **NODE** relationship means the GPU and NIC share a direct PCIe root complex, enabling GPU-Direct RDMA (GDR). A **SYS** relationship means data must cross the QPI/UPI interconnect between NUMA domains, disabling GDR and adding latency.

Without topology-aware scheduling, Kubernetes has no way to co-locate a GPU and its NUMA-local NICs in the same resource claim. NCCL will work, but silently fall back to slower data paths.

## How DRANET solves this

The following diagrams show how the control plane and data plane components work together to achieve topology-aware GPU and NIC alignment.

**Control plane**: DRA drivers discover hardware topology and publish ResourceSlices. The scheduler evaluates CEL selectors from ResourceClaimTemplates to allocate NUMA-aligned GPU and NIC pairs.

![Control plane diagram showing DRA drivers publishing device topology to ResourceSlices, and the scheduler evaluating CEL selectors to allocate NUMA-aligned GPU and NIC pairs](./control-plane-diagram.svg)

**Data plane**: Once the scheduler binds a pod, the kubelet instructs containerd to create the container. DRANET's NRI plugin intercepts the OCI hook and injects only the allocated InfiniBand devices, enabling GPU-Direct RDMA over NUMA-local PCIe paths.

![Data plane diagram showing kubelet, containerd, NRI plugin injecting allocated InfiniBand devices into the pod, with NUMA-aligned GPU-NIC PCIe GDR paths](./data-plane-diagram.svg)

DRANET is a DRA network resource driver that runs as a DaemonSet on each node. It handles three key tasks:

### 1. Discovering InfiniBand-only devices

The ConnectX VFs on GB300 nodes operate in InfiniBand mode -- they have no Ethernet netdev interface. DRANET discovers them by:

- Skipping IPoIB interfaces during netdev discovery
- Recording the RDMA link name (`rdmaDevice`) on each PCI device
- Identifying IB-only devices as those with a non-empty `rdmaDevice` and no `ifName`

### 2. Publishing DRA device attributes

DRANET publishes a `ResourceSlice` for each node, exposing each NIC with topology attributes:

```yaml
spec:
  devices:
  - name: pci-0101-00-00-0
    attributes:
      dra.net/numaNode:
        int: 0
      dra.net/pciAddress:
        string: "0101:00:00.0"
      dra.net/rdma:
        bool: true
      dra.net/rdmaDevice:
        string: mlx5_0
      dra.net/pciVendor:
        string: Mellanox Technologies
  driver: dra.net
```

The NVIDIA GPU DRA driver (`gpu.nvidia.com`) similarly publishes GPU attributes including `pciBusID` and `pcieRoot`. Together, these attributes give the Kubernetes scheduler enough information to make NUMA-aligned allocation decisions.

Here are the full device inventories on a GB300 node:

**GPUs** (driver: `gpu.nvidia.com`):

| Device | pciBusID | NUMA | pcieRoot |
|---|---|---|---|
| gpu-0 | 0008:06:00.0 | 0 | pci0008:00 |
| gpu-1 | 0009:06:00.0 | 0 | pci0009:00 |
| gpu-2 | 0018:06:00.0 | 1 | pci0018:00 |
| gpu-3 | 0019:06:00.0 | 1 | pci0019:00 |

**NICs** (driver: `dra.net`):

| Device | pciAddress | rdmaDevice | NUMA |
|---|---|---|---|
| pci-0101-00-00-0 | 0101:00:00.0 | mlx5_0 | 0 |
| pci-0102-00-00-0 | 0102:00:00.0 | mlx5_1 | 0 |
| pci-0103-00-00-0 | 0103:00:00.0 | mlx5_2 | 1 |
| pci-0104-00-00-0 | 0104:00:00.0 | mlx5_3 | 1 |

### 3. Enforcing device isolation

At pod start, DRANET's NRI (Node Resource Interface) plugin injects only the allocated `/dev/infiniband/uverbsN` character devices into the container. Without this, all four `uverbs*` devices would be visible in every pod, providing no isolation between workloads -- and no need for `privileged: true`.

## ResourceClaimTemplates for topology-aware allocation

Using CEL (Common Expression Language) selectors in `ResourceClaimTemplates`, you can express precise GPU-NIC co-location constraints. We define three templates to demonstrate different NUMA placement strategies.

### 1nic-aligned: 1 GPU + 1 NIC, same NUMA

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: 1nic-aligned
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
          count: 1
          selectors:
          - cel:
              expression: >-
                device.attributes["resource.kubernetes.io"].pciBusID == "0008:06:00.0"
      - name: nic
        exactly:
          deviceClassName: dranet.net
          count: 1
          selectors:
          - cel:
              expression: >-
                device.attributes["dra.net"]["rdmaDevice"] == "mlx5_0"
```

GPU 0 (NUMA 0) paired with mlx5_0 (NUMA 0). **NODE** affinity provides a direct PCIe path for GDR.

### 2nic-aligned: 1 GPU + 2 NICs, same NUMA

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: 2nic-aligned
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
          count: 1
          selectors:
          - cel:
              expression: >-
                device.attributes["resource.kubernetes.io"].pciBusID == "0008:06:00.0"
      - name: nic
        exactly:
          deviceClassName: dranet.net
          count: 2
          selectors:
          - cel:
              expression: >-
                device.attributes["dra.net"]["rdma"] == true &&
                device.attributes["dra.net"]["numaNode"] == 0
```

GPU 0 (NUMA 0) paired with both RDMA NICs from NUMA 0 (mlx5_0 + mlx5_1). The `count: 2` with a NUMA selector is the idiomatic DRA pattern for multi-device allocation from a homogeneous group -- the scheduler picks two distinct devices matching the predicate.

### 1nic-unaligned: 1 GPU + 1 NIC, cross-NUMA (baseline)

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: 1nic-unaligned
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
          count: 1
          selectors:
          - cel:
              expression: >-
                device.attributes["resource.kubernetes.io"].pciBusID == "0008:06:00.0"
      - name: nic
        exactly:
          deviceClassName: dranet.net
          count: 1
          selectors:
          - cel:
              expression: >-
                device.attributes["dra.net"]["rdmaDevice"] == "mlx5_2"
```

GPU 0 (NUMA 0) paired with mlx5_2 (NUMA 1). **SYS** affinity -- cross-NUMA with no GDR path. This serves as the degraded baseline.

## Running the NCCL benchmark

The benchmark uses an MPIJob from the Kubeflow MPI Operator to run NCCL `all_reduce_perf` across two worker pods on different nodes, each with one GPU and one or more NICs allocated through DRA.

```yaml
apiVersion: kubeflow.org/v2beta1
kind: MPIJob
metadata:
  name: nccl-test-dra
spec:
  slotsPerWorker: 1
  mpiReplicaSpecs:
    Launcher:
      replicas: 1
      template:
        spec:
          containers:
          - name: nccl
            image: ghcr.io/coreweave/nccl-tests:12.9.1-devel-ubuntu24.04-nccl2.29.2-1-d73ec07
            command: ["/bin/bash", "-c"]
            args:
            - |
              sleep 5
              mpirun -np 2 \
                --allow-run-as-root \
                -bind-to none \
                -x LD_LIBRARY_PATH \
                -x NCCL_DEBUG=INFO \
                -x NCCL_SOCKET_IFNAME=eth0 \
                -x NCCL_IB_DISABLE=0 \
                -x NCCL_SHM_DISABLE=1 \
                -x NCCL_MNNVL_ENABLE=0 \
                -x NCCL_NVLS_ENABLE=0 \
                -x NCCL_NET_GDR_LEVEL=PHB \
                -x NCCL_IB_DATA_DIRECT=0 \
                /opt/nccl_tests/build/all_reduce_perf \
                  -b 512M -e 8G -f 2 -g 1 -c 0
    Worker:
      replicas: 2
      template:
        spec:
          affinity:
            podAntiAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchLabels:
                    training.kubeflow.org/job-name: nccl-test-dra
                    training.kubeflow.org/job-role: worker
                topologyKey: kubernetes.io/hostname
          automountServiceAccountToken: false
          resourceClaims:
          - name: gpu-nic
            resourceClaimTemplateName: 1nic-aligned
          containers:
          - name: nccl
            image: ghcr.io/coreweave/nccl-tests:12.9.1-devel-ubuntu24.04-nccl2.29.2-1-d73ec07
            resources:
              claims:
              - name: gpu-nic
            securityContext:
              capabilities:
                add:
                - IPC_LOCK
          tolerations:
          - key: "nvidia.com/gpu"
            operator: "Exists"
            effect: "NoSchedule"
```

Key details:

- **Pod anti-affinity** ensures the two workers land on different nodes, forcing inter-node RDMA communication
- **`resourceClaimTemplateName`** controls which GPU-NIC template is used -- swap between `1nic-aligned`, `2nic-aligned`, or `1nic-unaligned` to test different topologies
- **`IPC_LOCK`** capability is required for RDMA memory registration
- NCCL environment variables disable shared memory (`NCCL_SHM_DISABLE=1`) and NVLink multi-node (`NCCL_MNNVL_ENABLE=0`) to isolate InfiniBand performance

### Running the test

```bash
# Install the MPI Operator (if not already installed)
kubectl apply --server-side -k \
  "https://github.com/kubeflow/mpi-operator/manifests/overlays/standalone?ref=v0.7.0"

# Apply the ResourceClaimTemplates
kubectl apply -f resource-claim-template.yaml

# Edit mpi-job.yaml to select a template, then apply
kubectl apply -f mpi-job.yaml

# Wait for workers and stream launcher logs
kubectl wait --for=condition=ready pod \
  -l training.kubeflow.org/job-name=nccl-test-dra,training.kubeflow.org/job-role=worker \
  --timeout=300s

launcher=$(kubectl get pods \
  -l training.kubeflow.org/job-name=nccl-test-dra,training.kubeflow.org/job-role=launcher \
  -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f "${launcher}"
```

### Verifying device isolation

After the job starts, confirm that each worker only sees its allocated InfiniBand devices:

```bash
kubectl exec nccl-test-dra-worker-0 -- ls /dev/infiniband/
```

Expected results by template:

- **1nic-aligned**: `uverbs0`, `umad0`, `rdma_cm` (only mlx5_0)
- **2nic-aligned**: `uverbs0`, `uverbs1`, `umad0`, `umad1`, `rdma_cm` (mlx5_0 + mlx5_1)
- **1nic-unaligned**: `uverbs2`, `umad2`, `rdma_cm` (only mlx5_2)

Devices for non-allocated NICs are absent -- isolation is enforced by the DRANET NRI plugin without requiring `privileged: true`.

## Benchmark results

Two-node `all_reduce_perf`, 1 GPU per worker, message sizes from 512 MB to 8 GB. Transport: `NET/IBext_v11/GDRDMA`.

| Template | GPU | NIC(s) | NUMA | Channels | GDR | Avg busbw |
|---|---|---|---|---|---|---|
| `1nic-aligned` | gpu-0 (NUMA 0) | mlx5_0 (NUMA 0) | NODE | 8 | Yes | **~56 GB/s** |
| `2nic-aligned` | gpu-0 (NUMA 0) | mlx5_0+mlx5_1 (NUMA 0) | NODE | 16 | Yes | **~112 GB/s** |
| `1nic-unaligned` | gpu-0 (NUMA 0) | mlx5_2 (NUMA 1) | SYS | 2 | No | **~25 GB/s** |

### Why NUMA alignment matters: a 4.5x difference

The cross-NUMA (`1nic-unaligned`) case shows a 4.5x performance degradation compared to the NUMA-aligned (`1nic-aligned`) case. Three compounding penalties explain this:

1. **GDR disabled** -- NCCL falls back from `GDRDMA` to staging through host memory when the NIC has no direct PCIe path to the GPU
2. **Fewer channels** -- NCCL's topology engine allocates only 2 channels for SYS-distant NICs versus 8 for NODE-local NICs
3. **Cross-NUMA memory traffic** -- every transfer crosses the QPI/UPI interconnect between NUMA domains

With two NUMA-aligned NICs (`2nic-aligned`), throughput doubles to ~112 GB/s as NCCL stripes data across both NICs with 16 channels and GDR active on both paths.

## Getting started

### Prerequisites

- An AKS cluster running Kubernetes 1.34 or later (DRA feature gate enabled)
- A GPU node pool with [ND GB300-v6 series](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/gpu-accelerated/nd-gb300-v6-series?tabs=sizebasic) VMs
- The [NVIDIA GPU DRA driver](https://github.com/NVIDIA/k8s-dra-driver-gpu) installed (publishes GPU `ResourceSlices`)
- DRANET installed (publishes NIC `ResourceSlices` with RDMA and NUMA attributes)
- The [MPI Operator](https://github.com/kubeflow/mpi-operator) for running multi-node NCCL benchmarks

### Install DRANET

```bash
kubectl apply -f https://raw.githubusercontent.com/anson627/dranet/main/examples/dranetctl-install.yaml
```

Verify that DRANET has published NIC ResourceSlices:

```bash
kubectl get resourceslices -o wide
```

You should see slices from both the `gpu.nvidia.com` and `dra.net` drivers for each GPU node.

## Key takeaways

- **NUMA alignment delivers 4.5x better NCCL throughput**: pairing GPUs with NUMA-local NICs enables GPU-Direct RDMA, doubles available channels, and avoids cross-NUMA memory traffic
- **Two NUMA-aligned NICs double throughput further**: the `count: 2` + pool-selector pattern in DRA is the idiomatic way to allocate multiple devices from a homogeneous group
- **DRANET enforces per-pod device isolation**: only allocated `uverbs` devices are visible in the container, without requiring privileged mode

## Next steps

- Explore the [DRANET examples](https://github.com/anson627/dranet/tree/main/examples) for additional configurations
- Learn more about [Dynamic Resource Allocation in Kubernetes](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
- Read about [DRA devices and drivers on Kubernetes](/2025/11/17/dra-devices-and-drivers-on-kubernetes) for foundational DRA concepts
- Read about [DRA with NVIDIA vGPU on AKS](/2026/03/06/dra-with-vGPUs-on-aks) for fractional GPU scenarios

## Questions?

Connect with the AKS team through our [GitHub discussions](https://github.com/Azure/AKS/discussions) or [share your feedback and suggestions](https://github.com/Azure/AKS/issues).
