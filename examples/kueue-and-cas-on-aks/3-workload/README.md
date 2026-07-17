# Module 3 — Workload

Submit a suspended batch Job and watch Kueue admit it by driving the cluster
autoscaler to provision nodes.

## Prerequisites

- Module 2 queues applied (`cluster-queue`, `user-queue`, `cas-provisioning`).

## Submit the Job

```bash
kubectl apply -f manifests/job.yaml
```

The Job requests 3 pods at 1800m CPU each. On a pool starting at one 4-core node
they cannot all fit, so Kueue asks CAS to scale up before admitting them.

## Watch the flow

```bash
# The Job starts Suspended
kubectl -n cas-demo get job kueue-cas-job

# Kueue creates a Workload, then a ProvisioningRequest
kubectl -n cas-demo get workloads
kubectl -n cas-demo get provisioningrequest

# CAS provisions the nodes (Provisioned=True), the pool grows
kubectl -n cas-demo get provisioningrequest -o yaml | grep -A5 conditions
kubectl get nodes -l agentpool=scalepool

# Job runs to completion
kubectl -n cas-demo get job kueue-cas-job -w   # COMPLETIONS 3/3
```

Expected end state:

```output
NAME            STATUS     COMPLETIONS   DURATION   AGE
kueue-cas-job   Complete   3/3           45s        6m
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job stays `Suspended`, no ProvisioningRequest | Wrong queue-name label | Verify `kueue.x-k8s.io/queue-name: user-queue` matches the LocalQueue |
| ProvisioningRequest created but `status.conditions` empty | CAS not consuming ProvisioningRequests | The autoscaler needs `--enable-provisioning-requests` (see Module 1 note) |
| Pods Pending after admission | Node label mismatch | Confirm `scalepool` nodes carry `agentpool=scalepool` |

## Cleanup

```bash
kubectl delete -f manifests/job.yaml
```
