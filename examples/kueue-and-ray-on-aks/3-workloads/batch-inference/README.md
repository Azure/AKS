# Example 3 — Batch Inference

RayJob that runs vLLM offline batch inference using the LoRA adapter produced by
Example 2 (LLM training). Reads the viggo test split from Azure Blob Storage
(`llm-pipeline/data/test.jsonl`) and applies the fine-tuned LoRA adapter from
`llm-pipeline/lora/`.

Uses a single GPU worker. Predictions are uploaded to
`llm-pipeline/inference/<run-id>/predictions.jsonl`.

## Prerequisites

- Example 2 (LLM training) completed successfully — the training job uploads
  the LoRA adapter and writes `lora/latest.txt` for auto-discovery.
- `AZURE_STORAGE_ACCOUNT_NAME` from Module 1 terraform output.

## Quick start

```bash
# Set the storage account (from Module 1)
export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)

# Source defaults
source env.example

# Submit the RayJob
./submit.sh
```

## Watch progress

```bash
# Kueue admission
kubectl get workloads -n ray

# RayJob status
kubectl -n ray get rayjob ${JOB_NAME} -w

# Tail logs
kubectl -n ray logs -l ray.io/cluster=$(kubectl -n ray get rayjob ${JOB_NAME} -o jsonpath='{.status.rayClusterName}') -f --tail=100
```

## Verify

```bash
# Check the job succeeded
kubectl -n ray get rayjob ${JOB_NAME}

# Check predictions in blob storage
az storage blob list -c llm-pipeline --prefix "inference/${JOB_NAME}/" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --auth-mode login -o table

# Download and inspect predictions
az storage blob download -c llm-pipeline \
  -n "inference/${JOB_NAME}/predictions.jsonl" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --auth-mode login \
  --file /tmp/predictions.jsonl
head -1 /tmp/predictions.jsonl | python3 -m json.tool
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `AZURE_STORAGE_ACCOUNT_NAME` | (required) | Storage account from Module 1 |
| `JOB_NAME` | `batch-inference-<timestamp>` | Unique RayJob name |
| `QUEUE_NAME` | `default` | Kueue LocalQueue |
| `LLM_DATA_CONTAINER` | `llm-pipeline` | Blob container with viggo test data |
| `LLM_LORA_CONTAINER` | `llm-pipeline` | Blob container with LoRA adapters |

## Clean up

```bash
kubectl -n ray delete rayjob ${JOB_NAME}
kubectl -n ray delete configmap ${CONFIGMAP_NAME}
```
