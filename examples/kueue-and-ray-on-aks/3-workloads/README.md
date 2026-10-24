# Module 3 — Workloads

Four Ray workloads use the managed KubeRay and Kueue setup from
[Module 1](../1-infrastructure/managed/) and the customer-owned queues from
[Module 2](../2-kueue-queues/). The separate CPU autoscale demo needs no Ray
dependencies. The [legacy Terraform lab](../1-infrastructure/terraform/legacy-guide.md)
is a self-managed alternative; don't layer managed operators over its Helm releases.

## Prerequisites

- For Ray examples: an AKS cluster with managed KubeRay and Kueue, storage,
  datasets, and authorized workload identity prepared through the managed path.
  The legacy Terraform installation is a separate deliberate alternative.
- For Ray examples: Module 2's `ray` namespace, `ray-workload` ServiceAccount,
  customer-owned ResourceFlavors, and one queue configuration
  (`20-single-queue.yaml` or `30-team-queues.yaml`).
- For the CPU autoscale example: follow its own prerequisites; Ray, storage,
  identity, and the Ray queues aren't required.
- `envsubst` available for Ray templates (`gettext` package on most Linux distros,
  `brew install gettext` on macOS).
- `kubectl` configured to the target cluster:
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

> **Exception:** [`cas-batch-job/`](cas-batch-job/) is a plain Kubernetes Job
> (no Ray, no `envsubst`) applied directly with `kubectl apply -f`. It
> demonstrates the cluster-autoscaler ProvisioningRequest path rather than a Ray
> runtime, so it doesn't use the template system described here.

### Standard fields (all workloads)

| Field | Value | Reason |
|-------|-------|--------|
| `suspend: true` | required | Kueue gates admission |
| `shutdownAfterJobFinishes: true` | required | Kueue tracks completion |
| `ttlSecondsAfterFinished` | `300` | Consistent cleanup |
| Head `num-cpus: "0"` | RayJob only | Tasks land on GPU workers only (RayService sets `"4"`) |
| Code mount | ConfigMap → `/home/ray/scripts` | Scripts injected at runtime |
| Workload deps | `runtimeEnvYAML.pip` | Never baked into image |
| `serviceAccountName` | `ray-workload` | Workload identity from Module 1 |
| `azure.workload.identity/use` | `"true"` | Required for Azure SDK auth |
| Ray image | `mcr.microsoft.com/aks/ai-runtime/ray:py3.12-ray2.55.1-cuda13.0` | Workload runtime default, separate from the managed operator version. |

### Key design choice: RayService is not Kueue-admitted

RayService (Example 4 — online serving) is a persistent deployment, not a
batch job. It does **not** carry the `kueue.x-k8s.io/queue-name` label.
Kueue manages batch workload admission; serving deployments are managed
directly by KubeRay.

## Examples

### 1. aurora-finetune/ — Aurora weather model fine-tune
Fine-tunes Microsoft Aurora on the regional WeatherBench2 data prepared in
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

- **1 GPU** (single head node runs both Serve controller and GPU inference)
- **Not Kueue-admitted** — persistent deployment
- Requires: completed `aurora-finetune` run (`AURORA_RUN_ID`)
- Access: `kubectl -n ray port-forward svc/${SERVICE_NAME}-serve-svc 8000:8000`
- See [online-serving/](online-serving/)

### 5. cas-batch-job/ — provision capacity on demand (cluster autoscaler)
A plain Kubernetes batch Job (no Ray) that demonstrates the **ProvisioningRequest
→ cluster autoscaler** path. Where the examples above admit against a fixed quota
on an existing GPU node, this one drives the AKS cluster autoscaler to grow an
autoscaling CPU pool *before* the Job is admitted — capacity provisioned
just-in-time.

- **CPU only** — 3 pods × 1800m on an autoscaling `scalepool`
- Queue: `cas-local-queue` in the `cas-kueue-demo` namespace (the ProvisioningRequest-gated queue from Module 2)
- Requires: an autoscaling `scalepool` pool
- See [cas-batch-job/](cas-batch-job/)

## Comparison

| | aurora-finetune | llm-training | batch-inference | online-serving | cas-batch-job |
|--|--|--|--|--|--|
| Kind | RayJob | RayJob | RayJob | RayService | Job |
| Kueue-admitted | ✓ | ✓ | ✓ | ✗ | ✓ |
| GPUs | 1 | 4 | 1 | 1 | 0 (CPU) |
| Queue label | `default` | `default` | `default` | — | `cas-local-queue` |
| Deps | Aurora, torch, azure-storage-blob | LLaMA-Factory, azure-storage-blob | vLLM, azure-storage-blob | Aurora, azure-storage-blob | none (busybox) |
| Reads from blob | `aurora/data/` (init/truth) | `llm-pipeline/data/` (train.jsonl) | `llm-pipeline/data/` + `lora/` | `aurora/checkpoints/` (adapter) | — |
| Writes to blob | `aurora/checkpoints/` | `llm-pipeline/lora/` | `llm-pipeline/inference/` | — | — |

## Submitter compatibility

The three RayJob templates provide a pod-local `python` wrapper for the MCR
image's `python3`. KubeRay 1.7's generated submitter health check needs that
unversioned executable. A small init container writes the wrapper to an
`emptyDir`, mounted read-only only in the submitter. The runtime image, generated
health/submission commands, and managed operator settings aren't replaced.
RayService has no batch submitter and doesn't need this wrapper.

## Quick start

For the managed path, use the private kubeconfig from Module 1 and set the
storage account from that setup before sourcing each workload's defaults.
The defaults preserve supplied values; no Terraform state is needed:

```bash
source ../1-infrastructure/managed/.managed/managed.env
export AZURE_STORAGE_ACCOUNT_NAME="<prepared-storage-account>"

# Run Example 1 (aurora fine-tune)
cd aurora-finetune
source env.example
export JOB_NAME="aurora-finetune-$(date +%s)"
./submit.sh
kubectl -n ray get rayjob ${JOB_NAME} -w
```

For the legacy Terraform path only, retrieve its storage account with
`terraform -chdir=../1-infrastructure/terraform output -raw storage_account_name`
instead. Don't use a different lab's state or install both sets of operators.
