# Module 7: Clean up

Remove GPU capacity as soon as you finish.

## Remove the workload and GPU pool

```bash
./scripts/90-cleanup.sh
```

This path:

1. Verifies that `kubectl` points to the example cluster.
2. Refuses to delete Kubernetes objects without the example ownership label.
3. Deletes the vLLM workload, staging Job, persistent volume claim, namespace,
   and StorageClass.
4. Deletes the managed GPU node pool.
5. Leaves the AKS cluster and CPU system nodes running.

Use this option when you want to inspect the cluster after completing the
example.

## Delete every example resource

```bash
./scripts/90-cleanup.sh --all
```

The script deletes the complete resource group only when it has the exact
ownership tag created in Module 1. Azure continues resource group deletion in
the background.

## Checkpoint

For standard cleanup:

```bash
az aks nodepool show \
  --resource-group "${LAB_RESOURCE_GROUP:-aks-managed-gpu-inference}" \
  --cluster-name "${LAB_CLUSTER:-aks-managed-gpu-inference}" \
  --name a100np
```

Expect `ResourceNotFound`.

For complete cleanup:

```bash
az group show \
  --name "${LAB_RESOURCE_GROUP:-aks-managed-gpu-inference}"
```

Expect `ResourceGroupNotFound` after Azure finishes deleting the group.

## Troubleshoot

| Problem | Action |
| --- | --- |
| The active context does not match | Rerun `./scripts/10-create-cluster.sh` before standard cleanup |
| An ownership check fails | Inspect the object before deleting it manually; the script will not remove shared resources |
| The persistent volume remains | Check the PVC and storage account deletion state; the StorageClass uses `reclaimPolicy: Delete` |
| Resource group deletion is still running | Query `az group show` until Azure reports that the group no longer exists |
