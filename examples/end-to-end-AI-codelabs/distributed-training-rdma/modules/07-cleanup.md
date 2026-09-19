# Module 7: Clean up

**Goal:** stop billing for the two RDMA GPU nodes and all other lab resources.
**Time:** about 5 minutes to request deletion.

Delete the entire codelab resource group:

```bash
./scripts/90-cleanup.sh --all
```

The script refuses to delete a resource group unless it carries the ownership
tag created by this codelab. Azure deletion continues asynchronously.

Check progress:

```bash
SUBSCRIPTION_ID=${LAB_SUBSCRIPTION:-$(az account show --query id -o tsv)}
az group exists \
  --subscription "$SUBSCRIPTION_ID" \
  --name "${LAB_RESOURCE_GROUP:-aks-rdma-training-lab}"
```

The expected final value is `false`.

To delete only Kubernetes test jobs while retaining a dedicated cluster:

```bash
./scripts/90-cleanup.sh --workloads
```

This does **not** stop GPU billing. Use workload-only cleanup only when the
cluster has an intentional owner and lifecycle outside this exercise.
