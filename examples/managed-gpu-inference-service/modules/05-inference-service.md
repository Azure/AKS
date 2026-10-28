# Module 5: Deploy the inference service

Deploy two vLLM replicas that mount the staged model read-only.

## Deploy and test vLLM

```bash
./scripts/50-deploy-vllm.sh
```

The first rollout usually takes 10–25 minutes while both GPU nodes pull the
image and load the model. The script waits up to 60 minutes. If the rollout
hasn't progressed after about 30 minutes, inspect events and logs from another
terminal.

The manifest includes:

- One GPU request per replica.
- Topology spread across host names.
- A PodDisruptionBudget with one replica always available.
- `maxSurge: 0` so an update does not require a third GPU.
- A 20-minute startup probe for model initialization.
- Separate readiness and liveness thresholds.
- An 8-GiB in-memory `/dev/shm` volume.
- A read-only model mount and offline Hugging Face mode.

## Checkpoint

```bash
kubectl get pods -n managed-gpu-inference \
  -l app.kubernetes.io/name=vllm \
  -o wide
```

Expect two ready pods on different nodes.

The deployment script also sends an OpenAI-compatible request through the
cluster-internal Service. A successful run ends with:

```output
PASS  Inference request completed
```

To test from your computer:

```bash
kubectl port-forward -n managed-gpu-inference service/vllm 8000:8000
```

Then send the request from the example README.

## Troubleshoot

| Problem | Action |
| --- | --- |
| A pod is `Pending` | Check for free `nvidia.com/gpu` capacity and the `sku=gpu:NoSchedule` toleration |
| A pod reports `No CUDA GPUs are available` | Delete the failed pod after the new node finishes initializing so Kubernetes makes a fresh allocation |
| The model path is missing | Rerun `./scripts/40-stage-model.sh` and inspect the staging Job |
| The process exits after loading | Confirm `enableServiceLinks: false`; a Service named `vllm` otherwise injects a conflicting `VLLM_PORT` variable |
| Rollout hasn't progressed after 30 minutes | Inspect pod events and logs with the commands printed by the script; the script times out after 60 minutes |

## Next step

[Module 6: Observe the service](06-observability.md)
