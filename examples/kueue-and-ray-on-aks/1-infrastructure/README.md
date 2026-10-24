# Module 1 — Prepare a managed Ray and Kueue cluster

Use the **managed KubeRay and Kueue extensions** for the recommended example path.
Prepare an AKS cluster and its capacity, install the managed operators, and then
configure storage and workload identity before running Modules 2 and 3.

1. Follow [Managed setup](managed/) for the executable operator installer and
   Azure CLI storage/identity commands. It uses your explicitly selected AKS
   cluster and a private kubeconfig, not global context changes.
2. [Configure your customer-owned queues](../2-kueue-queues/).
3. [Run the workload examples](../3-workloads/).

The CPU autoscaler demo is independent: it needs managed Kueue and an autoscaling
CPU user pool, but no Ray runtime, GPU, storage, or workload identity. See its
[own prerequisites](../3-workloads/cas-batch-job/#prerequisites).

## Installation choices

| Path | Operator ownership | When to use it |
| --- | --- | --- |
| **Managed setup — recommended** | Azure extension resources `microsoft.kuberay` and `microsoft.kueue`. | Validate and run the managed-first Learn walkthroughs. |
| [Legacy Terraform alternative](terraform/legacy-guide.md) | Self-managed KubeRay/Kueue Helm releases. | Deliberately run the existing all-in-one self-managed lab. |

Don't apply both installations to the same cluster. This change doesn't migrate
Terraform state, uninstall existing controllers, adopt Helm ownership, or modify
the legacy Terraform resources. Use a clean target or an owner-reviewed removal
plan if a self-hosted operator is already present.

The managed extensions install the operators and supported APIs. You still own
your Ray runtime images, application code, queue policies, storage, and workload
identity. Installing an operator doesn't create the datasets or authorize pods
to read them.
