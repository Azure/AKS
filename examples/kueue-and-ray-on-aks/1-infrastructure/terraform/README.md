# Legacy self-managed Terraform alternative

Prefer the [managed setup](../managed/) for the managed-first examples. This
module intentionally retains its existing Terraform resources and Helm operator
ownership; don't apply it to a managed target or treat a flag/state change as an
automatic migration. See the [full legacy guide](legacy-guide.md) for this path.

This alternative's Terraform configuration provisions:

- **AKS cluster** with a system node pool and an optional GPU-enabled workload node pool (toggled via `gpu_enabled`)
- **Helm releases** for KubeRay operator, Kueue (with RayJob/RayCluster integration), and GPU monitoring (DCGM exporter)
- **Azure Blob storage** with two private containers (`aurora` for weather data/checkpoints, `llm-pipeline` for LLM datasets/LoRA artifacts)
- **Workload identity** (managed identity + federated credential) so Ray pods authenticate to storage without secrets
- **Dataset uploads** — WeatherBench2 regional data for Aurora fine-tuning and viggo dataset for LLM training/inference

All resources are created in a single resource group and can be torn down with `terraform destroy`.
