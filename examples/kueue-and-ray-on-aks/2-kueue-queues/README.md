# Module 2 — Queues with managed Kueue

Use the **managed Kueue and KubeRay extensions** from
[Module 1](../1-infrastructure/managed/) for these examples. Kueue supplies batch
admission and generates ResourceFlavors for eligible user nodes. KubeRay manages
the Ray resources. You configure the namespace, identity, queues, and quota.

Prefer the managed scheduling resources when they meet your requirements.
Create customer-owned flavors only when you need a placement policy that the
managed flavors don't provide. Don't create replacements with managed `aks-*`
names or modify the generated defaults.

Choose one queue policy, not every manifest:

| Configuration | File | Purpose |
| --- | --- | --- |
| Managed Ray placement — recommended | `manifests/15-managed-queue.yaml.tmpl` | Reference existing managed CPU/GPU flavors in a fixed-quota queue. |
| Custom Ray placement — optional | `manifests/10-resource-flavors.yaml` plus `20-single-queue.yaml` or `30-team-queues.yaml` | Define a customer-owned placement/borrowing policy when managed flavors don't meet it. |
| CPU autoscale queue | `manifests/40-autoscale-queue.yaml` | Reference the managed CPU flavor/provisioning check for capacity before admission. |

## Prerequisites

- AKS 1.34 or later, Azure CLI 2.70 or later, and compatible `kubectl`.
- No self-installed Kueue or KubeRay controllers. Use the managed extensions;
  don't layer controllers or transfer ownership to make an installation fit.
- Permissions to manage extensions and the example Kubernetes resources.
- Capacity sized for the selected workload. Queue quota isn't physical capacity.
- For Ray workloads: Module 1's storage, datasets, and authorized workload identity.
  The federation subject must be `system:serviceaccount:ray:ray-workload`.
- Python with the [test dependency](tests/requirements.txt) and GNU `envsubst` for
  rendering the managed Ray queue template.

## Install and verify managed Kueue

Module 1 installs and verifies both managed operators. Keep those instances and
skip creation below if you completed it. These Kueue-only steps also support the
independent CPU demo, which needs no Ray, GPU, storage, or workload identity.

For CPU autoscaling, prepare its autoscaling pool and shared ProvisioningRequest
`v1` API **before Kueue starts**. See the [CPU prerequisites](../3-workloads/cas-batch-job/#prerequisites).
Waiting later doesn't register a controller that skipped startup setup. Don't
install a shared CRD or another controller as a workaround.

For the full lifecycle, see [Install managed Kueue on AKS](https://learn.microsoft.com/azure/aks/configure-queues-with-automatic-resource-flavors).
Run this section from `examples/kueue-and-ray-on-aks/2-kueue-queues`. It writes
one example-owned kubeconfig file, not an inherited file list. Select the target
explicitly:

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export RESOURCE_GROUP="<resource-group>"
export CLUSTER_NAME="<aks-cluster-name>"
EXTENSION_NAME="aks-kueue"
RELEASE_TRAIN="preview"

az login
az extension add --name k8s-extension --upgrade
az provider register --subscription "$SUBSCRIPTION_ID" \
  --namespace Microsoft.KubernetesConfiguration --wait
export KUBECONFIG="$PWD/.managed/kubeconfig"
umask 077
mkdir -p "$(dirname "$KUBECONFIG")"
az aks get-credentials --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
  --file "$KUBECONFIG" --overwrite-existing
```

Use `k8s-extension` 1.9.3 or later and check compatible packages:

```bash
az k8s-extension extension-types list-versions-by-cluster \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters --extension-type microsoft.kueue \
  --release-train "$RELEASE_TRAIN" --output table
```

If no compatible package is listed, stop. For a new installation only:

```bash
az k8s-extension create \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters --name "$EXTENSION_NAME" \
  --extension-type microsoft.kueue --scope cluster \
  --release-namespace kueue-system --release-train "$RELEASE_TRAIN" \
  --auto-upgrade-mode compatible
```

Verify Azure provisioning, both controllers, and the managed resources:

```bash
az k8s-extension show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters --name "$EXTENSION_NAME" \
  --query '{name:name,version:currentVersion,provisioningState:provisioningState,extensionState:extensionState,statuses:statuses}' \
  --output json
kubectl rollout status deployment/kueue-controller-manager --namespace kueue-system --timeout=5m
kubectl rollout status deployment/kueue-extension --namespace kueue-system --timeout=5m
kubectl get resourceflavors
kubectl get workloadpriorityclasses aks-low-priority aks-medium-priority aks-high-priority
```

If verification fails, inspect extension status, events, and logs. Don't repair
managed releases with another installation, replace shared CRDs, change protected
settings, or uninstall/reinstall as a health workaround.

## Choose a queue demo

Run the following commands from `examples/kueue-and-ray-on-aks/2-kueue-queues`.

### CPU autoscale queue

Add or verify the autoscaling `scalepool` with one starting node, following the
[CPU Job prerequisites](../3-workloads/cas-batch-job/#prerequisites). Verify the
CAS-owned API and managed defaults before applying the queue:

```bash
kubectl wait --for=condition=Established \
  crd/provisioningrequests.autoscaling.x-k8s.io --timeout=2m
kubectl wait --for=create resourceflavor/aks-cpu --timeout=5m
kubectl wait --for=condition=Active admissioncheck/aks-provisioning-check --timeout=2m
kubectl get provisioningrequestconfig aks-provisioning-config

kubectl apply -f manifests/40-autoscale-queue.yaml
kubectl wait --for=condition=Active clusterqueue/cas-cluster-queue --timeout=2m
kubectl wait --for=condition=Active localqueue/cas-local-queue \
  --namespace cas-kueue-demo --timeout=2m
```

This file owns only the demo namespace and queues. Its gate references existing
`aks-cpu`, `aks-provisioning-check`, and `aks-provisioning-config`; its provisioning
class is `best-effort-atomic-scale-up.autoscaling.x-k8s.io`. The Job's
`agentpool: scalepool` selector targets that pool. Continue with
[Submit the CPU Job](../3-workloads/cas-batch-job/#submit). Don't patch managed
defaults if a check fails.

### Prepare the Ray namespace and identity

Skip this section for the CPU demo. Complete Module 1 identity/federation setup,
then create the namespace and ServiceAccount:

```bash
kubectl apply -f manifests/00-namespace.yaml
IDENTITY_CLIENT_ID="${IDENTITY_CLIENT_ID:-<workload-identity-client-id>}"
TENANT_ID="${TENANT_ID:-<tenant-id>}"
kubectl create serviceaccount ray-workload --namespace ray \
  --dry-run=client --output yaml | kubectl apply -f -
kubectl annotate serviceaccount ray-workload --namespace ray --overwrite \
  "azure.workload.identity/client-id=$IDENTITY_CLIENT_ID" \
  "azure.workload.identity/tenant-id=$TENANT_ID"
```

These annotations don't create the Azure identity, role, federation, or datasets.
Supply the prepared storage account in each workload's environment.

### Use managed Ray placement flavors

Prefer existing AKS-managed flavors with the managed operators. Inspect what the
cluster generated and confirm their selectors match your actual CPU/GPU pools:

```bash
kubectl get resourceflavors
kubectl get nodes --show-labels
kubectl get nodes --output 'custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

The CPU flavor is `aks-cpu`; managed GPU flavor names depend on the cluster and
hardware. Don't invent a GPU flavor name. Inspect the selected objects with
`kubectl get resourceflavor <name> --output yaml`, including their node selectors
and topology, and verify allocatable GPU capacity first.

Set the existing flavor names and render the recommended queue policy:

```bash
export CPU_RESOURCE_FLAVOR="aks-cpu"
export GPU_RESOURCE_FLAVOR="<existing-managed-GPU-flavor>"
kubectl get resourceflavor "$CPU_RESOURCE_FLAVOR" "$GPU_RESOURCE_FLAVOR" &&
  envsubst '${CPU_RESOURCE_FLAVOR} ${GPU_RESOURCE_FLAVOR}' \
    < manifests/15-managed-queue.yaml.tmpl | kubectl apply -f -
kubectl wait --for=condition=Active clusterqueue/cluster-queue --timeout=2m
kubectl wait --for=condition=Active localqueue/default --namespace ray --timeout=2m
```

This template creates customer-owned queues, not ResourceFlavors. CPU, memory,
and GPU requests share a resource group so each PodSet uses one compatible
flavor. Don't combine the CPU-only managed flavor's selector with a GPU flavor's
selector for the same GPU worker. The example quotas allow CPU heads and an
eight-GPU pool; adjust all resource quotas for your capacity and workload policy.
Quota isn't a one-Job concurrency limit or a node-readiness guarantee.

### Optional custom placement and queue policies

Use this path only when the managed flavors don't meet your placement policy.
The optional file creates customer-owned `default` (no selector) and `gpu`
(`accelerator: nvidia`) flavors. The label is an AKS-provided selector to verify,
not a protected node label to set yourself. These examples use device-plugin
`nvidia.com/gpu` resources, not DRA.

```bash
kubectl apply -f manifests/10-resource-flavors.yaml
kubectl get resourceflavors default gpu
```

Choose **one** custom policy instead of the managed-flavor policy above:

```bash
# One fixed-quota queue:
kubectl apply -f manifests/20-single-queue.yaml
# OR team queues with borrowing/preemption:
# kubectl apply -f manifests/30-team-queues.yaml
```

The single policy admits every workload that fits its 96-CPU, 768-Gi memory,
and eight-GPU quota.
The team policy shares `shared-cohort`: each team has four nominal GPUs and can
borrow four idle GPUs. Size those quotas for physical capacity before use.

`withinClusterQueue: LowerPriority` allows higher-priority workloads to preempt
lower-priority ones in a team. Reference the managed `aks-low-priority`,
`aks-medium-priority`, or `aks-high-priority` classes through
`kueue.x-k8s.io/priority-class`. `reclaimWithinCohort: Any` lets a team reclaim
lent quota. Preemption stops a workload; it doesn't shrink a RayJob. Checkpoint
work that must resume safely.

## Clean up

Delete the workloads first. Use the [CPU cleanup guide](../3-workloads/cas-batch-job/#clean-up)
for that independent demo. For the recommended managed-flavor Ray policy, remove
only the queues you created:

```bash
kubectl delete localqueue default --namespace ray
kubectl delete clusterqueue cluster-queue
```

If you instead created a custom policy, delete its file (`20-single-queue.yaml`
or `30-team-queues.yaml`). Only after removing its queues, delete
`10-resource-flavors.yaml` if you created those custom flavors.

Keep managed `aks-*` flavors, priority classes, admission/provisioning defaults,
and shared CRDs. Delete the `ray` namespace only if it was dedicated to this demo
and no longer contains needed data. Planned extension removal is separate from
queue cleanup; don't force finalizers or rewrite ownership.

## Troubleshooting

| Symptom | Next action |
| --- | --- |
| A managed default is missing. | Verify eligible user nodes and both managed controllers. Don't recreate its managed name. |
| A ClusterQueue isn't active. | Inspect conditions, actual flavor references, namespace selection, and admission checks. |
| A Job stays suspended. | Check its LocalQueue, quota, priority, topology, and Workload conditions. |
| Pods stay Pending after admission. | Check node readiness, capacity, selectors, taints, and tolerations. |
| A controller isn't ready. | Inspect Azure extension status, controller events/logs, and the managed support path. |

```bash
kubectl get deployments,pods --namespace kueue-system
kubectl logs deployment/kueue-controller-manager --namespace kueue-system --tail=200
kubectl logs deployment/kueue-extension --namespace kueue-system --tail=200
```

## Validate the example offline

From this module, run the contracts before live submission:

```bash
python3 -m pip install -r tests/requirements.txt
python3 -m unittest discover -s tests -v
```

These check files and ownership/routing references, not live extension or model
execution. Verify live readiness and application outputs separately.

## Next steps

- [Run the CPU autoscaler demo](../3-workloads/cas-batch-job/).
- [Submit Ray workloads](../3-workloads/) after their storage/identity/data checks.
