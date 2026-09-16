# Module 5: Configure provisioning

**Goal:** Connect the Kueue queue to the AKS cluster autoscaler.

**Time:** About 3 minutes.

## Apply the queue

```bash
./scripts/40-configure-queue.sh
```

The configuration creates:

- a ResourceFlavor pinned to `agentpool=gpupool`;
- a ProvisioningRequestConfig for atomic scale-up;
- an AdmissionCheck controlled by Kueue's provisioning controller;
- a ClusterQueue with quota for three GPUs;
- a LocalQueue in the `gpu-inference` namespace.

The provisioning class is
`best-effort-atomic-scale-up.autoscaling.x-k8s.io`. Kueue asks the cluster
autoscaler to provision the complete pod set before it admits the Job.

## Checkpoint

```bash
kubectl get crd provisioningrequests.autoscaling.x-k8s.io
kubectl get admissioncheck gpu-inference-provisioning
kubectl get clusterqueue gpu-inference-cluster-queue
kubectl -n gpu-inference get localqueue gpu-inference
```

The ClusterQueue should report `ACTIVE=True`.

## Troubleshoot

| Problem | Action |
|---|---|
| ProvisioningRequest CRD is missing | Confirm the cluster runs Kubernetes 1.33 or later and the feature is available in the selected region |
| ClusterQueue is inactive | Run `kubectl describe clusterqueue gpu-inference-cluster-queue` and verify the ResourceFlavor and AdmissionCheck names |
| API version isn't recognized | Confirm Kueue 0.17.1 installed successfully in Module 4 |

## Next step

Continue to [Module 6: Run inference](06-run-inference.md).
