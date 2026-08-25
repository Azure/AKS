# Kueue Queue Manifests

Kubernetes manifests for Kueue resource management. Apply these in numbered
order after Module 1 infrastructure is provisioned.

## Files

| File | What it creates |
|------|-----------------|
| `00-namespace.yaml` | `ray` namespace |
| `10-resource-flavors.yaml` | `default` (any node) and `gpu` (NVIDIA accelerator) ResourceFlavors |
| `20-single-queue.yaml` | Single `cluster-queue` ClusterQueue + `default` LocalQueue |
| `30-team-queues.yaml` | Team-based `team-a-cq` / `team-b-cq` ClusterQueues with `shared-cohort` borrowing and preemption |

## Quick start

```bash
# 1. Create namespace + apply the workload identity ServiceAccount from Module 1
kubectl apply -f 00-namespace.yaml
kubectl apply -f <(terraform -chdir=../1-infrastructure/terraform output -raw ray_workload_sa_yaml)

# 2. Create resource flavors
kubectl apply -f 10-resource-flavors.yaml

# 3. Choose ONE queue configuration:

# Option A — Single queue (admission backpressure demo)
kubectl apply -f 20-single-queue.yaml

# Option B — Team queues (cohort borrowing + preemption demo)
kubectl apply -f 30-team-queues.yaml
```

> **Note:** Apply either `20-single-queue.yaml` or `30-team-queues.yaml` — they
> are independent configurations, not meant to coexist. To switch, delete one
> before applying the other.
