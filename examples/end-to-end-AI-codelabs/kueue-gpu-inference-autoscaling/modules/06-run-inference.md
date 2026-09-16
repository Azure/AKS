# Module 6: Run inference

**Goal:** Trigger GPU scale-up, load a model with vLLM, and validate a real
inference request.

**Time:** 10–20 minutes. GPU billing starts when the node is created.

## Submit the workload

```bash
./scripts/50-submit-inference.sh
./scripts/60-watch-flow.sh
```

The Job starts with `suspend: true` and requests three pods with one
`nvidia.com/gpu` each. Kueue creates one Workload and a ProvisioningRequest with
`count: 3` instead of creating pods immediately. The AKS cluster autoscaler adds
three nodes to `gpupool`, then marks the request provisioned. Kueue admits the
Workload and changes the Job to `suspend: false`.

The Job starts vLLM with the ungated `Qwen/Qwen2.5-0.5B-Instruct` model, waits
for `/health`, sends an OpenAI-compatible chat completion, verifies that the
response isn't empty, and exits. The manifest limits vLLM to 70% GPU memory, a
2,048-token context, four sequences, and eager execution. Those settings were
validated on a 4-GB A10-4Q profile and also work on larger GPUs.

The first run pulls the container image and model onto all three new nodes.
Most of the elapsed time is expected to be infrastructure and model cold start.

## Expected progression

The watcher prints a new row whenever state changes. Expect this order:

```output
ELAPSED  POOL  READY WORKLOAD           PROVISIONING   SUSPENDED  POD
0s       0     0     Pending            Pending        true       NotCreated
...      3     0     Pending            Pending        true       NotCreated
...      3     3     True               True           false      Pending
...      3     3     True               True           false      Running
```

`POOL` is the desired VM count reported by Azure. `READY` is the number of GPU
nodes registered with Kubernetes. Keeping them separate exposes node bootstrap
failures instead of making a provisioned VM look like usable GPU capacity.

Each pod's logs end with:

```output
MODEL_RESPONSE: ...
INFERENCE_VALIDATED
```

The watcher verifies all three pods and ends with:

```output
PASS  End-to-end inference completed in all 3 pods
```

The exact response text, timing, and number of intermediate rows vary.

## Checkpoint

```bash
for pod in $(kubectl -n gpu-inference get pods \
  -l job-name=vllm-inference-check -o name); do
  kubectl -n gpu-inference logs "$pod" | grep INFERENCE_VALIDATED
done
```

Continue only if this prints `INFERENCE_VALIDATED` three times and the Job
reports `Complete 3/3`.

## Troubleshoot

| Last state | Likely area | Next command |
|---|---|---|
| No Workload | Kueue Job integration or queue label | `kubectl -n gpu-inference describe job vllm-inference-check` |
| Workload pending without quota | Queue or flavor configuration | `kubectl -n gpu-inference describe workload` |
| ProvisioningRequest pending | GPU quota, regional capacity, or pool maximum | `kubectl -n gpu-inference describe provisioningrequest` |
| `POOL=1`, `READY=0` for more than 15 minutes | The VM exists but failed to register as a Kubernetes node | Check the node pool provisioning state and retry with another SKU or region |
| `BookingExpired=True` and no Ready GPU node | Node bootstrap exceeded the capacity reservation window | Inspect the node pool and autoscaler status; don't treat `Provisioned=True` alone as proof that the node joined |
| Pod Pending | Node label, taint, or device plugin | `kubectl -n gpu-inference describe pod` |
| Pod fails during model load | Image, model download, GPU driver, or memory | `kubectl -n gpu-inference logs job/vllm-inference-check` |

## Next step

Continue to [Module 7: Observe and troubleshoot](07-observe-and-troubleshoot.md).
