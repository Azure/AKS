# Module 3: Verify GPU access

Verify every GPU node before deploying the model server.

## Run the checks

```bash
./scripts/30-verify-gpu.sh
```

The script checks:

1. The node pool reports `nvidia.managementMode=Managed`.
2. Both nodes advertise `nvidia.com/gpu`.
3. Both nodes carry the DCGM exporter label.
4. A container pinned to each node creates a CUDA tensor.
5. The DCGM endpoint on each node publishes GPU metrics.

The DCGM probe uses the host network to reach the node-local metrics endpoint
on port 19400. A cluster that enforces the baseline Pod Security Standard can
block this diagnostic pod.

The CUDA allocation is deliberate. `nvidia-smi` confirms that the NVIDIA
Management Library can enumerate the device, but it does not prove that a
container can initialize CUDA and allocate GPU memory.

## Checkpoint

The final output should name two nodes and end with:

```output
PASS  Managed GPU access verified on 2 node(s)
```

You can also inspect the schedulable capacity directly:

```bash
kubectl get nodes -l agentpool=a100np \
  -o custom-columns='NODE:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,GPU:.status.allocatable.nvidia\.com/gpu,DCGM:.metadata.labels.kubernetes\.azure\.com/dcgm-exporter'
```

Each node should report `True`, `1`, and `enabled`.

## Troubleshoot

| Problem | Action |
| --- | --- |
| No nodes match `agentpool=a100np` | Confirm the pool finished provisioning |
| `nvidia.com/gpu` is empty | Inspect `gpuProfile`; the pool might not use the managed profile |
| The CUDA pod remains `Pending` | Confirm the pod has the GPU taint toleration and the node has free GPU capacity |
| CUDA allocation fails | Delete the validation pod and rerun after the node finishes initializing; inspect node and container events if it fails again |
| DCGM metrics are unavailable | Confirm the node label is `enabled`, then inspect the managed GPU node health |

## Next step

[Module 4: Stage the model](04-model-storage.md)
