# Example 1 — Aurora Fine-Tune

RayJob that fine-tunes the [Microsoft Aurora](https://github.com/microsoft/aurora)
weather foundation model on regional WeatherBench2 data. The job reads an
init/truth `.npz` pair from Azure Blob Storage (`aurora/data/`), runs a single
LoRA fine-tune step on one A100 GPU, and writes the adapter checkpoint +
training metrics back to blob storage (`aurora/checkpoints/<run-id>/`).

## Prerequisites

- Module 1 infrastructure deployed (AKS cluster, storage account, workload identity)
- Module 2 queues applied (`default` LocalQueue or `team-a`/`team-b`)
- Aurora data uploaded to `aurora/data/` (done by Module 1 Terraform, or manually
  via `populate_weatherbench2_regional_data.py`)

## Quick start

```bash
# Set the storage account from Module 1 outputs
export AZURE_STORAGE_ACCOUNT_NAME=<your-storage-account>

# Source defaults (image, queue, worker count)
source env.example

# Submit the RayJob
./submit.sh
```

## What happens

1. `submit.sh` creates a ConfigMap from `aurora_finetune.py` and renders
   `manifests/rayjob.yaml.tmpl` via `envsubst`.
2. Kueue admits the RayJob from the `default` queue when GPU quota is available.
3. The Ray worker downloads the init/truth pair from blob storage using
   workload identity (`DefaultAzureCredential`).
4. Aurora pretrained checkpoint is pulled from HuggingFace Hub.
5. LoRA adapter wraps the model (rank 8 by default).
6. One training step runs (configurable via `AURORA_MAX_STEPS`).
7. Checkpoint (`last.safetensors`) and metrics (`train-metrics.json`) upload
   to `aurora/checkpoints/<run-id>/`.

## Monitor

```bash
kubectl -n ray get rayjob ${JOB_NAME} -w
kubectl -n ray get workload -w
kubectl -n ray logs -l ray.io/cluster=$(kubectl -n ray get rayjob ${JOB_NAME} -o jsonpath='{.status.rayClusterName}') -f
```

## Verify

```bash
# Check uploaded artifacts
az storage blob list -c aurora --prefix checkpoints/${JOB_NAME}/ \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login -o table

# Download and inspect training metrics
az storage blob download -c aurora \
  -n checkpoints/${JOB_NAME}/train-metrics.json \
  --account-name ${AZURE_STORAGE_ACCOUNT_NAME} --auth-mode login \
  --file /tmp/train-metrics.json
cat /tmp/train-metrics.json | python3 -m json.tool
```

The `loss_history` array in `train-metrics.json` should contain finite values
(not NaN), confirming the data path and model training are working correctly.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_STORAGE_ACCOUNT_NAME` | *(required)* | Storage account from Module 1 |
| `AURORA_INPUT_CONTAINER` | `aurora` | Container for input data |
| `AURORA_OUTPUT_CONTAINER` | `aurora` | Container for checkpoints |
| `AURORA_INIT_FILE` | `init-2021-01-01-00z.npz` | Init NPZ file name |
| `AURORA_TRUTH_FILE` | `truth-2021-01-01-06z.npz` | Truth NPZ file name |
| `AURORA_MAX_STEPS` | `1` | Training steps |
| `AURORA_LORA_RANK` | `8` | LoRA rank |
| `AURORA_LEAD_HOURS` | `6` | Forecast lead time (must be 6h multiple) |
| `QUEUE_NAME` | `default` | Kueue LocalQueue name |

## Cleanup

```bash
kubectl -n ray delete rayjob ${JOB_NAME}
kubectl -n ray delete configmap aurora-finetune-scripts
```
