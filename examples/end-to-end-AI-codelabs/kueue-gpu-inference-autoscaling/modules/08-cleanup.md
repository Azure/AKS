# Module 8: Clean up

**Goal:** Stop GPU charges and remove the resources created by the codelab.

**Time:** About 5 minutes to start cleanup. Azure resource deletion continues in
the background.

## Remove the workload first

```bash
./scripts/90-cleanup.sh
```

Deleting the Job releases its Kueue Workload and ProvisioningRequest. The
script first verifies that kubectl targets the lab cluster. It deletes the
dedicated namespace and cluster-scoped queue objects only when their codelab
ownership labels are present, and waits for generated Workloads and
ProvisioningRequests to disappear before removing the queue. With no GPU pods
left, the cluster autoscaler can return `gpupool` to zero after its scale-down
delay.

Check the count:

```bash
. ./scripts/lib.sh
az aks nodepool show \
  --resource-group "$LAB_RESOURCE_GROUP" \
  --cluster-name "$LAB_CLUSTER" \
  --name "$LAB_GPU_POOL" \
  --query count -o tsv
```

## Delete all lab resources

Don't wait for scale-down if you're finished. Delete the resource group. The
script refuses this operation unless the resource group has the ownership tag
added during Module 2:

```bash
./scripts/90-cleanup.sh --all
```

## Checkpoint

```bash
. ./scripts/lib.sh
az group exists --name "$LAB_RESOURCE_GROUP"
```

The command eventually returns `false`.

## What you accomplished

You started with no GPU nodes and followed one workload through:

1. Kueue quota reservation.
2. ProvisioningRequest creation.
3. AKS cluster autoscaler scale-up.
4. Workload admission.
5. GPU scheduling and model startup.
6. A successful OpenAI-compatible inference request.
7. Resource cleanup and scale-down.

Return to the [end-to-end AI codelabs](../../README.md).
