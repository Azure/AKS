# Module 7: Clean up

**Goal:** stop billing for the two RDMA GPU nodes and all other lab resources.
**Time:** about 5 minutes to request deletion.

Delete the entire codelab resource group:

```bash
./scripts/90-cleanup.sh --all
```

The script refuses to delete a resource group unless it carries the ownership
tag created by this codelab. Azure deletion continues asynchronously.

To delete only Kubernetes test jobs while retaining a dedicated cluster:

```bash
./scripts/90-cleanup.sh --workloads
```

This does **not** stop GPU billing. Use workload-only cleanup only when the
cluster has an intentional owner and lifecycle outside this exercise.

## Checkpoint

Check Azure deletion progress:

```bash
SUBSCRIPTION_ID=${LAB_SUBSCRIPTION:-$(az account show --query id -o tsv)}
az group exists \
  --subscription "$SUBSCRIPTION_ID" \
  --name "${LAB_RESOURCE_GROUP:-aks-rdma-training-lab}"
```

Cleanup is complete when the command returns `false`.

## Troubleshooting

- **Ownership refusal:** verify that `LAB_SUBSCRIPTION`, `LAB_RESOURCE_GROUP`,
  and `LAB_CLUSTER` are the values used to create the lab. Never retag an
  unrelated group merely to bypass the guard.
- **Reused/shared cluster refusal:** run `--workloads`; persistent Azure metadata
  intentionally prevents `--all` from deleting a shared resource group.
- **Deletion remains in progress:** inspect `az group show` and the Azure
  Activity Log for locks or failed child-resource deletion.
- **Missing kubeconfig:** `--all` doesn't require cluster connectivity after the
  Azure ownership guards pass. The safer `--workloads` mode does require the
  configured AKS endpoint.

## Next step

Return to the [end-to-end AI codelab index](../../README.md), or rerun this lab
in another region or on another RDMA GPU SKU and compare the resulting metrics.
