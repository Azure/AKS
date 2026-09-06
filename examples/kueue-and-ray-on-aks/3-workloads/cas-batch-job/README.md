# cas-batch-job — provision capacity on demand with Kueue + cluster autoscaler

A plain Kubernetes batch Job that demonstrates the **ProvisioningRequest → AKS
cluster autoscaler (CAS)** path. The other Module 3 workloads admit against a
fixed quota on an already-provisioned GPU node; this one instead asks CAS to
*grow* an autoscaling CPU pool before the Job is admitted, so batch capacity is
provisioned just-in-time.

This isolates the Kueue↔CAS integration from the Ray runtime — it's the
simplest way to see a *provision-first* scale-up end to end.

## How it works

```
Job (suspend: true, queue-name: cas-local-queue)
   │
   ▼
Kueue creates a Workload ──► AdmissionCheck cas-provisioning
   │                              │
   │                              ▼
   │                        ProvisioningRequest  ──►  cluster autoscaler
   │                              │                     atomically scales
   │                              ▼                     up `scalepool`
   └──── admitted once nodes exist ◄── Provisioned=True
   │
   ▼
suspend flips to false → 3 pods schedule on the new nodes → Job completes
```

The atomic `best-effort-atomic-scale-up.autoscaling.x-k8s.io` provisioning class
adds the whole capacity block at once, avoiding the half-scheduled gang problem
where some pods land and others sit Pending.

### Why this matters: no wasted spend on partial capacity

Because pods stay gated until the *entire* capacity block is provisioned, the
cluster autoscaler can quickly clean up partially provisioned nodes — no pods
have been scheduled on them, so nothing blocks scale-down. This is especially
valuable when a scale-up is cut short by capacity or quota limits: instead of
paying for a handful of nodes that sit half-used while the gang waits, the
autoscaler reclaims them and the Job simply stays suspended until the full
block can be satisfied. For gang-scheduled batch and AI training jobs, this
significantly reduces wasteful compute spend.

If you are cost sensitive and want those partially provisioned nodes released
as fast as possible, run an aggressive scale-down
[cluster autoscaler profile](https://learn.microsoft.com/azure/aks/cluster-autoscaler?tabs=azure-cli#cluster-autoscaler-profile-settings)
on the cluster, for example:

```bash
az aks update \
  --resource-group <rg> --name <cluster> \
  --cluster-autoscaler-profile \
      scale-down-unneeded-time=1m \
      scale-down-delay-after-add=1m \
      scale-down-unready-time=5m \
      max-graceful-termination-sec=60
```

These profile settings are cluster-wide and apply to the scale-up and
scale-down that this ProvisioningRequest integration triggers, so tune them
alongside the queue configuration rather than in isolation.

### State transitions

A successful run passes through these states in order. If a run stalls, the last
state reached tells you which component to look at — see
[Troubleshooting](#troubleshooting).

| # | State | Check |
|---|-------|-------|
| 1 | Job exists, `suspend: true` | `kubectl -n cas-kueue-demo get job kueue-cas-job -o jsonpath='{.spec.suspend}'` → `true` |
| 2 | Kueue creates a Workload | `kubectl -n cas-kueue-demo get workloads` |
| 3 | AdmissionCheck is `Pending` | `kubectl -n cas-kueue-demo get workloads -o jsonpath='{.items[*].status.admissionChecks[*].state}'` |
| 4 | ProvisioningRequest created | `kubectl -n cas-kueue-demo get provisioningrequest` |
| 5 | ProvisioningRequest `Provisioned=True` | `kubectl -n cas-kueue-demo get provisioningrequest -o jsonpath='{.items[*].status.conditions[?(@.type=="Provisioned")].status}'` |
| 6 | Workload admitted | `kubectl -n cas-kueue-demo get workloads -o jsonpath='{.items[*].status.conditions[?(@.type=="Admitted")].status}'` |
| 7 | Job suspension flips to `false` | `kubectl -n cas-kueue-demo get job kueue-cas-job -o jsonpath='{.spec.suspend}'` → `false` |
| 8 | Pods scheduled on new nodes | `kubectl -n cas-kueue-demo get pods -o wide` |
| 9 | Job completes | `kubectl -n cas-kueue-demo get job kueue-cas-job` → `Complete 3/3` |

Steps 4–5 are the CAS scale-up and take the longest — allow a few minutes for
new nodes to join.

## Prerequisites

- An AKS cluster running Kubernetes 1.30+ with the cluster autoscaler enabled
  (ProvisioningRequest support), and Kueue v0.7.0 or later. The companion
  AKS how-to guide lists the supported version matrix in detail.
- Module 1 cluster deployed and Kueue running.
- An **autoscaling** CPU pool named `scalepool`. If your Module 1 cluster
  doesn't have one, add it:
  ```bash
  az aks nodepool add \
    --resource-group <rg> --cluster-name <cluster> \
    --name scalepool --mode User \
    --node-vm-size Standard_D4s_v3 \
    --enable-cluster-autoscaler --min-count 1 --max-count 5
  ```
  `--min-count 0` also works — the pool can scale from zero, and the
  ProvisioningRequest simply provisions the whole block from empty. `--max-count`
  is the real ceiling: a request larger than it fails with
  `Provisioned=False` / `CapacityIsNotFound` rather than partially scheduling.
- The autoscale queue applied from Module 2:
  ```bash
  kubectl apply -f ../../2-kueue-queues/manifests/40-autoscale-queue.yaml
  ```

## Submit

```bash
kubectl apply -f manifests/job.yaml
```

The Job requests 3 pods at 1800m CPU each. On a pool starting at one 4-core node
they cannot all fit, so Kueue asks CAS to scale up before admitting them.

## Watch the flow

```bash
# The Job starts Suspended
kubectl -n cas-kueue-demo get job kueue-cas-job

# Kueue creates a Workload, then a ProvisioningRequest
kubectl -n cas-kueue-demo get workloads
kubectl -n cas-kueue-demo get provisioningrequest

# CAS provisions the nodes (Provisioned=True), the pool grows
kubectl -n cas-kueue-demo get provisioningrequest -o yaml | grep -A5 conditions
kubectl get nodes -l agentpool=scalepool

# Job runs to completion
kubectl -n cas-kueue-demo get job kueue-cas-job -w   # COMPLETIONS 3/3
```

Expected end state:

```output
NAME            STATUS     COMPLETIONS   DURATION   AGE
kueue-cas-job   Complete   3/3           45s        6m
```

## Observability

If a run stalls, these are the logs and events that explain why, in the order
the request flows through the system:

```bash
# Workload conditions (QuotaReserved, Admitted) and admission-check state
kubectl -n cas-kueue-demo get workloads -o yaml

# AdmissionCheck status
kubectl get admissioncheck cas-provisioning -o yaml

# ProvisioningRequest conditions and events (Provisioned / CapacityIsNotFound)
kubectl -n cas-kueue-demo describe provisioningrequest

# Kueue controller logs — provisioning-request creation and failures
kubectl -n kueue-system logs deploy/kueue-controller-manager -c manager --tail=200

# Cluster autoscaler decisions (AKS surfaces these as cluster events)
kubectl get events -A --field-selector source=cluster-autoscaler \
  --sort-by=.lastTimestamp
kubectl -n kube-system describe configmap cluster-autoscaler-status
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job stays `Suspended`, no ProvisioningRequest | Wrong queue-name label | Verify `kueue.x-k8s.io/queue-name: cas-local-queue` matches the LocalQueue |
| ProvisioningRequest created but `status.conditions` empty | Cluster autoscaler not yet processing the request | Check the autoscaler is enabled on `scalepool` and re-check after a minute |
| `Provisioned=False` with reason `CapacityIsNotFound` | Pool can't reach the requested size — existing workloads occupy it, or the request exceeds `--max-count` | Free capacity or raise `--max-count`. CAS keeps retrying; the Job stays suspended rather than partially scheduling |
| Pods Pending after admission | Node label mismatch | Confirm `scalepool` nodes carry `agentpool=scalepool` (`kubectl get nodes --show-labels`) |

## Clean up

Remove things in this order — the Job first, so Kueue releases its Workload and
the ProvisioningRequest is garbage-collected before the queues that own them go
away.

```bash
# 1. The Job. Deleting it releases the Workload; Kueue then removes the
#    ProvisioningRequest it created.
kubectl delete -f manifests/job.yaml

# 2. Confirm nothing is left holding quota.
kubectl -n cas-kueue-demo get workloads,provisioningrequest
```

If you are done with the demo entirely, also remove the queue objects and the
node pool:

```bash
# 3. The Kueue objects from Module 2. This deletes the cas-kueue-demo namespace
#    (and cas-local-queue inside it), plus the cluster-scoped cas-cluster-queue,
#    cas-provisioning AdmissionCheck, cas-provreq-config, and scalepool
#    ResourceFlavor.
kubectl delete -f ../../2-kueue-queues/manifests/40-autoscale-queue.yaml

# 4. The autoscaling node pool added in the Prerequisites. Skip this if
#    scalepool was already part of your Module 1 cluster.
az aks nodepool delete \
  --resource-group <rg> --cluster-name <cluster> \
  --name scalepool
```

Verify the cluster is clean:

```bash
kubectl get clusterqueue cas-cluster-queue          # NotFound
kubectl get admissioncheck cas-provisioning         # NotFound
kubectl get resourceflavor scalepool                # NotFound
kubectl get namespace cas-kueue-demo                # NotFound
```

> If the `cas-kueue-demo` namespace hangs in `Terminating`, a Workload is still
> pending finalization. Re-run step 1 and confirm step 2 returns no resources
> before retrying the namespace delete.
