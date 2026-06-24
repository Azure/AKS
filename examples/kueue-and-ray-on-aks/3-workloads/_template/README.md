# _template/ — Reference Templates

These are **reference templates** that define the standard fields shared by all
Module 3 workloads. They are documentation, not imported by any per-example code.

Each per-example directory (`aurora-finetune/`, `llm-training/`, etc.) contains
its own copy of the template with workload-specific pip packages, env vars, and
resource settings baked in. The per-example templates are the source of truth
for submission.

## Files

| File | Purpose |
|------|---------|
| `rayjob.yaml.tmpl` | Standard RayJob fields (suspend, Kueue label, workload identity, etc.) |
| `rayservice.yaml.tmpl` | Standard RayService fields (serveConfigV2, head/worker specs) |
| `submit.sh` | Generic RayJob submitter with full variable validation |
| `submit-service.sh` | Generic RayService submitter with full variable validation |

## Usage

These templates are useful as a starting point when adding new workloads.
Copy a template into a new example directory and customize the pip packages,
env vars, and resource requests for your workload.

The generic `submit.sh` and `submit-service.sh` validate **all** required
variables (including `PIP_PACKAGES`) before rendering. The per-example submit
scripts are simpler because they source `env.example` which sets the defaults.
