# Module 6: Observe and interpret results

**Goal:** connect the performance numbers to direct transport evidence.
**Time:** about 5 minutes.

Run:

```bash
./scripts/50-report.sh
```

The report shows:

- Average and P95 distributed step time.
- Steps per second.
- Effective gradient synchronization rate.
- Step-time speedup and throughput gain.
- One NCCL line from each transport.
- The verbs link, latency, and bandwidth result from Module 4.

Inspect all evidence directly when troubleshooting:

```bash
cat .results/summary.json
cat .results/fabric.json
grep -E 'Using network|GDRDMA|APP_METRIC' .results/rdma-rank0.log
grep -E 'Using network|APP_METRIC' .results/tcp-rank0.log
```

## Interpreting the layers

- `State: Active` and `ib_write_bw` prove that the IB fabric carries verbs.
- `Using network IB` proves NCCL selected its IB transport.
- `GDRDMA` proves NCCL used GPU Direct rather than staging through host memory.
- `Using network Socket` proves the baseline stayed on Ethernet.
- Lower DDP step time shows that transport choice improved this application.

Don't infer RDMA from speed alone. A fast result without `GDRDMA` is incomplete,
and an IB link benchmark doesn't prove that NCCL selected it.

## Expected variability

Absolute values vary with VM SKU, active HCA, NCCL version, message size, and
neighboring load. Compare runs from the same invocation and investigate large
P95-to-average gaps before treating a one-off result as a platform baseline.

**Next:** [Clean up](07-cleanup.md).
