# Module 2 — Queues with managed Kueue

Use the AKS managed Kueue extension to control workload admission. The extension
manages the Kueue controller, generates ResourceFlavors for eligible user nodes,
and supplies default workload priority classes and a provisioning admission check.
You own the ClusterQueues, LocalQueues, and workload policies in this module.

For Ray workloads, start with [Module 1's managed setup](../1-infrastructure/managed/),
which installs **both managed KubeRay and Kueue** and documents storage, identity,
and datasets. If those extensions are already installed, keep them and skip
creation below. The independent CPU demo can use the Kueue-only steps here.

Choose one of these independent demos:

| Configuration | File | Purpose |
| --- | --- | --- |
| Single Ray queue | `manifests/20-single-queue.yaml` | Admit Ray workloads against a fixed quota. Workloads wait when they don't fit. |
| Team Ray queues | `manifests/30-team-queues.yaml` | Share a cohort with borrowing and priority-based preemption. |
| CPU autoscale queue | `manifests/40-autoscale-queue.yaml` | Reference the managed flavor and provisioning check so the cluster autoscaler provisions capacity before admission. |

The CPU autoscale demo doesn't require Ray, a GPU, storage, or workload identity.
The Ray demos keep the customer-owned `default` and `gpu` flavors to preserve their
existing resource-group and placement policy. Those names aren't AKS-managed
resources; don't replace or edit generated `aks-*` resources to run these demos.

## Prerequisites

- An AKS cluster running Kubernetes 1.34 or later, Azure CLI 2.70 or later, and
  `kubectl` compatible with the cluster.
- Permissions to manage cluster extensions and the example Kubernetes resources.
- An eligible CPU user node pool for the CPU demo, or NVIDIA GPU capacity sized
  for the Ray demo that you choose.
- For Ray workloads only: managed KubeRay, the required datasets and Blob storage,
  and a workload identity authorized to access that storage. Its federated credential
  must trust `system:serviceaccount:ray:ray-workload`. See the
  [AKS workload identity deployment guide](https://learn.microsoft.com/azure/aks/workload-identity-deploy-cluster).

> [!IMPORTANT]
> Don't run the [legacy Module 1 Terraform lab](../1-infrastructure/terraform/legacy-guide.md)
> to prepare a managed Kueue cluster. That alternative installs Kueue through Helm. Never
> install that controller alongside the managed extension. This module doesn't
> perform an in-place migration. Before uninstalling any existing self-hosted
> Kueue, preserve queue and workload manifests, review running and queued work,
> preserve application data, and pause GitOps reconciliation. Follow the supported
> uninstall procedure for that installation, or use a clean target cluster.

## Install and verify managed Kueue

For the CPU autoscaler demo, prepare its autoscaling pool and shared
ProvisioningRequest `v1` API **before Kueue starts**. See the
[CPU prerequisites](../3-workloads/cas-batch-job/#prerequisites). Waiting for an
admission check doesn't dynamically register a controller that skipped setup at
startup; don't install a shared CRD or another controller as a workaround.

For the complete lifecycle and supported configuration, see
[Install managed Kueue on AKS](https://learn.microsoft.com/azure/aks/configure-queues-with-automatic-resource-flavors).

Set your target cluster and preferred extension instance name:

```bash
SUBSCRIPTION_ID="<subscription-id>"
RESOURCE_GROUP="<resource-group>"
CLUSTER_NAME="<aks-cluster-name>"
EXTENSION_NAME="aks-kueue"
RELEASE_TRAIN="preview"

az login
az account set --subscription "$SUBSCRIPTION_ID"
az extension add --name k8s-extension --upgrade
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

Use `k8s-extension` version 1.9.3 or later. Check package availability for the
cluster before you install:

```bash
az k8s-extension extension-types list-versions-by-cluster \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --extension-type microsoft.kueue \
  --release-train "$RELEASE_TRAIN" \
  --output table
```

If no compatible version is listed, stop and check the prerequisites and release
availability. If the extension is already installed, use its actual resource name
and skip creation. Otherwise, install it in the required namespace:

```bash
az k8s-extension create \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$EXTENSION_NAME" \
  --extension-type microsoft.kueue \
  --scope cluster \
  --release-namespace kueue-system \
  --release-train "$RELEASE_TRAIN" \
  --auto-upgrade-mode compatible
```

Verify Azure provisioning and both controllers:

```bash
az k8s-extension show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$EXTENSION_NAME" \
  --query '{name:name,version:currentVersion,provisioningState:provisioningState,extensionState:extensionState,statuses:statuses}' \
  --output json

kubectl rollout status deployment/kueue-controller-manager --namespace kueue-system --timeout=5m
kubectl rollout status deployment/kueue-extension --namespace kueue-system --timeout=5m
kubectl get resourceflavors
kubectl get workloadpriorityclasses aks-low-priority aks-medium-priority aks-high-priority
```

If verification fails, inspect extension status, events, and controller logs.
Don't use Helm to repair the managed release, apply arbitrary upstream CRDs, or
uninstall the extension as a health workaround. Customer-supplied feature-gate or
controller-configuration overrides aren't supported.

## Choose a queue demo

All following commands run from `examples/kueue-and-ray-on-aks/2-kueue-queues`.
Apply only the configuration you intend to use, not every file in `manifests/`.

### CPU autoscale queue

First add or verify an autoscaling CPU user pool named `scalepool`, initially with
one node. Follow the [CPU batch Job prerequisites](../3-workloads/cas-batch-job/#prerequisites).
The cluster autoscaler provides the shared ProvisioningRequest API. Verify it and
the managed defaults before applying your queue:

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

This file creates only the example namespace and customer-owned queues. Its
ClusterQueue references `aks-cpu` and gates admission on `aks-provisioning-check`,
which uses `aks-provisioning-config` and the
`best-effort-atomic-scale-up.autoscaling.x-k8s.io` provisioning class. The example
Job's `agentpool: scalepool` node selector targets that pool even though `aks-cpu`
can cover multiple CPU user pools.

Continue with [Submit the CPU batch Job](../3-workloads/cas-batch-job/#submit).
Don't create or patch the managed defaults if a readiness check fails.

### Prepare the Ray namespace and identity

Skip this section for the CPU autoscale demo. On a managed cluster, prepare the
namespace and ServiceAccount for your existing, authorized workload identity:

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

These annotations don't create the Azure identity, federated credential, storage,
role assignments, or datasets. Complete those prerequisites before submitting Ray
workloads. Set the Module 3 environment variables, including the storage account,
from your own provisioned resources rather than Terraform outputs.

Create the **customer-owned** Ray placement flavors:

```bash
kubectl apply -f manifests/10-resource-flavors.yaml
kubectl get resourceflavors default gpu
```

`default` has no node selector. `gpu` matches `accelerator: nvidia`. These demos
use the NVIDIA device-plugin resource `nvidia.com/gpu`, not DRA. Inspect node
labels and GPU resources before selecting quotas:

```bash
kubectl get nodes --show-labels
kubectl get nodes --output 'custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

### Single Ray queue

Apply this option for a fixed-quota queue:

```bash
kubectl apply -f manifests/20-single-queue.yaml
kubectl wait --for=condition=Active clusterqueue/cluster-queue --timeout=2m
kubectl wait --for=condition=Active localqueue/default --namespace ray --timeout=2m
```

The defaults are 96 CPUs, 768 Gi of memory, and eight GPUs. Adjust them to your
capacity and workload policy. Kueue admits every workload that fits the available
quota; this configuration doesn't guarantee that only one Job runs at a time.
CPU and memory are charged for the Ray head **and** workers.

### Team Ray queues

Use this option instead of the single queue:

```bash
kubectl apply -f manifests/30-team-queues.yaml
kubectl wait --for=condition=Active clusterqueue/team-a-cq clusterqueue/team-b-cq --timeout=2m
kubectl wait --for=condition=Active localqueue/team-a localqueue/team-b --namespace ray --timeout=2m
```

The queues share `shared-cohort`. Each team has nominal quota for four GPUs and
can borrow four idle GPUs from the other team. This configuration requires enough
GPU capacity; don't use the default quota on a single-GPU cluster.

`withinClusterQueue: LowerPriority` permits a higher-priority workload to preempt
one of lower priority within a team. Use the managed `aks-low-priority`,
`aks-medium-priority`, or `aks-high-priority` classes through a workload's
`kueue.x-k8s.io/priority-class` label. `reclaimWithinCohort: Any` permits a team to
reclaim its lent quota. Preemption stops a workload; it doesn't shrink an
eight-GPU RayJob into a four-GPU Job. Checkpoint work that must resume safely.

## Self-managed Terraform alternative

If you deliberately use the existing Module 1 Terraform path, keep its Helm-owned
controller and **skip the managed installation section**. It isn't a supported
way to install the managed extension. The single and team Ray queue files can
still be used with that self-managed controller. The CPU autoscale manifest now
requires the managed defaults and isn't part of that alternative.

For that Terraform path only, use its ServiceAccount output instead of the manual
identity setup above, from this module's root:

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f <(terraform -chdir=../1-infrastructure/terraform output -raw ray_workload_sa_yaml)
```

## Clean up

Delete the example workloads first so Kueue can release their quota. Follow the
[CPU Job cleanup](../3-workloads/cas-batch-job/#clean-up) for the autoscale demo.
For a Ray demo, delete the **one queue configuration you applied**. For example:

```bash
kubectl delete -f manifests/20-single-queue.yaml
kubectl delete -f manifests/10-resource-flavors.yaml
```

Don't delete the managed `aks-*` flavors, priority classes, admission check,
provisioning config, or shared CRDs. Deleting the `ray` namespace also deletes its
workloads, LocalQueues, and ServiceAccount; do so only if it was dedicated to this
demo and you no longer need its contents. Uninstalling the managed extension is a
separate destructive lifecycle operation, not part of queue cleanup.

## Troubleshooting

| Symptom | Next action |
| --- | --- |
| A managed default is missing. | Verify eligible user nodes and both managed controllers. Don't create a replacement with the managed name. |
| A ClusterQueue isn't active. | Inspect its conditions, flavor references, and admission-check status. |
| A Job stays suspended. | Check its LocalQueue label, quota, priority, and Workload admission conditions. |
| Pods are pending after admission. | Check physical capacity, node labels, taints, tolerations, and workload placement constraints. |
| A controller isn't ready. | Inspect Azure extension status and both controllers' events and logs; use the managed extension support path. |

```bash
kubectl get deployments,pods --namespace kueue-system
kubectl logs deployment/kueue-controller-manager --namespace kueue-system --tail=200
kubectl logs deployment/kueue-extension --namespace kueue-system --tail=200
```

## Validate the example offline

From this module's root, use a Python virtual environment with the test dependency
and run the manifest contract tests:

```bash
python3 -m pip install -r tests/requirements.txt
python3 -m unittest discover -s tests -v
```

These tests check ownership, managed references, queue routing, and the target
pool selector. They don't prove extension availability or live autoscaler behavior.

## Next steps

- [Run the CPU autoscaler demo](../3-workloads/cas-batch-job/).
- [Submit Ray workloads](../3-workloads/) after preparing their storage and identity dependencies.
