# Module 3 — Workloads

Four example workloads demonstrating Ray on AKS with Kueue admission control.
Each example reuses the cluster from [Module 1](../1-infrastructure/) and the
queue configuration from [Module 2](../2-kueue-queues/).

## Prerequisites

- Module 1 deployed: AKS cluster, KubeRay, Kueue, storage, workload identity
- Module 2 applied: `ray` namespace, ResourceFlavors, at least one queue
  (`20-single-queue.yaml` or `30-team-queues.yaml`)
- `envsubst` available (`gettext` package on most Linux distros, `brew install gettext` on macOS)
- `kubectl` configured to the Module 1 cluster:
  ```bash
  az aks get-credentials --resource-group <rg> --name <cluster>
  ```

## Manifest template system

All RayJob and RayService manifests are rendered with `envsubst`.
Each example directory contains:

| File | Purpose |
|------|---------|
| `env.example` | Variable defaults — source this before running `submit.sh` |
| `submit.sh` | Creates/updates the ConfigMap and applies the rendered manifest |
| `manifests/rayjob.yaml.tmpl` | RayJob template (or `rayservice.yaml.tmpl` for online-serving) |
| `<script>.py` | Python workload payload |

The shared base templates in [`_template/`](_template/) define the standard
fields used by every workload. Per-example templates extend these with
workload-specific pip packages, env vars, and resource counts.

### Standard fields (all workloads)

| Field | Value | Reason |
|-------|-------|--------|
| `suspend: true` | required | Kueue gates admission |
| `shutdownAfterJobFinishes: true` | required | Kueue tracks completion |
| `ttlSecondsAfterFinished` | `300` | Consistent cleanup |
| Head `num-cpus: "0"` | always | Tasks land on GPU workers only |
| Code mount | ConfigMap → `/home/ray/scripts` | Scripts injected at runtime |
| Workload deps | `runtimeEnvYAML.pip` | Never baked into image |
| `serviceAccountName` | `ray-workload` | Workload identity from Module 1 |
| `azure.workload.identity/use` | `"true"` | Required for Azure SDK auth |
| Ray image | `mcr.microsoft.com/aks/ai-runtime/ray:py3.12-ray2.55.1-cuda13.0` | Module 1 pin |

### Key design choice: RayService is not Kueue-admitted

RayService (Example 4 — online serving) is a persistent deployment, not a
batch job. It does **not** carry the `kueue.x-k8s.io/queue-name` label.
Kueue manages batch workload admission; serving deployments are managed
directly by KubeRay.

## Examples

### 1. aurora-finetune/ — Aurora weather model fine-tune
Fine-tunes Microsoft Aurora on WeatherBench2 Hurricane-Ida data uploaded by
Module 1. Produces a LoRA adapter in Azure Blob (`aurora/checkpoints/<run-id>/`).

- **1 worker × 1 A100 GPU**
- Queue: `default` (or `team-a` / `team-b` for the borrowing demo)
- Output: `aurora/checkpoints/<JOB_NAME>/last.safetensors`
- See [aurora-finetune/](aurora-finetune/) for the full example

### 2. llm-training/ — Qwen2.5-7B LoRA fine-tune
Fine-tunes Qwen2.5-7B on the viggo dataset using LLaMA-Factory (distributed
across 4 GPUs). Reads dataset from Module 1 blob storage; writes LoRA adapter
to `llm-pipeline/lora/<run-id>/`.

- **4 workers × 1 A100 GPU (4 GPUs total)**
- Queue: `default` (or `team-a` / `team-b`)
- Output: `llm-pipeline/lora/<JOB_NAME>/`
- See [llm-training/](llm-training/)

### 3. batch-inference/ — vLLM batch inference
Runs vLLM batch inference on the viggo test split using the LoRA adapter from
Example 2. Reads `test.jsonl` and the LoRA from blob storage; writes
predictions to `llm-pipeline/inference/<run-id>/predictions.jsonl`.

- **1 worker × 1 A100 GPU**
- Queue: `default`
- Requires: completed `llm-training` run (`lora/latest.txt` in blob storage)
- See [batch-inference/](batch-inference/)

### 4. online-serving/ — Aurora RayService
Deploys the fine-tuned Aurora model as a persistent HTTP endpoint using
Ray Serve. Loads the LoRA adapter from blob storage on startup.

- **1 GPU** (head node handles Serve controller + worker handles GPU inference)
- **Not Kueue-admitted** — persistent deployment
- Requires: completed `aurora-finetune` run (`AURORA_RUN_ID`)
- Access: `kubectl -n ray port-forward svc/aurora-serve-serve-svc 8000:8000`
- See [online-serving/](online-serving/)

## Comparison

| | aurora-finetune | llm-training | batch-inference | online-serving |
|--|--|--|--|--|
| Kind | RayJob | RayJob | RayJob | RayService |
| Kueue-admitted | ✓ | ✓ | ✓ | ✗ |
| GPUs | 1 | 4 | 1 | 1 |
| Queue label | `default` | `default` | `default` | — |
| Deps | Aurora, torch, azure-storage-blob | LLaMA-Factory, azure-storage-blob | vLLM, azure-storage-blob | Aurora, azure-storage-blob |
| Reads from blob | `aurora/data/` (init/truth) | `llm-pipeline/data/` (train.jsonl) | `llm-pipeline/data/` + `lora/` | `aurora/checkpoints/` (adapter) |
| Writes to blob | `aurora/checkpoints/` | `llm-pipeline/lora/` | `llm-pipeline/inference/` | — |

## Quick start

```bash
# Get storage account from Module 1 outputs
export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../1-infrastructure/terraform output -raw storage_account_name)

# Run Example 1 (aurora fine-tune)
cd aurora-finetune
source env.example
export JOB_NAME="aurora-finetune-$(date +%s)"
./submit.sh
kubectl -n ray get rayjob ${JOB_NAME} -w
```
