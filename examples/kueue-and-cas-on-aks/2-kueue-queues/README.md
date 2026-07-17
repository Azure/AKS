# Module 2 — Kueue Queues + ProvisioningRequest gate

Configure Kueue to gate workloads and delegate capacity provisioning to the
cluster autoscaler.

## Prerequisites

- Module 1 infrastructure provisioned (autoscaling `scalepool`, Kueue installed).
- `kubectl` pointed at the cluster.

## Apply the manifests

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/10-resource-flavor.yaml
kubectl apply -f manifests/20-provisioning.yaml
```

| File | What it creates |
|------|-----------------|
| `00-namespace.yaml` | The `cas-demo` namespace for the workload and LocalQueue |
| `10-resource-flavor.yaml` | A ResourceFlavor pinned to the autoscaling `scalepool` |
| `20-provisioning.yaml` | The ProvisioningRequest `AdmissionCheck` + `ProvisioningRequestConfig`, the `ClusterQueue` that references them, and the `LocalQueue` |

## How the pieces connect

- **ProvisioningRequestConfig** `cas-provreq-config` selects the
  `best-effort-atomic-scale-up.autoscaling.x-k8s.io` provisioning class — CAS
  adds the requested capacity as a single atomic increase.
- **AdmissionCheck** `cas-provisioning` uses the
  `kueue.x-k8s.io/provisioning-request` controller and points at that config.
- **ClusterQueue** `cluster-queue` lists `cas-provisioning` under
  `admissionChecks`, so every workload it admits first goes through the
  provisioning gate.

## Verify

```bash
kubectl get resourceflavor scalepool-flavor
kubectl get admissioncheck cas-provisioning
kubectl get clusterqueue cluster-queue
kubectl -n cas-demo get localqueue user-queue
```

## Next

Continue to [Module 3 — Workload](../3-workload/).
