# Example 2 — LLM Training

LoRA fine-tuning of Qwen2.5-7B-Instruct on the viggo dataset using
LLaMA-Factory and Ray Train. Reads training data from Azure Blob Storage
(`llm-pipeline/data/`) and uploads the trained LoRA adapter to
`llm-pipeline/lora/`.

The LoRA output is consumed by Example 3 (batch inference).

## Prerequisites

- [Managed setup](../../1-infrastructure/managed/) and Module 2 completed (managed operators, queues, storage, and service account).
- ViGGO data uploaded to `llm-pipeline/data/` following [dataset preparation](../../1-infrastructure/managed/data.md).

## Quick start

```bash
# Use the storage account prepared for the managed target.
export AZURE_STORAGE_ACCOUNT_NAME="<prepared-storage-account>"

# Source defaults (generates a unique JOB_NAME)
source env.example

# Submit the RayJob
./submit.sh
```

## Monitor

```bash
kubectl -n ray get rayjob ${JOB_NAME} -w
kubectl -n ray get workload -w

# Tail the head pod logs
kubectl -n ray logs -f -l ray.io/cluster=$(kubectl -n ray get rayjob ${JOB_NAME} -o jsonpath='{.status.rayClusterName}') -c ray-head
```

## Verify

A usable LoRA adapter needs both `adapter_config.json` and nonempty
`adapter_model.safetensors` (or `adapter_model.bin`). Nonzero training ranks can
save only `rng_state_*.pth`; that isn't a model. The script skips incomplete
worker checkpoints and refuses to upload them or advance `lora/latest.txt`.

```bash
# Check LoRA upload
az storage blob list -c llm-pipeline --prefix lora/ \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login -o table

# Check latest pointer
az storage blob download -c llm-pipeline -n lora/latest.txt \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_STORAGE_ACCOUNT_NAME` | (required) | Storage account from the selected managed setup. |
| `NUM_WORKERS` | `4` | GPU worker replicas (4 × 1 GPU each) |
| `QUEUE_NAME` | `default` | Kueue LocalQueue name |
| `LLM_DATA_CONTAINER` | `llm-pipeline` | Blob container for input data |
| `LLM_LORA_CONTAINER` | `llm-pipeline` | Blob container for LoRA upload |

## Cleanup

```bash
kubectl -n ray delete rayjob ${JOB_NAME}
kubectl -n ray delete configmap ${CONFIGMAP_NAME}
```
