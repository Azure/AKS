# Module 5: Run the training comparison

**Goal:** measure the application-level effect of GPUDirect RDMA with a
controlled A/B test. **Time:** 5–10 minutes after image pull.

Run:

```bash
./scripts/40-run-training-comparison.sh
```

Two PyTorch DDP ranks run on different nodes, one GPU per rank. Each training
step trains an 8,192 × 8,192 dense neural layer on a small synthetic batch,
executes `loss.backward()`, synchronizes its 256-MiB gradient bucket, and
performs an SGD update. The small batch keeps the cross-node gradient path
visible.

The script runs the same application twice:

1. `NCCL_IB_DISABLE=1`: Ethernet Socket control.
2. `NCCL_IB_DISABLE=0`: InfiniBand/GPUDirect run.

Image digest, nodes, GPU count, model, gradient size, warmup, and measured steps
remain unchanged. Both runs still request the RDMA resource so scheduling is
identical.

## Checkpoint

The report contains two `APP_METRIC` objects and a table similar to:

```text
| TCP sockets | ... ms | ... steps/s |
| GPUDirect RDMA | ... ms | ... steps/s |
```

The script fails unless:

- TCP logs contain `NET/Socket`.
- RDMA logs contain both `NET/IB` and `GDRDMA`.
- RDMA reduces average step time by at least `LAB_MIN_SPEEDUP` (default 2x).

Results and complete rank logs are written under `.results/`.

## Tuning the workload

```bash
export LAB_GRADIENT_MIB=512
export LAB_MEASURE_STEPS=20
./scripts/40-run-training-comparison.sh
```

Larger gradients emphasize bandwidth but consume more GPU memory.

**Next:** [Observe and interpret results](06-observe-results.md).
