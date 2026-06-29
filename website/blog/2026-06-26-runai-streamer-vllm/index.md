---
title: "Stream vLLM Model Weights from Azure Blob Storage on AKS"
date: 2026-06-26
description: "Streaming LLM weights from Azure Blob Storage with the RunAI Model Streamer and workload identity"
authors: [suraj-deshmukh, hariharan-sethuraman]
tags: ["ai-inference", "gpu", "storage", "workload-identity"]
---

When you autoscale LLM inference, cold-start time is dominated by one thing: getting tens of gigabytes of model weights off storage and into GPU memory. The naive path involves downloading all the model weights to local disk, then loading them into the GPU. This serializes two slow copies back to back and leaves the network idle while the GPU waits.

The [RunAI Model Streamer](https://github.com/run-ai/runai-model-streamer) collapses that into a single streaming step: it reads tensors concurrently from object storage and feeds them into GPU memory as they arrive, saturating the available bandwidth instead of staging everything on disk first. vLLM wires it in behind `--load-format runai_streamer`.

The streamer has natively supported AWS S3 and GCS for a while, but Azure Blob Storage was just added to the mix. **Since vLLM v0.18.0 ([vllm-project/vllm#34614](https://github.com/vllm-project/vllm/pull/34614)) and runai-model-streamer v0.15.6 ([run-ai/runai-model-streamer#116](https://github.com/run-ai/runai-model-streamer/pull/116)), the `az://` scheme is supported out of the box.** A stock `vllm/vllm-openai` image can stream from Blob with nothing more than an environment variable and a workload-identity binding.

<!-- truncate -->

This post walks the whole thing end to end on AKS:

1. An AKS cluster with OIDC + workload identity, and a **fully managed** A100 GPU node pool (AKS installs and maintains the NVIDIA driver, device plugin, and DCGM exporter — no need to install the NVIDIA GPU operator).
2. A premium block-blob storage account to hold the weights.
3. Workload identity that lets pods read and write Blob with a Microsoft Entra ID token instead of a storage key.
4. An **in-cluster upload Job** that pulls `microsoft/phi-4` from HuggingFace and pushes it to Blob — running inside Azure, so it uses Azure's backbone bandwidth rather than your home uplink. Such jobs need to be run once per model.
5. A vLLM Deployment that streams those weights straight from `az://` at startup.

> **Why upload from a Job instead of your laptop?** Multi-gigabyte model weights uploaded from a workstation are gated by your upstream bandwidth and can take hours. A Job in the same region as the storage account moves the same bytes over Azure's network in minutes, and it authenticates with workload identity so there are no keys to copy around.

---

## Why stream instead of download-then-load?

The default way vLLM loads a model is a two-step relay: download all the model weights from the source (HuggingFace Hub or object storage) onto the node's local disk, then read them back off disk to load them into GPU memory. The RunAI streamer replaces both halves with a single concurrent stream from object storage straight into GPU memory.

```mermaid
flowchart TB
    subgraph naive["Default: download-then-load"]
        NS["Object storage<br/>(HF Hub / Blob)"]
        ND["Local disk"]
        NG["GPU memory"]

        NS -->|"1. copy all model weights<br/>to disk (GPU idle)"| ND
        ND -->|"2. read back from disk<br/>into GPU (network idle)"| NG
    end

    subgraph stream["RunAI streamer: stream straight to GPU"]
        SS["Object storage<br/>(Blob, az://)"]
        SG["GPU memory"]

        SS -->|"concurrent reads,<br/>no disk staging"| SG
    end
```

Three things make the default path slow, and the streamer fixes each one:

- **Two serial passes instead of one.** With download-then-load, *nothing* reaches the GPU until the last byte has landed on disk. The GPU sits idle through the entire download, and the network sits idle through the entire disk-to-GPU load — the two slow copies never overlap. The streamer pipelines them: a tensor is loading onto the GPU while the next ones are still in flight from storage.
- **A wasted round-trip through disk.** Staging to disk writes tens of gigabytes and immediately reads them back — a second full pass over the data that exists only to bridge the two steps. Even on fast local NVMe that's pure overhead; on network-attached or smaller disks it's worse, and large model weights can fill the disk outright. Streaming never touches disk.
- **No concurrency.** A plain download and a plain disk read each tend to move data in a single stream, leaving bandwidth unused. The streamer issues many parallel reads against object storage and feeds the GPU concurrently, keeping the link saturated — which is exactly why the premium block-blob account in step 2 is worth it.

The net effect: cold-start time drops from *download time + disk-load time* (added together) to roughly *the streaming time alone* (overlapped), with the disk write-and-read-back eliminated entirely. That's what makes this approach worthwhile when you're autoscaling replicas and every cold start is on the critical path. With those bottlenecks removed, cold starts become significantly faster and cheaper. Let's build the infrastructure to prove it.

---

## Prerequisites

- The [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`), version 2.85.0 or later.
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) and [`jq`](https://jqlang.github.io/jq/).
- An Azure subscription with quota for an NVIDIA GPU VM (For example: `Standard_NC24ads_A100_v4`) in your target region.
- Logged in: `az login` and `az account set --subscription <id>`.

---

## Configuration

Everything below is driven by these variables. Export them once in your shell and the rest of the commands are copy-paste.

```bash
# --- Azure / cluster ---
export AZURE_RESOURCE_GROUP="runai-suraj"
export AZURE_REGION="southcentralus"
export CLUSTER_NAME="llm"
export ADMIN_USERNAME="azuser"

# --- GPU node pool ---
export NODE_POOL_NAME="gpunodes"
export NODE_POOL_VM_SIZE="Standard_NC24ads_A100_v4"
export NODE_POOL_NODE_COUNT=1

# --- Storage ---
# Must be globally unique, 3-24 chars, lowercase letters and digits only.
export STORAGE_ACCOUNT_NAME="llmmodelsrunaisuraj1"
export STORAGE_CONTAINER_NAME="models"

# --- Workload identity ---
export IDENTITY_NAME="vllm-model-reader"
export SERVICE_ACCOUNT_NAME="default"
export NAMESPACE="default"

# --- Model / vLLM ---
export MODEL_NAME="microsoft/phi-4"
export VLLM_IMAGE="vllm/vllm-openai:v0.23.0"
```

---

## 1. Deploy the AKS cluster

### 1a. Enable the managed GPU preview

The fully managed GPU node-pool experience is a preview feature. Register it once per subscription. This is what lets us skip the NVIDIA GPU operator entirely — AKS takes over installing and maintaining the driver, the NVIDIA GPU device plugin, and the NVIDIA DCGM metrics exporter on every GPU node.

```bash
# The managed-GPU flag lives in the aks-preview extension (>= 19.0.0b29).
az extension add --name aks-preview
az extension update --name aks-preview

# Register the feature flag.
az feature register \
    --namespace Microsoft.ContainerService \
    --name ManagedGPUExperiencePreview

# Registration is asynchronous — poll until it flips to "Registered"
# (this can take a few minutes). Skipping this wait makes the node-pool
# command in step 1c fail while the feature is still "Registering".
until [ "$(az feature show \
    --namespace Microsoft.ContainerService \
    --name ManagedGPUExperiencePreview \
    --query properties.state -o tsv)" = "Registered" ]; do
    echo "Waiting for ManagedGPUExperiencePreview to register..."
    sleep 15
done

# Propagate the newly registered feature to the resource provider.
az provider register --namespace Microsoft.ContainerService
```

### 1b. Create the resource group and cluster

The cluster needs three things switched on for workload identity to work later: `--enable-oidc-issuer` (so Kubernetes service-account tokens can be validated by Microsoft Entra ID), `--enable-workload-identity` (installs the mutating webhook that injects federated-token env vars into labeled pods), and `--enable-managed-identity`.

```bash
az group create \
    --name "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}"

az aks create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --location "${AZURE_REGION}" \
    --node-count 1 \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --enable-managed-identity \
    --generate-ssh-keys \
    --admin-username "${ADMIN_USERNAME}" \
    --os-sku Ubuntu

az aks get-credentials \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --overwrite-existing
```

The default node pool created here is a small CPU pool that runs system
components. GPU capacity comes from a dedicated pool in the next step.

### 1c. Add the managed A100 GPU node pool

This single flag — `--enable-managed-gpu=true` — is the whole reason we don't need a GPU operator. AKS provisions the node with the NVIDIA driver already installed, deploys the NVIDIA GPU device plugin so `nvidia.com/gpu` is advertised, and wires up the NVIDIA DCGM exporter for metrics.

```bash
az aks nodepool add \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${NODE_POOL_NAME}" \
    --node-count "${NODE_POOL_NODE_COUNT}" \
    --node-vm-size "${NODE_POOL_VM_SIZE}" \
    --enable-managed-gpu=true
```

Confirm the GPU is schedulable before moving on. It can take a couple of minutes after the pool is ready for the device plugin to advertise the resource:

```bash
kubectl get nodes -o json \
    | jq -r '.items[] | {name: .metadata.name, gpu: .status.allocatable["nvidia.com/gpu"]}'
```

You're looking for a node reporting `"gpu": "1"`.

---

## 2. Create a premium block-blob storage account

Premium block blob (`Premium_LRS` + `BlockBlobStorage`) gives the streamer the high, consistent throughput that makes this whole approach worthwhile. A standard account works too, but you'll leave bandwidth on the table.

```bash
az storage account create \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}" \
    --sku Premium_LRS \
    --kind BlockBlobStorage

az storage container create \
    --name "${STORAGE_CONTAINER_NAME}" \
    --account-name "${STORAGE_ACCOUNT_NAME}"
```

---

## 3. Set up workload identity for Blob access

This is the part that lets pods talk to Blob with **zero secrets**. The chain looks like this:

```mermaid
flowchart TD
    Pod["Pod<br/>(default SA, labeled)"]
    FC["Federated credential<br/>(trusts the cluster's OIDC issuer for this SA)"]
    MI["User-assigned managed identity"]
    Role["Storage Blob Data Contributor"]
    Blob["Azure Blob Storage"]

    Pod -->|projected SA token| FC
    FC --> MI
    MI -->|has role| Role
    MI --> Blob
```

We use **Storage Blob Data Contributor** (not just Reader) on purpose: the same identity is reused by both the upload Job (which needs to *write*) and the vLLM pod (which only *reads*).

> **You need permission to create role assignments.** The `az role assignment create` step below writes to `Microsoft.Authorization/roleAssignments`, which requires an elevated role on the scope — **Owner**, **User Access Administrator**, or **Role Based Access Control Administrator**. Plain Contributor isn't enough. Without it you'll see:
>
> ```text
> (AuthorizationFailed) The client 'you@example.com' with object id '...' does not
> have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'
> over scope '/subscriptions/.../storageAccounts/<account>/providers/Microsoft.Authorization/roleAssignments/...'
> ```
>
> If you hit this, ask a subscription/resource-group administrator to either grant you one of those roles or run the role-assignment command for you. The rest of the setup is unaffected.

```bash
# The cluster's OIDC issuer URL — the trust anchor for federated credentials.
export AKS_OIDC_ISSUER=$(az aks show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create a user-assigned managed identity.
az identity create \
    --name "${IDENTITY_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_REGION}"

export IDENTITY_CLIENT_ID=$(az identity show \
    --name "${IDENTITY_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query clientId -o tsv)

export IDENTITY_OBJECT_ID=$(az identity show \
    --name "${IDENTITY_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query principalId -o tsv)

export STORAGE_ACCOUNT_ID=$(az storage account show \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query id -o tsv)

# Grant the identity read/write on the storage account.
az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee-object-id "${IDENTITY_OBJECT_ID}" \
    --assignee-principal-type ServicePrincipal \
    --scope "${STORAGE_ACCOUNT_ID}"

# Federate the Kubernetes service account to the managed identity.
az identity federated-credential create \
    --name "vllm-federated-cred" \
    --identity-name "${IDENTITY_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --issuer "${AKS_OIDC_ISSUER}" \
    --subject "system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}" \
    --audience api://AzureADTokenExchange

# Tell the workload-identity webhook which identity this SA maps to,
# and opt the SA into token injection. --overwrite keeps both commands
# idempotent so re-running this section after a partial attempt succeeds.
kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    -n "${NAMESPACE}" --overwrite \
    azure.workload.identity/client-id="${IDENTITY_CLIENT_ID}"

kubectl label serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    -n "${NAMESPACE}" --overwrite \
    azure.workload.identity/use="true"
```

These two commands play different roles, and it's worth being precise about which is which. The **annotation** on the service account tells the webhook *which* managed identity to mint tokens for. The **label** is what actually triggers injection — but the webhook keys off the label on the **pod**, not the service account. Labeling the service account here is just a convenience: it makes new pods inherit the label by default in some setups, but the authoritative switch is the `azure.workload.identity/use: "true"` label in each pod template (you'll see it on both the Job and the Deployment below). A pod that runs as this service account but is missing that label gets **no** token injected — and fails to authenticate to Blob with no obvious error. So from here on, every workload that needs Blob access carries `azure.workload.identity/use: "true"` on its **pod template**, which earns it `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and a projected federated token automatically.

> **Give the role assignment a couple of minutes to propagate.** Azure RBAC role assignments are eventually consistent. If the upload Job in the next step starts too soon, it fails with `AuthorizationPermissionMismatch`. If you hit that, wait a couple of minutes (`sleep 120`) and let the Job's `backoffLimit` retry. To re-run the Job from scratch, delete it first — a `Job` is immutable, so a second `kubectl apply` fails with `AlreadyExists`:
>
> ```bash
> kubectl delete job upload-model --ignore-not-found
> ```

---

## 4. Upload the model weights from a Kubernetes Job

The Job does three things: pull `microsoft/phi-4` from HuggingFace, install `azcopy`, and copy the files into Blob using workload identity (`AZCOPY_AUTO_LOGIN_TYPE=WORKLOAD`). Because it runs in-cluster, the HuggingFace → Blob transfer rides Azure's network, not yours.

A few details worth calling out:

- The pod template carries the `azure.workload.identity/use: "true"` label, so `azcopy` finds the federated token automatically.
- `--overwrite=ifSourceNewer` makes retries cheap: a re-run skips blobs that already uploaded successfully instead of re-sending all the model weights.
- `--exclude-path '.cache'` skips HuggingFace's local cache directory.

> **A subtlety worth understanding: scoped `envsubst`.** The manifest is rendered with `envsubst` so the apply-time config (namespace, account, container, model) gets baked in. But the container script *also* contains shell variables that must survive untouched until the container runs — `$AZURE_STORAGE_ACCOUNT_NAME` and `$AZURE_STORAGE_CONTAINER_NAME` (injected via the pod's `env:` block) and the retry-loop counters `$attempt` / `$max_retries`. A bare `envsubst` would happily blank all of those out (they aren't set in your shell), leaving a broken `https://.blob.core.windows.net//...` URL and a retry loop comparing empty strings. Passing `envsubst` an explicit allow-list — `envsubst '${NAMESPACE} ${STORAGE_ACCOUNT_NAME} ${STORAGE_CONTAINER_NAME} ${MODEL_NAME}'` — substitutes only those four and leaves the runtime variables alone.

```yaml
cat <<'JOBEOF' | envsubst '${NAMESPACE} ${STORAGE_ACCOUNT_NAME} ${STORAGE_CONTAINER_NAME} ${MODEL_NAME}' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: upload-model
  namespace: ${NAMESPACE}
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      restartPolicy: Never
      volumes:
      # Scratch space for the downloaded model weights. Backing it with an
      # emptyDir (plus the ephemeral-storage requests below) makes the
      # scheduler reserve disk for the model up front, instead of letting a
      # large download fill the node and trigger a DiskPressure eviction.
      - name: model-scratch
        emptyDir:
          sizeLimit: 60Gi
      containers:
      - name: uploader
        image: python:3.12-slim
        command:
        - bash
        - -exc
        - |
          set -euo pipefail

          # Install the HuggingFace CLI. Pin huggingface-hub so the `hf`
          # command is guaranteed present (the CLI was renamed from
          # `huggingface-cli` to `hf` in huggingface-hub v0.34).
          pip install 'huggingface-hub>=0.34'

          # Install azcopy.
          apt-get update && apt-get install -y curl
          cd /tmp && curl -sL https://aka.ms/downloadazcopy-v10-linux | tar xz --strip-components=1
          mv /tmp/azcopy /usr/local/bin/

          # Download the model from HuggingFace.
          hf download "${MODEL_NAME}" --local-dir /tmp/model

          # Authenticate with workload identity.
          export AZCOPY_AUTO_LOGIN_TYPE=WORKLOAD

          # Upload to Blob (skip .cache, parallel chunked upload).
          # --overwrite=ifSourceNewer means a retry skips already-uploaded blobs
          # instead of re-sending the entire model.
          max_retries=5
          attempt=1
          until azcopy copy '/tmp/model/*' \
              "https://${AZURE_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER_NAME}/${MODEL_NAME}/" \
              --recursive \
              --exclude-path '.cache' \
              --overwrite=ifSourceNewer \
              --log-level WARNING; do
            if [ "$attempt" -ge "$max_retries" ]; then
              echo "Upload failed after ${max_retries} attempts"
              exit 1
            fi
            echo "Upload attempt ${attempt} failed, retrying in 30s..."
            sleep 30
            attempt=$((attempt + 1))
          done
        env:
        - name: AZURE_STORAGE_ACCOUNT_NAME
          value: "${STORAGE_ACCOUNT_NAME}"
        - name: AZURE_STORAGE_CONTAINER_NAME
          value: "${STORAGE_CONTAINER_NAME}"
        - name: MODEL_NAME
          value: "${MODEL_NAME}"
        volumeMounts:
        - name: model-scratch
          mountPath: /tmp/model
        resources:
          requests:
            memory: "4Gi"
            # Reserve disk for the model weights so the scheduler places the pod
            # on a node with room. Size this above your largest model; phi-4
            # is ~29 GB on disk, so 50 GB leaves headroom.
            ephemeral-storage: "50Gi"
          limits:
            memory: "8Gi"
            ephemeral-storage: "60Gi"
JOBEOF
```

Wait for it to finish and check the logs:

```bash
kubectl wait --for=condition=complete job/upload-model --timeout=1800s
```

**A note on scaling to larger models:** The 1800s (30 minute) timeout is plenty for a ~14 GB model like `microsoft/phi-4`. If you reuse this manifest for a 70B+ parameter model, two limits need raising together: bump this `--timeout` so the command doesn't give up while the Job is still uploading, **and** raise the `ephemeral-storage` request/limit on the Job — larger model weights that overflow the reserved scratch space get evicted with `DiskPressure` long before any timeout fires.

In a separate terminal you can follow the logs:

```bash
kubectl logs -f job/upload-model
```

Verify the blobs landed:

```bash
az storage blob list \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --container-name "${STORAGE_CONTAINER_NAME}" \
    --prefix "${MODEL_NAME}" \
    --output table
```

---

## 5. Deploy vLLM streaming from Azure Blob

Now the payoff. Two things turn on Blob streaming:

- `--load-format runai_streamer` selects the RunAI Model Streamer loader.
- `--model az://${STORAGE_CONTAINER_NAME}/${MODEL_NAME}` points at the blobs using the native `az://` scheme. The `AZURE_STORAGE_ACCOUNT_NAME` env var tells the streamer which account to read from, and the pod's workload-identity label handles auth — no keys, no connection strings.

> **Tuning the streamer.** The RunAI Model Streamer exposes [tunable parameters](https://docs.vllm.ai/en/latest/models/extensions/runai_model_streamer/#tunable-parameters) that you pass to vLLM as a JSON object via `--model-loader-extra-config`. A few worth knowing:
>
> - `'{"distributed":true}'` enables distributed streaming across tensor-parallel ranks (CUDA and ROCm only) — useful once you scale `--tensor-parallel-size` past 1.
> - `'{"concurrency":16}'` sets how many OS threads read tensors from storage into the CPU buffer; raise it to push more bandwidth against a premium account.
> - `'{"memory_limit":5368709120}'` caps the CPU staging buffer (in bytes).
>
> To set one, add the flag to the `args` list below, for example:
>
> ```yaml
>         - --model-loader-extra-config
>         - '{"concurrency":16}'
> ```

The pod mounts an in-memory `emptyDir` at `/dev/shm` because vLLM uses shared memory for inter-process communication.

A `startupProbe` and `readinessProbe` against vLLM's `/health` endpoint keep the pod out of the Service's endpoints until the model has finished streaming from Blob and the server is actually answering requests. Without them the pod is marked ready the instant the container starts — minutes before it can serve — so a Service or rollout would route traffic to a model that isn't loaded yet.

> This manifest uses an unquoted heredoc (`<<EOF`), so your shell expands the variables directly — every `${...}` here is set in your shell, and there are no runtime-only variables to protect, so the `envsubst` dance from step 4 isn't needed.

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phi-4
  namespace: ${NAMESPACE}
  labels:
    app: phi-4
spec:
  replicas: 1
  selector:
    matchLabels:
      app: phi-4
  template:
    metadata:
      labels:
        app: phi-4
        azure.workload.identity/use: "true"
    spec:
      volumes:
      - name: shm
        emptyDir:
          medium: Memory
      containers:
      - name: vllm
        image: ${VLLM_IMAGE}
        args:
        - --model
        - az://${STORAGE_CONTAINER_NAME}/${MODEL_NAME}
        - --load-format
        - runai_streamer
        - --tensor-parallel-size
        - "1"
        - --pipeline-parallel-size
        - "1"
        - --enable-prefix-caching
        - --served-model-name
        - ${MODEL_NAME}
        ports:
        - containerPort: 8000
        # vLLM serves /health on port 8000 and only returns 200 once the engine
        # has finished loading and is ready to serve.
        #
        # startupProbe covers the slow first load: streaming the weights from Blob
        # and loading them onto the GPU takes minutes. While it's still failing,
        # Kubernetes holds off the readiness probe, so the pod won't be marked
        # ready (or get traffic) until the server is actually up. The window here
        # is periodSeconds * failureThreshold = 10s * 60 = up to 10 minutes; bump
        # failureThreshold for larger models.
        startupProbe:
          httpGet:
            path: /health
            port: 8000
          periodSeconds: 10
          failureThreshold: 60
        # readinessProbe takes over once startup succeeds. If /health starts
        # failing later (e.g. the engine wedges), the pod is pulled from the
        # Service endpoints until it recovers.
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          periodSeconds: 10
          failureThreshold: 3
        env:
        - name: AZURE_STORAGE_ACCOUNT_NAME
          value: "${STORAGE_ACCOUNT_NAME}"
        resources:
          limits:
            nvidia.com/gpu: "1"
          requests:
            nvidia.com/gpu: "1"
        volumeMounts:
        - name: shm
          mountPath: /dev/shm
---
apiVersion: v1
kind: Service
metadata:
  name: phi-4
  namespace: ${NAMESPACE}
spec:
  selector:
    app: phi-4
  ports:
  - port: 8000
    targetPort: 8000
EOF
```

Wait for the rollout to complete:

```bash
kubectl rollout status deployment/phi-4 --timeout=600s
```

In a separate terminal you can follow the logs:

```bash
kubectl logs -f deployment/phi-4
```

---

## 6. Verify and test

Once it's serving, port-forward and send a chat completion. The port-forward needs a moment to establish, so wait for `/health` to answer before firing the request:

```bash
kubectl port-forward svc/phi-4 8000:8000 &

# Wait for the tunnel to come up so the first request doesn't race it.
until curl -sf http://localhost:8000/health >/dev/null; do sleep 1; done

curl -s http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "microsoft/phi-4",
        "messages": [{"role": "user", "content": "Hello!"}],
        "max_tokens": 50
    }' | jq .
```

A JSON response with a `choices[0].message.content` field means the model loaded from Blob and is serving.

---

## How it fits together

```mermaid
flowchart TB
    HF["HuggingFace"]
    Job["upload Job<br/>(in-cluster,<br/>workload identity)"]
    Blob["Azure Blob<br/>az://models/microsoft/phi-4"]
    Pod["vLLM pod<br/>(workload identity,<br/>az:// native)"]
    GPU["A100 GPU memory"]

    HF -->|download| Job
    Job -->|azcopy upload| Blob
    Blob -->|"RunAI Model Streamer<br/>(--load-format runai_streamer)"| Pod
    Pod -->|load tensors| GPU
```

The pieces that make this clean:

- **Native `az://` support** in vLLM + runai-model-streamer means a stock `vllm/vllm-openai` image just works. No custom builds, no monkey-patching.
- **Workload identity end to end.** Neither the uploader nor the server ever sees a storage key — both authenticate with short-lived federated tokens, and the same managed identity does double duty (write for the Job, read for the server).
- **Managed GPU node pool.** `--enable-managed-gpu=true` hands the driver, device plugin, and DCGM exporter lifecycle to AKS, so there's no GPU operator to install, reconcile, or debug.
- **Upload from inside Azure.** Moving the HuggingFace → Blob copy into a Job trades your home uplink for Azure's backbone, turning an hours-long upload into a minutes-long one.

---

## Cleanup

The GPU VM is the expensive part — delete the resource group when you're done to stop the meter on everything in one shot:

```bash
az group delete --name "${AZURE_RESOURCE_GROUP}" --yes --no-wait
```

---

## References

- [vLLM #34614 — Azure Blob support in the RunAI streamer loader](https://github.com/vllm-project/vllm/pull/34614)
- [runai-model-streamer #116 — `az://` scheme support](https://github.com/run-ai/runai-model-streamer/pull/116)
- [AKS-managed GPU node pools (preview)](https://learn.microsoft.com/azure/aks/aks-managed-gpu-nodes)
- [Azure Workload Identity on AKS](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [vLLM RunAI Model Streamer docs](https://docs.vllm.ai/en/latest/models/extensions/runai_model_streamer.html)
