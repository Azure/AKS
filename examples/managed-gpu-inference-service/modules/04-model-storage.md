# Module 4: Stage the model

Download the model once to an Azure Blob NFS volume that both replicas can
mount.

## Create storage and stage the weights

```bash
./scripts/40-stage-model.sh
```

The script creates:

- A dedicated `managed-gpu-inference` namespace.
- A Premium Azure Blob NFS `StorageClass`.
- A 200-GiB `ReadWriteMany` persistent volume claim.
- A Job that downloads and verifies `Qwen/Qwen2.5-7B-Instruct`.

The Job verifies every safetensors shard listed in the model index before it
reports success. It also removes the Hugging Face transfer cache after
verification because NFS stores the cache as a second physical copy.

This example downloads
[`Qwen/Qwen2.5-7B-Instruct`](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct)
from Hugging Face. Review the model license and terms before use.

## Why use a separate Job

An init container would run once per replica. Two replicas could download the
same files concurrently, duplicate network transfer, and write to the same
paths. A separate Job makes staging an explicit prerequisite for serving.

The serving pods set `HF_HUB_OFFLINE=1`. If staging is incomplete, deployment
fails instead of silently downloading another copy inside a GPU pod.

## Checkpoint

```bash
kubectl get pvc -n managed-gpu-inference model-weights
kubectl logs -n managed-gpu-inference job/stage-model
```

Expect the claim to report `Bound` with `RWX` access. The final Job output
should report four verified shards and approximately 14 GiB of weights.

## Troubleshoot

| Problem | Action |
| --- | --- |
| The claim remains `Pending` | Confirm the Blob CSI driver is enabled and inspect PVC events |
| A pod remains in `ContainerCreating` | Inspect mount events and confirm the StorageClass uses the NFS mount options from the manifest |
| The Job is `OOMKilled` | Confirm the staging container retains its 10-GiB memory limit |
| Model transfer fails | Inspect Job logs, then rerun the script; `snapshot_download` resumes partial files |
| Cleanup refuses an existing object | Choose a clean cluster or remove the conflicting object after confirming its owner |

## Next step

[Module 5: Deploy the inference service](05-inference-service.md)
