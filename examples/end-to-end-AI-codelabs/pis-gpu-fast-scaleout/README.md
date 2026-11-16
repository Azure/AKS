# Faster GPU scale-out with Prepared Image Specification (PIS)

Bake the slow parts of a GPU node — the container image, the model weights, and
even a pinned GPU driver — into the node image **once** with Prepared Image
Specification (PIS), so every subsequent GPU node boots ready instead of
downloading gigabytes at scale-out.

Where the other GPU codelabs in this folder provision nodes and install drivers
at runtime, this one moves that work to **image-build time**. Each example is
self-contained and demonstrates one PIS capability on an NVIDIA H100 node pool.

## What you'll build

```mermaid
flowchart LR
    PIS["PIS resource\n(image + scripts)"] -->|attach to pool| BAKE[AKS builds a prepared VHD once]
    BAKE --> N1[GPU node 1]
    BAKE --> N2[GPU node 2]
    BAKE --> N3[GPU node N]
    N1 -.->|zero pull / zero download| READY[Ready in minutes]
    N2 -.-> READY
    N3 -.-> READY
```

## The three examples

| # | Example | What you bake | Why it matters |
|---|---|---|---|
| 1 | [Bake model weights](1-bake-model-weights.md) | A 15 GB Qwen2.5-7B checkpoint onto the node's local **NVMe** | The model is on local disk at boot — no Hugging Face download at scale-out |
| 2 | [Pre-cache a container image](2-precache-container-image.md) | The `vllm/vllm-openai` inference image | No image pull at scale-out — the slowest part of GPU pod startup |
| 3 | [Bake a custom GPU driver](3-custom-gpu-driver.md) | A pinned NVIDIA `595.91.07` driver | Pin an exact driver version that survives the AKS node bootstrap |

Do them in any order. If you're new to PIS, start with Example 2 — it's the
simplest and has no customization script.

## Time and cost

- **Time:** 45–60 minutes per example, most of it the one-time image bake
  (~25–40 minutes) plus GPU node boot.
- **Cost:** An H100 node pool is billed while it exists. Each example uses one
  `Standard_NC40ads_H100_v5` node (1× H100 NVL). PIS **re-bakes on every pool
  attach** (no cached VHD during preview), so each attach costs another bake.
- **Cleanup:** Run the cleanup section of each example, or delete the whole
  resource group at the end (see [below](#clean-up)).

## Prerequisites

- An AKS cluster on a supported Kubernetes version (validated on **1.35.6**).
- Azure CLI **≥ 2.85.0** and the **`aks-preview`** extension **≥ 21.0.0b5**.
- The **`AKSPreparedImageSpecificationPreview`** feature flag registered in your
  subscription (see [the shared setup](#one-time-setup)).
- **H100 quota *and* capacity** in your target region. Quota alone is not
  enough — check that the SKU is unrestricted (see
  [Capacity note](#capacity-note-read-before-you-pick-a-region)).
- `kubectl` and, for Example 3, Helm 3.

## One-time setup

These steps are shared by all three examples. Run them once.

```bash
# 1. Environment used throughout. Set SUB FIRST so the preview is registered in
#    the SAME subscription the cluster and PIS resources are created in.
export SUB=<your-subscription-id>
export RG=pis-gpu-codelab
export LOC=westeurope            # a region with H100 quota AND capacity
export ZONE=3
export CLUSTER=pis-gpu-codelab
export GPU_SKU=Standard_NC40ads_H100_v5

# 2. CLI + preview extension
az extension add --name aks-preview        # or: az extension update --name aks-preview
az --version                               # confirm az >= 2.85.0

# 3. Register the PIS preview feature in $SUB, then refresh the resource provider
az feature register --subscription $SUB --namespace Microsoft.ContainerService \
  --name AKSPreparedImageSpecificationPreview
# wait until "state" == "Registered":
az feature show --subscription $SUB --namespace Microsoft.ContainerService \
  --name AKSPreparedImageSpecificationPreview --query properties.state -o tsv
az provider register --subscription $SUB --namespace Microsoft.ContainerService

# 4. Resource group (tag it so a shared-sub janitor doesn't reap it mid-bake)
az group create -n $RG -l $LOC --subscription $SUB \
  --tags doNotDelete=true skipAutoDelete=true

# 5. Cluster with a CPU system pool
az aks create -g $RG -n $CLUSTER --subscription $SUB --location $LOC \
  --kubernetes-version 1.35.6 --node-count 2 --node-vm-size Standard_D4s_v5 \
  --nodepool-name system --network-plugin azure --generate-ssh-keys

az aks get-credentials -g $RG -n $CLUSTER --subscription $SUB --overwrite-existing
```

### The PIS read-permission grant (every example needs this)

Attaching a PIS to a node pool fails with `ResourceMissingPermissionError` unless
the **cluster identity** has **Reader** on the PIS resource. This is separate from
any bake identity. After you create a PIS (in each example), grant it:

```bash
CP_PRINCIPAL=$(az aks show -g $RG -n $CLUSTER --subscription $SUB \
  --query identity.principalId -o tsv)
PIS_ID=$(az aks prepared-image-specification show -g $RG --name <pis-name> \
  --subscription $SUB --query id -o tsv)
az role assignment create --assignee-object-id "$CP_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal --role Reader --scope "$PIS_ID"
```

## Capacity note (read before you pick a region)

GPU **quota is not capacity.** A region can show plenty of quota yet refuse to
allocate the SKU. Run a **restriction (eligibility) check** before you commit to
a ~30-minute bake:

```bash
az vm list-skus -l $LOC --subscription $SUB --size $GPU_SKU \
  --query "[0].{zones:locationInfo[0].zones, restrictions:restrictions}" -o json
```

- A `Zone`/`NotAvailableForSubscription` restriction covering every zone → you
  **cannot** allocate there, no matter how much quota you have. Pick another region.
- `restrictions: []` (empty) means the SKU is **eligible** in that zone — but this
  only reports eligibility, **not** guaranteed physical capacity. An unrestricted
  zone can still return `AllocationFailed` under contention. Treat an empty result
  as "worth trying," not a guarantee, and be ready to retry or fall back to another
  unrestricted zone/region (each pool attach re-runs the bake).

This codelab was validated in **`westeurope` zone 3**, which was unrestricted and
had capacity at the time.

## How PIS works (30-second version)

1. You create a **PIS resource** that lists container images to cache and/or
   customization scripts to run.
2. You attach a **PIS version** to a node pool. AKS spins up a temporary **build
   VM**, runs your scripts, caches your images, and snapshots a **prepared VHD**.
3. Every node in that pool — now and on every scale-out — boots from the prepared
   VHD, skipping the pull/download/install work.

PIS versions are **immutable**. To change an image or script, create a new
version and point the pool at it. Updating tags on the PIS resource does **not**
change a version's contents.

> **When is PIS worth it?** When a pool scales out **repeatedly**. The bake is a
> one-time front-loaded cost (~25–40 min); the payoff is every node that boots
> from the result. For a pool that never scales, the bake can cost more than it
> saves.

## Clean up

```bash
# removes the cluster, all GPU pools, PIS resources, and prepared images.
# Target $SUB explicitly so you don't rely on (or accidentally hit) a different
# CLI default subscription.
az group delete -n $RG --subscription $SUB --yes --no-wait
```

## Validation status

Every command and number in these examples was executed end-to-end on
`Standard_NC40ads_H100_v5` (1× H100 NVL 94 GB) in `westeurope` zone 3, AKS
Kubernetes 1.35.6, node image `AKSUbuntu-2404gen2containerd` /
kernel `6.8.0-1073-azure` / containerd 2.3.7, `aks-preview` with the PIS command
group. See each example's own **Validation status** section for its measured
timings.
