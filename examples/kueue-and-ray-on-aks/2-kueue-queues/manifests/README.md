# Kueue queue manifests

Use these files with the [managed Kueue setup and verification steps](../README.md).
Apply only the demo you choose, not the whole directory.

| File | Ownership and purpose |
| --- | --- |
| `00-namespace.yaml` | Creates the customer-owned `ray` namespace for Ray demos. |
| `10-resource-flavors.yaml` | Creates customer-owned `default` and `gpu` flavors for the Ray demos. It doesn't replace generated AKS flavors. |
| `20-single-queue.yaml` | Creates the `cluster-queue` ClusterQueue and `default` LocalQueue. |
| `30-team-queues.yaml` | Creates `team-a-cq` and `team-b-cq` ClusterQueues with cohort borrowing, plus their LocalQueues. Use instead of the single queue. |
| `40-autoscale-queue.yaml` | Creates the CPU demo's namespace, ClusterQueue, and LocalQueue. References existing managed `aks-cpu` and `aks-provisioning-check` resources. |

The CPU autoscale demo needs only `40-autoscale-queue.yaml`, after verifying its
managed defaults and autoscaling pool. It doesn't use the Ray namespace,
ServiceAccount, or the customer-owned Ray flavors.

For either Ray demo, prepare the `ray` namespace and authorized workload identity,
apply `10-resource-flavors.yaml`, and then choose **either**
`20-single-queue.yaml` **or** `30-team-queues.yaml`. Follow the parent guide for
verification, quota sizing, safe switching, and cleanup.

Don't create, edit, or delete the managed `aks-*` defaults. Deleting
`40-autoscale-queue.yaml` removes only the example's customer-owned namespace and
queues, not the managed provisioning check, config, or flavor.
