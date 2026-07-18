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
Job (suspend: true, queue-name: autoscale)
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

## Prerequisites

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
- The cluster autoscaler must run with `--enable-provisioning-requests` (this is
  what consumes the ProvisioningRequest — without it the request is created but
  never satisfied).
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
kubectl -n ray get job kueue-cas-job

# Kueue creates a Workload, then a ProvisioningRequest
kubectl -n ray get workloads
kubectl -n ray get provisioningrequest

# CAS provisions the nodes (Provisioned=True), the pool grows
kubectl -n ray get provisioningrequest -o yaml | grep -A5 conditions
kubectl get nodes -l agentpool=scalepool

# Job runs to completion
kubectl -n ray get job kueue-cas-job -w   # COMPLETIONS 3/3
```

Expected end state:

```output
NAME            STATUS     COMPLETIONS   DURATION   AGE
kueue-cas-job   Complete   3/3           45s        6m
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job stays `Suspended`, no ProvisioningRequest | Wrong queue-name label | Verify `kueue.x-k8s.io/queue-name: autoscale` matches the LocalQueue |
| ProvisioningRequest created but `status.conditions` empty | CAS not consuming ProvisioningRequests | The autoscaler needs `--enable-provisioning-requests` |
| Pods Pending after admission | Node label mismatch | Confirm `scalepool` nodes carry `agentpool=scalepool` (`kubectl get nodes --show-labels`) |

## Clean up

```bash
kubectl delete -f manifests/job.yaml
```
