# Module 2 — Kueue Queues

Kubernetes manifests that configure [Kueue](https://kueue.sigs.k8s.io/)
resource management for the Ray workloads. This module sets up:

- The `ray` namespace and workload identity ServiceAccount
- ResourceFlavors that map to CPU and GPU node pools
- Queue configurations that control how workloads are admitted to the cluster

Two queue configurations are provided as **independent demos** — apply one or
the other, not both:

| Configuration | File | What it demonstrates |
|---------------|------|----------------------|
| **Single queue** | `manifests/20-single-queue.yaml` | One ClusterQueue with admission backpressure — one workload runs, the next waits |
| **Team queues** | `manifests/30-team-queues.yaml` | Two ClusterQueues in a shared cohort with borrowing and preemption |

## Prerequisites

- Module 1 infrastructure deployed (`terraform apply` completed successfully)
- `kubectl` configured to talk to the cluster:
  ```bash
  eval "$(terraform -chdir=1-infrastructure/terraform output -raw get_credentials_command)"
  ```
- Kueue controller running (deployed by Module 1 Helm release):
  ```bash
  kubectl -n kueue-system get pods
  # Expected: kueue-controller-manager-* in Running state
  ```

> All commands below assume your working directory is
> `kueue-and-ray-on-aks/2-kueue-queues/` (this module's root).

## Contents

| File | What it creates |
|------|-----------------|
| `manifests/00-namespace.yaml` | `ray` namespace |
| `manifests/10-resource-flavors.yaml` | `default` (any node) and `gpu` (NVIDIA accelerator nodes) ResourceFlavors |
| `manifests/20-single-queue.yaml` | `cluster-queue` ClusterQueue + `default` LocalQueue |
| `manifests/30-team-queues.yaml` | `team-a-cq` / `team-b-cq` ClusterQueues in `shared-cohort` + `team-a` / `team-b` LocalQueues |

## Apply

```bash
cd kueue-and-ray-on-aks/2-kueue-queues

# 1. Create namespace
kubectl apply -f manifests/00-namespace.yaml

# 2. Apply the workload identity ServiceAccount from Module 1
kubectl apply -f <(terraform -chdir=../1-infrastructure/terraform output -raw ray_workload_sa_yaml)

# 3. Create resource flavors
kubectl apply -f manifests/10-resource-flavors.yaml

# 4. Choose ONE queue configuration:

#   Option A — Single queue (start here if you're new to Kueue)
kubectl apply -f manifests/20-single-queue.yaml

#   Option B — Team queues (multi-tenant borrowing + preemption demo)
kubectl apply -f manifests/30-team-queues.yaml
```

> **⚠️ Choose one.** `20-single-queue.yaml` and `30-team-queues.yaml` are
> independent configurations. To switch between them, delete the active one
> first:
> ```bash
> kubectl delete -f manifests/20-single-queue.yaml   # then apply 30-team-queues.yaml
> ```

## Verify

### Namespace and ServiceAccount

```bash
kubectl get ns ray
kubectl -n ray get serviceaccount ray-workload -o yaml
```

The ServiceAccount should have `azure.workload.identity/client-id` and
`azure.workload.identity/tenant-id` annotations — these are what let Ray
pods read and write Azure Blob storage without credentials.

### ResourceFlavors

```bash
kubectl get resourceflavors
```

Expected output:

```
NAME      AGE
default   ...
gpu       ...
```

The `gpu` flavor targets nodes with label `accelerator: nvidia`,
which AKS automatically stamps on GPU node pools.

### ClusterQueues and LocalQueues

**Option A — Single queue:**

```bash
kubectl get clusterqueue cluster-queue
kubectl -n ray get localqueue default
```

Expected: both resources exist, `cluster-queue` shows the configured quota.

```bash
kubectl get clusterqueue cluster-queue -o jsonpath='{.spec.resourceGroups}' | python3 -m json.tool
```

Verify the quotas match your cluster: 96 CPU, 768 Gi memory, 8 GPUs (default
values sized for a single `Standard_ND96amsr_A100_v4` node).

**Option B — Team queues:**

```bash
kubectl get clusterqueues
kubectl -n ray get localqueues
```

Expected:

```
NAME        COHORT          ...
team-a-cq   shared-cohort   ...
team-b-cq   shared-cohort   ...
```

```
NAME     CLUSTER QUEUE   ...
team-a   team-a-cq       ...
team-b   team-b-cq       ...
```

Verify the per-team quotas and borrowing limits:

```bash
kubectl get clusterqueue team-a-cq -o jsonpath='{.spec.resourceGroups}' | python3 -m json.tool
kubectl get clusterqueue team-b-cq -o jsonpath='{.spec.resourceGroups}' | python3 -m json.tool
```

Each team should show: 48 CPU / 768 Gi memory (default flavor) and 4 GPUs with
`borrowingLimit: 4` (gpu flavor). The borrowing limit lets each team use up to
8 GPUs total when the other team is idle.

## How it works

### Kueue concepts in 60 seconds

```
┌─────────────────────────────────────────────────┐
│ Cluster-wide                                    │
│                                                 │
│  ResourceFlavor        ResourceFlavor            │
│  ┌─────────┐          ┌─────────────┐           │
│  │ default │          │     gpu     │           │
│  │ any node│          │ nvidia node │           │
│  └─────────┘          └─────────────┘           │
│                                                 │
│  ClusterQueue(s) — quota + admission policy     │
│  ┌──────────────────────────────────────┐       │
│  │ cpu: 96, memory: 768Gi (default)     │       │
│  │ nvidia.com/gpu: 8      (gpu)        │       │
│  └──────────────────────────────────────┘       │
│                                                 │
├─────────────────────────────────────────────────┤
│ Namespace: ray                                  │
│                                                 │
│  LocalQueue ──► points to ClusterQueue          │
│                                                 │
│  RayJob (suspend: true)                         │
│    label: kueue.x-k8s.io/queue-name: <queue>   │
│    → Kueue admits when quota is available       │
│    → sets suspend: false → Ray starts           │
│                                                 │
└─────────────────────────────────────────────────┘
```

1. **ResourceFlavors** describe *types of nodes* (CPU-only vs GPU). They map
   Kueue's quota system to physical capacity via node labels.

2. **ClusterQueues** define *how much* of each resource is available and the
   admission policy (FIFO, preemption rules). They reference ResourceFlavors.

3. **LocalQueues** live in a namespace and point to a ClusterQueue. Workloads
   submit to LocalQueues.

4. **Workloads** (RayJobs in our case) are created with `suspend: true` and a
   `kueue.x-k8s.io/queue-name` label. Kueue watches for these, checks quota,
   and un-suspends admitted workloads.

### Single queue — admission backpressure

The single-queue configuration creates one ClusterQueue with quotas sized for
one Module 3 workload at a time:

- **CPU:** 96 cores, 768 Gi memory (default flavor)
- **GPU:** 8 × `nvidia.com/gpu` (gpu flavor)
- **Strategy:** `BestEffortFIFO` — admits in submission order when possible

When the quota is fully consumed by a running workload, the next submission
stays `Pending` until the first completes (or is deleted). This is the
simplest demonstration of Kueue: fair scheduling with backpressure.

### Team queues — cohort borrowing and preemption

The team-queue configuration splits the GPU node across two teams, each with
their own ClusterQueue, connected via a **cohort** (shared pool):

```
shared-cohort
├── team-a-cq: 4 GPU guaranteed, can borrow 4 more
└── team-b-cq: 4 GPU guaranteed, can borrow 4 more
```

Key behaviors:

| Scenario | What happens |
|----------|-------------|
| Team A submits, Team B idle | Team A gets all 8 GPUs (4 own + 4 borrowed) |
| Team B submits while Team A uses 8 | Kueue **preempts** Team A's borrowed GPUs, Team B gets its guaranteed 4 |
| Both teams busy | Each team uses its guaranteed 4 GPUs |
| Both teams idle, Team A submits | Team A can borrow Team B's idle 4 GPUs |

Preemption policy:
- `withinClusterQueue: LowerPriority` — within a team, higher-priority jobs go first
- `reclaimWithinCohort: Any` — a team can reclaim its lent GPUs from any borrower

**Demo idea:** Submit an 8-GPU RayJob to `team-a`, watch it consume all GPUs.
Then submit a 4-GPU RayJob to `team-b` — Kueue will preempt Team A down to 4
GPUs and admit Team B's job. See Module 3 for ready-to-run workload examples.

### Quota sizing

The default quotas are sized for a single `Standard_ND96amsr_A100_v4` node
(96 vCPUs, 1.8 TiB RAM, 8×A100 GPUs). CPU and memory quotas are set to the
node's full capacity so that GPU count is the only admission constraint.

Module 3 workload resource requirements:

| Example | Workers | CPU (head + workers) | Memory (head + workers) | GPUs |
|---------|---------|---------------------|------------------------|------|
| aurora-finetune | 1 | 24 | 176 Gi | 1 |
| batch-inference | 1 | 24 | 176 Gi | 1 |
| llm-training | 4 | 84 | 656 Gi | 4 |
| online-serving | 1 | 24 | 176 Gi | 1 (not Kueue-admitted) |

> **Note:** Kueue charges **all** pod CPU and memory against the `default`
> flavor quota — including GPU workers — because CPU/memory and
> `nvidia.com/gpu` are in separate resource groups. The quotas must be large
> enough to cover the full workload, not just the head.

If you use a different GPU SKU or node size, adjust the `nominalQuota` values
in the ClusterQueue manifests to match your available resources.

## Switching queue configurations

To switch from single queue to team queues (or vice versa):

```bash
# Delete the active configuration
kubectl delete -f manifests/20-single-queue.yaml

# Apply the new one
kubectl apply -f manifests/30-team-queues.yaml
```

Pending workloads will be re-evaluated against the new queue configuration.
Running workloads are not affected — they complete under the old admission.

## Troubleshooting

### Workload stays Pending

```bash
kubectl -n ray describe workload <workload-name>
```

Check the `Events` section for admission failures. Common causes:

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Inadmissible: insufficient quota for nvidia.com/gpu` | Queue quota exhausted | Wait for the running workload to finish, or increase `nominalQuota` in the ClusterQueue |
| `Inadmissible: insufficient quota for cpu` | CPU quota too low for Ray head + workers | Increase CPU `nominalQuota` in the ClusterQueue |
| `LocalQueue not found` | Wrong queue name in RayJob label | Verify the `kueue.x-k8s.io/queue-name` label matches an existing LocalQueue name |
| `ClusterQueue is stopped` | ClusterQueue has `stopPolicy` set | Remove the `stopPolicy` field |

### ResourceFlavor not matching nodes

```bash
kubectl get nodes --show-labels | grep accelerator
```

The `gpu` ResourceFlavor expects `accelerator=nvidia`. If your GPU nodes
don't have this label, AKS may not have labeled them automatically —
check that the node pool uses a supported NVIDIA GPU SKU.

### Kueue controller not running

```bash
kubectl -n kueue-system get pods
kubectl -n kueue-system logs deploy/kueue-controller-manager
```

If the controller is crashlooping, check the Helm release:

```bash
helm -n kueue-system list
helm -n kueue-system get values kueue
```

The Kueue Helm release is managed by Module 1 Terraform. If you need to
redeploy: `terraform -chdir=../1-infrastructure/terraform apply`.

## Clean up

To remove just the Kueue queue configuration (keeps the cluster):

```bash
kubectl delete -f manifests/30-team-queues.yaml   # or 20-single-queue.yaml
kubectl delete -f manifests/10-resource-flavors.yaml
kubectl delete -f manifests/00-namespace.yaml
```

> **Note:** Deleting the `ray` namespace removes all workloads, LocalQueues,
> and the ServiceAccount in that namespace. ClusterQueues and ResourceFlavors
> are cluster-scoped and must be deleted separately.

To tear down everything (including the cluster), use Module 1:

```bash
cd ../1-infrastructure/terraform && terraform destroy
```

## Next steps

→ [Module 3 — Workloads](../3-workloads/) — submit RayJob and RayService
examples that use the queues configured here.
