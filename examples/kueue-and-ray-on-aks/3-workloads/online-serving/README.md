# Example 4 — Aurora Online Serving

RayService that serves the fine-tuned Aurora weather model as a persistent HTTP endpoint via Ray Serve. Loads the LoRA checkpoint produced by Example 1 (Aurora fine-tune) from Azure Blob storage using workload identity.

Unlike the other examples, this uses **RayService** (not RayJob) and runs as a long-lived service rather than a batch workload. RayService is not admission-controlled by Kueue — no queue label is needed.

## Prerequisites

- Completed Example 1 (Aurora fine-tune) with a successful checkpoint at `aurora/checkpoints/<run-id>/last.safetensors`
- Module 1 infrastructure deployed (storage account, workload identity)
- Module 2 namespace and ServiceAccount applied

## Deploy

```bash
# Set required environment variables
export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
export AURORA_RUN_ID=<JOB_NAME from your completed aurora-finetune run>

# Source defaults and deploy
source env.example
./submit-service.sh
```

## Verify

```bash
# Watch until the RayService reports Running
kubectl -n ray get rayservice ${SERVICE_NAME} -w

# Once Running, port-forward and test
kubectl -n ray port-forward svc/${SERVICE_NAME}-serve-svc 8000:8000
```

Health check (GET):

```bash
curl http://localhost:8000${ROUTE_PREFIX}
```

Forecast request (POST):

```bash
curl -X POST http://localhost:8000${ROUTE_PREFIX} \
  -H 'Content-Type: application/json' \
  -d '{"init_file": "init-2021-01-01-00z.npz", "lead_hours": 6}'
```

The response includes per-variable summary statistics (shape, mean, min, max) for each surface variable in the forecast.

## Clean up

```bash
kubectl -n ray delete rayservice ${SERVICE_NAME}
kubectl -n ray delete configmap ${CONFIGMAP_NAME}
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_STORAGE_ACCOUNT_NAME` | (required) | Storage account from Module 1 |
| `AURORA_RUN_ID` | (required) | JOB_NAME from a completed aurora-finetune run |
| `AURORA_INPUT_CONTAINER` | `aurora` | Container with init data (`data/*.npz`) |
| `AURORA_ADAPTER_CONTAINER` | `aurora` | Container with the LoRA checkpoint |
| `AURORA_INIT_FILE` | `init-2021-01-01-00z.npz` | Default init file for requests |
| `AURORA_LEAD_HOURS` | `6` | Default forecast lead time (must be a 6h multiple) |
| `AURORA_LORA_RANK` | `8` | LoRA rank (must match training) |
| `AURORA_REQUIRE_GPU_NAME` | `A100` | GPU name check (empty to skip) |
