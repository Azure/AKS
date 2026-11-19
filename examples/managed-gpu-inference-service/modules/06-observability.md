# Module 6: Observe the service

Use device metrics and server metrics together. They answer different
questions.

| Source | Endpoint | Use it to measure |
| --- | --- | --- |
| DCGM exporter | Node port `19400` | GPU activity, memory, temperature, power, and hardware errors |
| vLLM | Pod port `8000/metrics` | Running requests, queued requests, token throughput, and cache pressure |

## Read vLLM metrics

Forward the Service:

```bash
kubectl port-forward -n managed-gpu-inference service/vllm 8000:8000
```

In another terminal:

```bash
curl --fail http://127.0.0.1:8000/metrics \
  | grep -E 'vllm:(num_requests_running|num_requests_waiting|kv_cache_usage_perc)'
```

`vllm:num_requests_waiting` is the clearest signal that requests are arriving
faster than the replicas can serve them.

## Read DCGM metrics

The verification script reads the node-local endpoint from a pod pinned to
each GPU node:

```bash
./scripts/30-verify-gpu.sh --dcgm-only
```

Use `--dcgm-only` after deployment because the two vLLM replicas already hold
all available GPUs. This mode checks the exporter without requesting another
GPU.

Focus on these metrics:

| Metric | Meaning |
| --- | --- |
| `DCGM_FI_DEV_GPU_UTIL` | Percentage of time work is active on the GPU |
| `DCGM_FI_DEV_FB_USED` | Framebuffer memory in use |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature |
| `DCGM_FI_DEV_POWER_USAGE` | Current power draw |
| `DCGM_FI_DEV_XID_ERRORS` | Driver-reported hardware error count |

Do not interpret GPU utilization by itself as request throughput. Compare DCGM
with vLLM queue depth and latency before deciding whether the service needs
more capacity or different batching settings.

## Production monitoring

This example reads metrics directly to keep the deployment focused. For
central collection and alerting, follow
[Monitor GPU metrics on AKS](https://learn.microsoft.com/azure/aks/monitor-gpu-metrics)
and scrape the managed DCGM exporter into Azure Managed Prometheus.

## Next step

[Module 7: Clean up](07-cleanup.md)
