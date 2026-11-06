# Module 3: Enable RDMA and GPUDirect

**Goal:** expose GPUs and InfiniBand HCAs to pods and enable direct GPU-memory
access. **Time:** 15–25 minutes.

Run:

```bash
./scripts/20-install-rdma.sh
```

The script installs pinned components based on
[Azure/aks-rdma-infiniband](https://github.com/Azure/aks-rdma-infiniband):

- NVIDIA Network Operator `26.4.0` and Node Feature Discovery.
- Mellanox DOCA OFED on nodes carrying ConnectX devices.
- RDMA shared device plugin, exposing `rdma/shared_ib` pod slots.
- NVIDIA device plugin `0.17.4`, exposing `nvidia.com/gpu`.
- A privileged `nvidia-peermem` loader. If the AKS-managed open NVIDIA module
  cannot load `nvidia-peermem` after OFED changes, the loader records a DMA-BUF
  fallback; Module 5 must still prove `NET/IB/.../GDRDMA` on both ranks.

The operator may drain and restart RDMA nodes while replacing networking
modules. The script waits for reconciliation before checking allocatable
resources. A DMA-BUF fallback is not treated as proof by itself: only the
application's NCCL `GDRDMA` evidence completes GPUDirect validation.

## Checkpoint

Each of the two GPU nodes reports nonzero values for both resources:

```text
<nodename>    8    63
```

The columns are node, `nvidia.com/gpu`, and `rdma/shared_ib`.

## Why use a device plugin?

A privileged pod could see host devices directly, but Kubernetes could not
account for them. The shared plugin mounts `/dev/infiniband` only into pods that
request a slot and prevents more than the configured number of concurrent RDMA
consumers.

## Troubleshooting

```bash
kubectl get nicclusterpolicy nic-cluster-policy -o yaml
kubectl get pods -n network-operator -o wide
kubectl logs -n gpu-resources daemonset/nvidia-peermem-loader
```

Don't install NVIDIA GPU Operator over an AKS-managed GPU driver. Those driver
lifecycle models are mutually exclusive.

**Next:** [Validate InfiniBand](04-validate-infiniband.md).
