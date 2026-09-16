# Module 7: Observe and troubleshoot

**Goal:** Identify the component responsible for each state transition.

**Time:** About 10 minutes.

## Follow the handoffs

Inspect the resources in order. Stop at the first stage that isn't healthy.

### 1. Kueue Workload

```bash
kubectl -n gpu-inference get workloads
kubectl -n gpu-inference get workloads -o yaml
```

`QuotaReserved=True` means quota has been assigned. `Admitted=True` means every
admission check passed and Kueue released the Job.

### 2. Admission check

```bash
kubectl -n gpu-inference get workloads \
  -o jsonpath='{range .items[*].status.admissionChecks[*]}{.name}{"\t"}{.state}{"\t"}{.message}{"\n"}{end}'
```

`Pending` means Kueue is waiting for capacity. `Ready` allows admission.

### 3. ProvisioningRequest

```bash
kubectl -n gpu-inference get provisioningrequests
kubectl -n gpu-inference describe provisioningrequest
```

`Provisioned=True` means the cluster autoscaler found or added VM capacity. It
doesn't by itself prove that a new VM registered as a Ready Kubernetes node.
`Provisioned=False` with `CapacityIsNotFound` means the complete request can't
fit within available regional capacity and node pool limits. `BookingExpired`
means the reserved capacity wasn't consumed before the reservation expired.

### 4. GPU node and device plugin

```bash
kubectl get nodes -l agentpool=gpupool \
  -o 'custom-columns=NODE:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
kubectl -n kube-system get pods -l app.kubernetes.io/name=nvidia-device-plugin -o wide
```

All three new nodes must register as Ready and advertise one GPU before the
inference pods can start. If the Azure pool count is higher than the number of
Ready nodes, one or more nodes are still bootstrapping or failed to register.

### 5. Inference

```bash
kubectl -n gpu-inference get pods -o wide
kubectl -n gpu-inference logs job/vllm-inference-check
```

The final line `INFERENCE_VALIDATED` proves that scheduling alone wasn't the
finish line: the container accessed the GPU, loaded the model, started the
server, and returned an inference response.

## Understand the boundaries

This codelab provisions three nodes atomically for **one admitted Workload**.
It doesn't implement request-driven scaling for a long-running inference
service:

- Kueue controls workload admission.
- The cluster autoscaler controls node count.
- KEDA or the Horizontal Pod Autoscaler controls replica count.

A later codelab can connect vLLM queue depth to replica scaling. Keeping that
separate makes this first control-plane path easier to understand and diagnose.

## Checkpoint

Confirm that the Job completed and the successful ProvisioningRequest remains
visible for inspection:

```bash
kubectl -n gpu-inference get job vllm-inference-check
kubectl -n gpu-inference get provisioningrequests
```

## Next step

Continue to [Module 8: Clean up](08-cleanup.md).
