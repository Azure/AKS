# Module 4: Validate InfiniBand

**Goal:** prove that RDMA works between two distinct nodes before involving
PyTorch or NCCL. **Time:** about 5 minutes after the image is cached.

Run:

```bash
./scripts/30-validate-fabric.sh
```

The script schedules a server and client on different nodes. Both request
`rdma/shared_ib: 1` and `IPC_LOCK`, discover the first active InfiniBand HCA,
and run:

- `ib_read_lat` for one-way verbs latency.
- `ib_write_bw` with 8-MiB messages for large-message bandwidth.

The Kubernetes Service is used only for the initial control exchange. The data
rows report RC verbs over the InfiniBand link, not Service traffic.

## Checkpoint

Look for all of the following:

```text
State: Active
Link layer: InfiniBand
FABRIC_METRIC {..."write_bandwidth_gbps": ...}
```

The default A100 floors are 150 Gb/s bandwidth and at most 10 µs latency.
Override `LAB_MIN_IB_GBPS` or `LAB_MAX_IB_LATENCY_US` for a different SKU only
after consulting that SKU's expected link characteristics.

## Why this test comes first

NCCL can silently fall back to sockets. A successful distributed program alone
therefore does not prove IB. This module verifies the fabric independently; the
next module separately requires NCCL's `GDRDMA` evidence.

## Troubleshooting

- **No HCA:** inspect `rdma/shared_ib`, the device-plugin pod, and NFD labels.
- **Down/Initializing:** inspect the OFED pod and `ibstat` before retrying.
- **Peers on one node:** required pod anti-affinity should prevent this; don't
  accept a same-node measurement as cross-node validation.
- **Low bandwidth:** confirm both nodes are in one VMSS placement group and no
  other job is saturating the fabric.

**Next:** [Run the training comparison](05-run-training-comparison.md).
