# Kueue queue manifests

Use the [managed Kueue and KubeRay setup](../README.md). Apply one queue policy,
not the whole folder.

| File | Ownership and purpose |
| --- | --- |
| `00-namespace.yaml` | Customer-owned `ray` namespace. Prepare its workload identity through Module 2. |
| `15-managed-queue.yaml.tmpl` | Recommended Ray queue policy, rendered with existing verified managed CPU/GPU ResourceFlavors. Creates only queues. |
| `10-resource-flavors.yaml` | Optional customer-owned `default`/`gpu` placement flavors, only when managed flavors don't meet your policy. Never replaces `aks-*` objects. |
| `20-single-queue.yaml` | Optional fixed-quota policy for the custom `default`/`gpu` flavors. |
| `30-team-queues.yaml` | Optional team/cohort/borrowing policy for custom flavors. Use instead of the single queue. |
| `40-autoscale-queue.yaml` | CPU demo namespace/queues referencing managed `aks-cpu` and `aks-provisioning-check`. |

Start with `15-managed-queue.yaml.tmpl` for Ray. GPU flavor names vary, so inspect
the cluster and render the names as described in the parent guide. Verify their
node selectors, topology, and physical resources. Don't combine a CPU-only
flavor's selector with a GPU flavor for the same worker's CPU/GPU requests.

If you need a custom placement policy, explicitly choose `10-resource-flavors.yaml`
and either `20-single-queue.yaml` or `30-team-queues.yaml` instead. The operators
remain managed in every case.

The independent CPU autoscaler demo needs only `40-autoscale-queue.yaml` after its
pool, API, and defaults pass verification. It doesn't need the Ray namespace,
ServiceAccount, GPU flavors, storage, or dataset preparation.

Delete only the workloads and customer-owned policy objects you created. Keep
managed flavors, priority classes, admission/provisioning defaults, and shared
CRDs intact. See [cleanup](../README.md#clean-up) for the selected policy.
