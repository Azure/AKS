# cas-batch-job — provision capacity with managed Kueue and the cluster autoscaler

A plain Kubernetes batch Job that demonstrates the **ProvisioningRequest → AKS
cluster autoscaler (CAS)** path. The Ray batch workloads admit against a
fixed quota on an already-provisioned GPU node; this one requests or provisions
capacity in an autoscaling CPU pool's virtual machine scale set (VMSS) before
the Job is admitted.

A `Provisioned=True` condition doesn't guarantee `Ready` Kubernetes nodes.
Placement checks for the managed `aks-default` hostname topology can delay
admission while eligible nodes become `Ready`. Pods can remain Pending after
admission while instances join the cluster.

This isolates the Kueue↔CAS integration from the Ray runtime — it's the
simplest way to see a *provision-first* scale-up end to end.

## How it works

```
Job (suspend: true, queue-name: cas-local-queue)
   │
   ▼
Kueue creates a Workload ──► AdmissionCheck aks-provisioning-check
   │                              │
   │                              ▼
   │                        ProvisioningRequest  ──►  cluster autoscaler
   │                              │                     atomically scales
   │                              ▼                     up `scalepool`
   └──── provisioning gate passes ◄── Provisioned=True
   │
   ▼
Kueue placement/topology checks → Workload admitted → suspend: false
   │
   ▼
pods schedule when eligible nodes are Ready → Job completes
```

The `best-effort-atomic-scale-up.autoscaling.x-k8s.io` provisioning class requests
an atomic capacity increase. This gate concerns VMSS capacity, not Kubernetes
node readiness or simultaneous pod scheduling.

<a id="why-this-matters-no-wasted-spend-on-partial-capacity"></a>

### Why this matters: reduce spend on partial capacity

The Job remains suspended while the provisioning gate is pending, so its pods
don't occupy a partially provisioned capacity block. If the request can't be
satisfied, CAS can reclaim unused nodes according to the cluster autoscaler
profile. Other workloads, node-joining delays, and profile settings can still
affect reclamation timing and cost.

If you are cost sensitive and want those partially provisioned nodes released
as fast as possible, run an aggressive scale-down
[cluster autoscaler profile](https://learn.microsoft.com/azure/aks/cluster-autoscaler?tabs=azure-cli#cluster-autoscaler-profile-settings)
on the cluster, for example:

```bash
az aks update \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
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

Steps 4–5 cover capacity provisioning. Node readiness is separate:
`Provisioned=True` at step 5 doesn't confirm that all new nodes are `Ready`.
Placement and other admission checks can delay step 6. After admission, pods
might still wait for nodes to join and become `Ready`.

## Prerequisites

- An AKS cluster running Kubernetes 1.34 or later with the
  [managed Kueue extension installed and verified](../../2-kueue-queues/#install-and-verify-managed-kueue).
  Don't add managed operators beside self-installed Kueue or KubeRay controllers.
  This CPU-only example doesn't require Ray, a GPU, storage, or workload identity.
- An autoscaling CPU user pool named `scalepool`. Use the `SUBSCRIPTION_ID`,
  `RESOURCE_GROUP`, and `CLUSTER_NAME` variables from the managed setup. If the pool doesn't exist, add
  it with one initial node:

  ```bash
  az aks nodepool add \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
    --name scalepool --mode User \
    --node-vm-size Standard_D4s_v6 --node-count 1 \
    --enable-cluster-autoscaler --min-count 1 --max-count 5

  kubectl wait --for=condition=Ready nodes \
    --selector agentpool=scalepool --timeout=10m
  ```

  The pool's maximum node count and available Azure capacity bound scale-up.
  Queue quota alone doesn't guarantee capacity.
- Verify the shared API provided by the cluster autoscaler and the managed
  defaults, then apply your customer-owned queue configuration from this
  `cas-batch-job` directory:

  ```bash
  kubectl wait --for=condition=Established \
    crd/provisioningrequests.autoscaling.x-k8s.io --timeout=2m
  kubectl wait --for=create resourceflavor/aks-cpu --timeout=5m
  kubectl wait --for=condition=Active admissioncheck/aks-provisioning-check --timeout=2m
  kubectl get provisioningrequestconfig aks-provisioning-config

  kubectl apply -f ../../2-kueue-queues/manifests/40-autoscale-queue.yaml
  kubectl wait --for=condition=Active clusterqueue/cas-cluster-queue --timeout=2m
  kubectl wait --for=condition=Active localqueue/cas-local-queue \
    --namespace cas-kueue-demo --timeout=2m
  ```

The queue references the existing `aks-cpu` flavor and `aks-provisioning-check`,
which uses the extension's `aks-provisioning-config`. The Job's
`agentpool: scalepool` selector targets the intended pool; don't edit the managed
flavor or provisioning defaults.

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

# CAS reports provisioning; check node readiness separately
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
kubectl get admissioncheck aks-provisioning-check -o yaml

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
| `Provisioned=True`, but the Job stays suspended | Placement, topology, or another admission check is still pending | Inspect Workload conditions and admission-check state, and check eligible nodes' `Ready` conditions. Don't patch the managed defaults. |
| Pods Pending after admission | Nodes aren't `Ready`, or a node label doesn't match | Check node conditions and pod events, then confirm `scalepool` nodes carry `agentpool=scalepool` (`kubectl get nodes --show-labels`) |

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

If you are done with the demo, delete its customer-owned namespace and queues:

```bash
kubectl delete -f ../../2-kueue-queues/manifests/40-autoscale-queue.yaml
```

Keep the managed `aks-cpu` ResourceFlavor, `aks-provisioning-check`,
`aks-provisioning-config`, priority classes, extension, and shared CRDs. The queue
manifest doesn't own or delete them. Verify the example resources are gone and
inspect the retained defaults:

```bash
kubectl get clusterqueue cas-cluster-queue          # Expected: NotFound
kubectl get namespace cas-kueue-demo                # Expected: NotFound
kubectl get admissioncheck aks-provisioning-check
kubectl get provisioningrequestconfig aks-provisioning-config
kubectl get resourceflavor aks-cpu
```

If you created `scalepool` only for this demo, review its remaining workloads
before deleting it. Skip this command for an existing shared pool:

```bash
az aks nodepool delete \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name scalepool
```

> If the example namespace remains in `Terminating`, inspect remaining Workloads,
> events, and controller health. Don't delete shared CRDs, clear finalizers
> manually, or uninstall the managed extension as a cleanup shortcut.
