# Managed KubeRay and Kueue setup

Install the customer-visible `microsoft.kuberay` and `microsoft.kueue` extensions
through Azure. These managed extensions are the operator setup used throughout
all three example modules.

## Prerequisites

- An AKS cluster running Kubernetes 1.34 or later with **no self-installed Kueue
  or KubeRay controllers**. An existing healthy managed installation is acceptable.
  The installer rejects detected controller/CRD ownership conflicts; it doesn't
  replace or adopt another installation.
- Azure CLI 2.70 or later, `k8s-extension` 1.9.3 or later, compatible `kubectl`,
  Python 3.9 or later for preflight checks, Bash, and GNU `envsubst` (gettext)
  for workload submission. Windows users need a suitable Bash environment.
- Permissions to manage cluster extensions and retrieve cluster credentials.
  The storage steps additionally need resource-management and storage-scoped
  role-assignment permissions.
- Only for the CPU autoscaler demo: prepare its shared ProvisioningRequest `v1`
  API **before starting Kueue**, as described below. The default fixed-quota Ray
  queue path doesn't need a CPU autoscaler.
- For GPU examples, eligible user nodes with enough NVIDIA device-plugin GPUs,
  CPU, and memory for the selected workload. Follow the
  [AKS NVIDIA GPU guide](https://learn.microsoft.com/azure/aks/use-nvidia-gpu).
  Four A100 GPUs are required for the LLM training example. No GPU is needed for
  the CPU autoscaler demo.

Select the intended target explicitly:

```bash
export SUBSCRIPTION_ID="<subscription-id>"
export RESOURCE_GROUP="<resource-group>"
export CLUSTER_NAME="<existing-aks-cluster>"
```

### Optional CPU autoscaler prerequisites

Skip this subsection for the Ray-only path. For the CPU demo, enable autoscaling
on a suitable pool before installing Kueue. Its user pool starts with one
four-vCPU node, for example:

```bash
az aks nodepool add --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name scalepool --mode User --node-vm-size Standard_D4s_v6 \
  --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 5
```

Skip creation when the intended pool already exists. This command creates paid
capacity; review its size, limits, and existing workloads before changing a pool.
Pass `--with-cpu-autoscaling` to the installer to enforce this startup prerequisite.
It checks the shared API; it doesn't create the autoscaler, pool, or CRD. Don't
skip the check and assume that waiting for an admission check later dynamically
registers a controller that skipped setup at startup.

For GPU pools, `accelerator` is a protected AKS label key. Don't attempt to set it
in `az aks nodepool add --labels`. Verify the actual GPU labels and allocatable
resources. Prefer the managed ResourceFlavors when they meet your placement
requirements. Module 2 explains [managed flavor selection and optional custom policies](../../2-kueue-queues/#use-managed-ray-placement-flavors).

## Install and verify the managed operators

Sign in and register providers if needed; these commands don't change the CLI's
selected subscription:

```bash
az login
az provider register --subscription "$SUBSCRIPTION_ID" \
  --namespace Microsoft.ContainerService --wait
az provider register --subscription "$SUBSCRIPTION_ID" \
  --namespace Microsoft.KubernetesConfiguration --wait
az extension add --name k8s-extension --upgrade
```

From this directory:

```bash
export SUBSCRIPTION_ID RESOURCE_GROUP CLUSTER_NAME
./install-extensions.sh
# For the combined CPU demo instead: ./install-extensions.sh --with-cpu-autoscaling
source .managed/managed.env
```

The installer:

- Uses a private `.managed/kubeconfig` and doesn't overwrite `~/.kube/config`.
- Fails before installation if it finds an unmanaged controller or retained
  Kueue/Ray CRDs without their managed extension. It doesn't adopt ownership,
  remove finalizers, or perform an in-place migration.
- With `--with-cpu-autoscaling`, requires an established, served `v1`
  ProvisioningRequest API before manager startup. It never creates or replaces
  that shared CRD. The normal Ray path doesn't require it.
- Discovers compatible `preview` packages for the actual cluster and creates
  `aks-kueue` in `kueue-system` and `kuberay` in `kuberay-system`.
- Reuses a successfully provisioned managed instance instead of updating,
  deleting, or renaming it; verifies its expected controller ownership.
- Checks both Kueue deployments, KubeRay, and the core APIs. Module 2 separately
  verifies the managed flavor/check/config needed by the CPU demo.

If package discovery, provisioning, or readiness fails, preserve extension
status, events, and logs. A timeout doesn't cancel the Azure operation. Don't
layer Helm controllers, change protected settings, or uninstall/reinstall as a
health workaround. Customer configuration/protected-setting overrides aren't
supported by this example's managed installation.

`MANAGED_STATE_DIR` can select another private output directory.
`WAIT_TIMEOUT_SECONDS` bounds observation (default 1,200 seconds), not recovery.
The installer doesn't create an AKS cluster, allocate GPU capacity, configure
storage, or upload models/datasets.

## Prepare storage and workload identity

The following steps mirror the managed Learn workflow. Use an existing approved
storage/identity setup instead if it already satisfies this contract; don't
replace shared resources merely to match the example names.

- Namespace: `ray`.
- ServiceAccount: `ray-workload`.
- Federated credential subject: `system:serviceaccount:ray:ray-workload`.
- Private Blob containers: `aurora` and `llm-pipeline`.
- Workload identity role: Storage Blob Data Contributor, scoped to its storage
  account. The CLI uploader needs its own data-plane access separately.

Enable OIDC/workload identity if your cluster doesn't already have them:

```bash
az aks update --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" --enable-oidc-issuer --enable-workload-identity
```

Choose a globally unique storage account name. `STORAGE_LOCATION` can differ
from an AKS canary region if storage isn't offered there; choose a location
appropriate for your data residency and network requirements:

```bash
export AZURE_STORAGE_ACCOUNT_NAME="<unique-storage-account>"
WORKLOAD_IDENTITY_NAME="ray-workload-identity"
STORAGE_LOCATION="<storage-region>"

az storage account create --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$AZURE_STORAGE_ACCOUNT_NAME" \
  --location "$STORAGE_LOCATION" --sku Standard_LRS --kind StorageV2 \
  --allow-blob-public-access false --allow-shared-key-access false \
  --min-tls-version TLS1_2
```

Before creating containers, verify your signed-in identity has Storage Blob Data
Contributor at the account or a parent scope. An ARM Contributor role alone
isn't sufficient. See the
[role-assignment instructions](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access)
and allow for role propagation; don't fall back to account keys.

```bash
az storage container create --subscription "$SUBSCRIPTION_ID" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --name aurora --auth-mode login
az storage container create --subscription "$SUBSCRIPTION_ID" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --name llm-pipeline --auth-mode login

az identity create --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$WORKLOAD_IDENTITY_NAME" \
  --location "$STORAGE_LOCATION"

export IDENTITY_CLIENT_ID=$(az identity show --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$WORKLOAD_IDENTITY_NAME" \
  --query clientId --output tsv)
IDENTITY_PRINCIPAL_ID=$(az identity show --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$WORKLOAD_IDENTITY_NAME" \
  --query principalId --output tsv)
export TENANT_ID=$(az account show --subscription "$SUBSCRIPTION_ID" \
  --query tenantId --output tsv)
STORAGE_ID=$(az storage account show --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$AZURE_STORAGE_ACCOUNT_NAME" \
  --query id --output tsv)

az role assignment create --subscription "$SUBSCRIPTION_ID" \
  --assignee-object-id "$IDENTITY_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$STORAGE_ID"

ISSUER=$(az aks show --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
  --query oidcIssuerProfile.issuerUrl --output tsv)
az identity federated-credential create --subscription "$SUBSCRIPTION_ID" \
  --name ray-workload-federated --identity-name "$WORKLOAD_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" --issuer "$ISSUER" \
  --subject system:serviceaccount:ray:ray-workload \
  --audiences api://AzureADTokenExchange
```

Module 2 creates the namespace and service account with those identifiers. Its
annotations and the templates' `azure.workload.identity/use: "true"` pod labels
are required for storage authentication. Don't put account keys or tokens in
the environment files or manifests.

For the Learn guide's equivalent variable names:

```bash
export WORKLOAD_IDENTITY_CLIENT_ID="$IDENTITY_CLIENT_ID"
export AZURE_TENANT_ID="$TENANT_ID"
```

## Prepare datasets

The managed extensions don't upload application data. Follow
[dataset preparation](data.md), or use your existing compatible datasets.
The examples require the `aurora` input/truth NPZ pair and the ViGGO JSONL and
metadata files under `llm-pipeline/data/`.

## Continue to queues and workloads

From `examples/kueue-and-ray-on-aks/2-kueue-queues`, use the managed path to create
the Ray namespace/service account and choose **one** queue policy, starting with
[managed placement flavors](../../2-kueue-queues/#use-managed-ray-placement-flavors).
Then supply the account from this setup before sourcing each workload's defaults:

```bash
export AZURE_STORAGE_ACCOUNT_NAME
# In the selected 3-workloads/<example> directory:
source env.example
./submit.sh --dry-run
```

For online serving, use its `submit-service.sh` command instead. Rendering a
manifest or passing schema checks isn't evidence that training, inference, or
serving succeeded; observe admission, pod readiness, application output, and
stored results on your actual cluster.

## Cleanup

Delete the example RayJobs/RayService and their ConfigMaps before deleting the
customer-owned queues and namespace. Retain the managed defaults and shared
CRDs. Remove storage, federated credentials, role assignments, identities, or
node pools only if you created them for this example and no longer need them.
Keep a shared/pre-existing cluster intact.

The installer performs no automatic teardown. Planned extension removal is a
separate lifecycle operation: Kueue removal deletes queue/admission configuration,
whereas KubeRay removal retains Ray CRDs/resources. Follow the respective
managed-extension guide and preserve data first; never clear finalizers or
rewrite ownership to force removal.

## Offline safety tests

```bash
python3 -m unittest discover -s tests -v
bash -n install-extensions.sh
```

These tests don't contact Azure or Kubernetes. Real managed-extension and
workload validation is still required for your chosen package versions,
Kubernetes version, capacity, and access policy.
