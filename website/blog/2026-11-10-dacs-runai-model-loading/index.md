---
title: "Accelerate Model Loading on AKS with DACS and Run:ai Model Streamer"
date: "2026-11-10"
description: "Load GPT-OSS-20B into vLLM on an AKS H100 node with Run:ai Model Streamer and DACS. Configure three NVMe cache servers and verify fresh-pod warm-cache loading and inference."
authors: ["francis-yu", "hariharan-sethuraman"]
tags: [acstor, ai, ai-inference]
keywords: ["AKS", "DACS", "Azure Container Storage", "Run:ai Model Streamer", "model loading"]
---

When you add an inference replica, replace a node, or roll out a deployment, your application can spend valuable time loading model weights before it serves its first request. Streaming those weights helps avoid a download-then-load pipeline. Reusing weights already cached in your cluster can reduce repeated reads from object storage.

In our [earlier post about Run:ai Model Streamer and vLLM on AKS](https://blog.aks.azure.com/2026/07/13/runai-streamer-vllm), we explored streaming models directly from Azure Blob Storage. This post adds **distributed accelerator for cloud storage (DACS)**: a distributed, read-through NVMe cache managed through Azure Container Storage. You'll configure Run:ai to use DACS, load a model, and verify that a fresh pod reuses cached weights in your AKS cluster.

<!-- truncate -->

:::caution[Preview and measurement scope]

DACS is in public preview. Preview features have no service-level agreement and aren't recommended for production workloads. See the [Microsoft Azure preview terms](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

We validated this walkthrough with **vLLM model loading and inference on an NVIDIA H100**. The model-loading stage and container-start-to-ready interval are different measurements; neither establishes production latency or an SLA.

:::

## Streaming and caching solve different problems

Run:ai Model Streamer reads tensors concurrently and, in a GPU loading workflow, can overlap storage reads with CPU-to-GPU transfers. DACS adds reuse across pods: model chunks remain on the cache nodes' local NVMe disks, even when an application pod restarts or moves.

In this post, **cold** and **warm** describe DACS's cached data for a particular model version:

- **Cold cache:** The model's weight chunks aren't cached when loading begins. Reads retrieve missing chunks from Azure Blob Storage and populate DACS.
- **Warm cache:** A previous load has populated the cache. A subsequent load, even from a new application pod, can reuse those chunks from the cache nodes' NVMe disks instead of fetching them again from Blob Storage.

A cache can also be partially warm: cached chunks come from DACS, while missing chunks still come from Blob Storage. A warm DACS cache doesn't mean the model is already loaded into GPU memory.

The diagrams show where model data comes from. A **cache hit** means DACS can read the requested data from the cache machines' NVMe disks. A **cache miss** means the data must come from Blob Storage and can then populate the cache:

```text
Cache hit:
vLLM / Run:ai Azure backend -> DACS native client -> cache-node NVMe -> H100 model loader

Cache miss:
vLLM / Run:ai Azure backend -> DACS native client -> Azure Blob Storage -> H100 model loader
                                                  \-> populate distributed cache
```

The DACS controller manages cache servers, keeping them provisioned and configured, but it doesn't sit between the client and the data as a proxy. DACS caches model-file data rather than inference KV cache or container images, while Azure Blob Storage remains the durable source of truth. Because cached data is temporary and isn't replicated for durability, clients can fall back to Blob Storage whenever a chunk is missing or the cache is unavailable.

This pattern is useful when multiple replicas repeatedly load the same model version, such as during scale-out, recovery, or rolling updates. The benefit depends on how much of the model is already cached, how much data the workloads need, the available CPU and network capacity, and the loader configuration. A cold cache still requires an initial read from Blob Storage, and concurrent readers can each fetch the same missing chunks before those chunks become available in the cache.

## What we measured

We validated the GPU workflow on November 9, 2026, using an isolated AKS cluster in the `Australia East` region. Three `Standard_L16s_v3` nodes ran the cache servers, while a `Standard_NC40ads_H100_v5` node ran vLLM on an NVIDIA H100 NVL GPU. A separate small system node handled cluster services. The cluster used Kubernetes `1.36.5`, the managed DACS extension and native client `0.1.0`, vLLM `0.32.0`, Torch `2.13.0+cu130`, and Run:ai core and Azure backend `0.17.3`.

For each test, we started a fresh pod with the same GPT-OSS-20B checkpoint at revision `6cee5e81ee83917806bbde320786a8fb61efebee`. The checkpoint contains approximately **13.761 GB of model weights** across three SafeTensors shards. Before uploading the files to private Azure Blob Storage, we verified their contents using full-file SHA-256 checksums. We then checked the uploaded file names and sizes and confirmed that the model could generate tokens on the GPU.

| Loading path | Number of runs | vLLM model-loading time | Container start to ready |
| --- | ---: | ---: | ---: |
| Direct Blob Storage, DACS disabled | 1 | 17.41 s | 61 s |
| DACS with an initially empty cache | 1 | 17.51 s | 60 s |
| DACS with a populated cache | 5 | **8.08 s mean** | **50.6 s mean** |

With a warm cache, model-loading times ranged from **7.59 to 9.48 seconds**, with a median of **7.80 seconds**. The cold DACS load took approximately **2.17 times as long as the warm load**. We included all five warm runs, including the slower first run.

These results demonstrate the benefit of reusing cached model data in this deployment, but they aren't a performance guarantee. Both the cold-cache test and the direct-Blob control consisted of a single run, so neither provides a statistical baseline for broader comparisons.

We measured model-loading time using vLLM's `Model loading took ... seconds` log entry. That stage includes initialization and loading weights onto the GPU, rather than measuring network transfer alone. We measured startup readiness separately, from the container's Kubernetes `startedAt` timestamp to the timestamp when it became Ready. This excludes scheduling and image-pull time; the container image was already present on the H100 node.

Startup configuration also matters. The example uses `--enforce-eager`, and different compilation or CUDA-graph settings can change how long initialization takes. Our tests used a kubelet HTTP readiness probe, while the walkthrough uses an exec probe to support a server that listens only on the pod's loopback interface. Remeasure readiness with the walkthrough manifest before comparing your results with these measurements.

The read metrics confirmed that the warm runs used the cache. Every warm pod recorded **zero native backing-store weight reads** and nonzero remote-cache reads, with corresponding increases in the cache servers' download-byte counters. The direct-Blob control generated no DACS upload or download traffic.

We also checked that the model was running on the GPU, not merely loading successfully. All seven pods answered the same chat request, “What is 2 + 2? Answer briefly,” with `4`, and NVIDIA tooling showed the `VLLM::EngineCore` process using H100 GPU memory.

The smaller improvement in overall readiness reflects the work that caching doesn't remove. Tokenizer setup, engine initialization, kernel warmup, and other startup tasks still take time even when model weights load faster. An empty DACS cache must also retrieve and populate the model data, so the first load still requires reads from Blob Storage.

## Before you start

You need:

- An AKS cluster meeting the [DACS preview requirements](https://learn.microsoft.com/en-us/azure/storage/container-storage/distributed-accelerator-for-cloud-storage-quickstart#prerequisites), including Kubernetes 1.35 or later.
- Three Linux `Standard_L16s_v3` NVMe cache nodes and one `Standard_NC40ads_H100_v5` GPU client node, plus your system node pool. The example requests 16 CPU/64 GiB for vLLM and limits it to 32 CPU/128 GiB and one GPU.
- DACS enabled through the managed Azure Container Storage extension, with the controller and NVMe prerequisite DaemonSet ready. Follow the [DACS quickstart](https://learn.microsoft.com/en-us/azure/storage/container-storage/distributed-accelerator-for-cloud-storage-quickstart) through installation and NVMe preparation. Don't install a second controller or disk-setup chart.
- OIDC and [Microsoft Entra Workload ID enabled on AKS](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster#enable-oidc-issuer-and-microsoft-entra-workload-id-on-an-aks-cluster).
- A private Blob container containing a licensed SafeTensors model under an immutable, versioned prefix. Keep the model in Blob Storage; direct Hugging Face origin access isn't part of DACS.
- A single-trust-domain cluster containing only trusted workloads. DACS doesn't authenticate cache clients or encrypt cache traffic by default; restrict cache-server network access to trusted pods.
- Bash, Azure CLI, `kubectl`, Docker, and permissions to create a managed identity, assign a container-scoped reader role, and deploy Kubernetes resources.
- A container registry your cluster can pull from. Configure [AKS image-pull access](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration) separately from the application's Blob reader identity.
- An H100-compatible NVIDIA driver and device plugin. Our test used AKS managed GPU support, driver `580.159.04`, CUDA 13.0, and one allocatable `nvidia.com/gpu` device. Don't install a second device plugin when AKS already manages it.

Only label cache nodes whose NVMe disks are dedicated to DACS: the managed prerequisites can format those disks. Don't relabel or reformat a shared node pool for this experiment.

## 1. Set the experiment values

First, tell the commands which Azure resources to use. Replace the values in angle brackets with your own resource names and IDs, and check that `GPU_NODE_POOL` matches your GPU node pool's name. Run the commands in one Bash terminal, and keep that terminal open: later steps reuse these settings. The final two commands select your Azure subscription and connect `kubectl` to your AKS cluster.

Keep the GPT-OSS-20B configuration for this example. Another model can require different memory, data types, or loading settings. You'll set `CACHE_FOLDER_PATH` after choosing a directory for the cache.

```bash
# filename: settings.sh
SUBSCRIPTION_ID="<subscription-id>"
RESOURCE_GROUP="<cluster-and-identity-resource-group>"
CLUSTER_NAME="<aks-cluster>"
STORAGE_ACCOUNT="<storage-account>"
STORAGE_CONTAINER="<model-container>"
MODEL_PREFIX="<immutable-model-prefix>"
REGISTRY_NAME="<registry-name>"
CACHE_NAMESPACE="runai-dacs"
CACHE_NAME="model-cache"
CACHE_FOLDER_PATH=""
IDENTITY_NAME="dacs-runai-demo-reader"
GPU_NODE_POOL="gpupool"
WORKLOAD_IMAGE="${REGISTRY_NAME}.azurecr.io/runai-dacs-vllm/gpu:0.32.0-dacs0.1.0"
az account set --subscription "$SUBSCRIPTION_ID" || exit 1

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" || exit 1

```

Set the required `CACHE_FOLDER_PATH` value before running the cache script. Follow [Create an isolated cache](#4-create-an-isolated-cache) to choose and prepare the directory; the script doesn't default to the managed cache root.

Place all checkpoint files, including configuration, tokenizer, shard index, and weights, under the versioned Blob prefix. Follow [Upload model files to Blob Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-distributed-accelerator-for-cloud-storage-model-streamer#upload-model-files-to-blob-storage), but set `MODEL_ID="openai/gpt-oss-20b"`, `MODEL_REVISION="6cee5e81ee83917806bbde320786a8fb61efebee"`, and `MODEL_DIR="$PWD/models/gpt-oss-20b-$MODEL_REVISION"`. Replace the guide's single-file download command with `hf download "$MODEL_ID" --revision "$MODEL_REVISION" --include "*.json" "*.safetensors" "*.jinja" --local-dir "$MODEL_DIR"` to include all three SafeTensors shards, their index, and the configuration and tokenizer files. Continue with the guide's upload steps using this directory and your configured storage account, container, and immutable model prefix. Downloading from Hugging Face is a preparation step, not a DACS origin integration.

If you're starting with a new test cluster, these commands add two node pools, or groups of machines: three machines with fast local disks to hold cached model data, and one GPU machine to run the model. The final command enables DACS after both pools are created.

These machines incur charges. Use only dedicated, disposable cache disks because DACS setup can format them. Before creating the pools, complete the [managed GPU prerequisites](https://aka.ms/aks/managed-gpu) and the [SSH access prerequisites](https://learn.microsoft.com/azure/aks/manage-ssh-node-access#prerequisites), including installing the required `aks-preview` extension. Register `ManagedGPUExperiencePreview` and `DisableSSHPreview`, wait for both registrations to reach `Registered`, and refresh the `Microsoft.ContainerService` resource provider.

```bash
az aks nodepool add --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name cachepool --node-count 3 --node-vm-size Standard_L16s_v3 --os-sku Ubuntu \
  --mode User --labels dacs.azure.com/processing-unit=cpu --ssh-access disabled
az aks nodepool add --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name "$GPU_NODE_POOL" --node-count 1 --node-vm-size Standard_NC40ads_H100_v5 \
  --os-sku Ubuntu --mode User --enable-managed-gpu true \
  --node-taints nvidia.com/gpu=true:NoSchedule --ssh-access disabled
az aks update --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
  --enable-azure-container-storage distributedAccelerator
```

Managed GPU support requires the applicable AKS preview prerequisites. Use the [managed GPU guidance](https://aka.ms/aks/managed-gpu) for your subscription. If AKS reports an in-progress addon operation, wait for it to complete before retrying; don't abort another operation just to continue this experiment.

## 2. Package the model server and cache client

AKS runs the model server from a container image, a package containing the application and its software dependencies. This image recipe starts with the tested GPU version of vLLM and adds the software it needs to read through DACS.

Save the recipe as `Dockerfile` in an empty build directory.

```dockerfile
FROM vllm/vllm-openai@sha256:6ee133356d49ed24cee03dd0cda3d3980279a11c107ce3e752c89e76540f41c9
# Remove an unused exporter whose requirements conflict with this base image's SDK.
RUN python3 -m pip uninstall -y opentelemetry-exporter-otlp-common
RUN python3 -m pip install --no-cache-dir "runai-model-streamer[azure]==0.17.3" "dacs-client==0.1.0" && python3 -m pip check
```

The pinned x86-64 GPU base image already includes Run:ai Model Streamer and its Azure backend at `0.17.3`. The explicit Run:ai requirement keeps those tested versions, while `dacs-client` installs the DACS native client in the same Python environment. Keep the application's Torch/CUDA constraints.

The selected base image also includes an unused OpenTelemetry component with conflicting dependency requirements: `opentelemetry-exporter-otlp-common==0.66b1` requires `opentelemetry-sdk~=1.45.1`, but the image contains SDK `1.40.0`. This conflict isn't caused by DACS. Upgrading the telemetry stack would violate LMCache's API and exporter constraints, so the recipe removes only the unused exporter and leaves the SDK unchanged. This workaround applies to this specific image, not every vLLM installation. If you choose another base image, resolve its dependency conflicts and require `pip check` to pass.

Now build the image and upload it to your Azure Container Registry so AKS can download it. These commands also locate the installed DACS library and record the uploaded image's unique identifier, called a digest. Using that digest ensures later steps refer to the exact image you uploaded.

```bash
# filename: image.sh
az acr login --name "$REGISTRY_NAME" || exit 1
docker build --platform linux/amd64 -t "$WORKLOAD_IMAGE" . || exit 1
docker push "$WORKLOAD_IMAGE" || exit 1
DACS_LIBRARY=$(docker run --rm --entrypoint python3 "$WORKLOAD_IMAGE" -c '
from importlib.metadata import distribution
from pathlib import Path

library = distribution("dacs-client").locate_file(
    "py_dacs_client/libStorageDirect.so"
)
library = Path(library).resolve()
assert library.is_file(), library
print(library)
') || exit 1
IMAGE_DIGEST=$(az acr repository show \
  --name "$REGISTRY_NAME" \
  --image "${WORKLOAD_IMAGE#*/}" \
  --query digest --output tsv) || exit 1
if [[ ! "$IMAGE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  printf '%s\n' "ACR didn't return a valid image digest for $WORKLOAD_IMAGE." >&2
  exit 1
fi
WORKLOAD_IMAGE="${WORKLOAD_IMAGE%:*}@${IMAGE_DIGEST}"
```

The ACR lookup resolves the exact tag just pushed to the configured registry. After validating the digest, the script replaces the tag with an immutable digest reference while preserving the registry and repository. It doesn't select from the local image's `RepoDigests`, which can include other repositories. In the tested image, the library is `/usr/local/lib/python3.12/dist-packages/py_dacs_client/libStorageDirect.so`; resolve it rather than assume that path for another image. Keep the complete installation and sibling native libraries. Run:ai's Azure extra doesn't supply the DACS native client.

## 3. Give the application permission to read the model

The application needs permission to read your model files from Blob Storage. These commands create an Azure identity and connect it to the application in AKS, so you don't need to put passwords or storage keys in the application. They also create a namespace, a named group of Kubernetes resources, for this experiment.

Use a new namespace and an identity name that doesn't already exist in the resource group. The identity can read only the specified model container, not the whole storage account or subscription. Uploading the model requires separate write permission.

These permissions protect access to Blob Storage; they don't isolate data already stored in DACS from other cache clients. Use this experiment only in a single-tenant cluster containing trusted workloads.

```bash
# filename: identity.sh
kubectl create namespace "$CACHE_NAMESPACE" || exit 1
az identity create --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --output none
CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query principalId -o tsv)
OIDC_ISSUER=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query oidcIssuerProfile.issuerUrl -o tsv)
STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --query id -o tsv)
ROLE_ID=$(az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" \
  --scope "$STORAGE_ID/blobServices/default/containers/$STORAGE_CONTAINER" \
  --query id --output tsv) || exit 1

az identity federated-credential create \
  --name runai-reader --identity-name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:$CACHE_NAMESPACE:runai-reader" \
  --audiences api://AzureADTokenExchange --output none || exit 1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: runai-reader
  namespace: $CACHE_NAMESPACE
  annotations:
    azure.workload.identity/client-id: "$CLIENT_ID"
EOF
```

Azure can take several minutes to apply the new permissions. The application's Kubernetes configuration must select the `runai-reader` ServiceAccount and include the label `azure.workload.identity/use: "true"`. These settings let AKS supply the identity settings and authentication token automatically. Don't add storage keys, SAS tokens, or client secrets.

## 4. Create an isolated cache

Our GPU test used a **new cluster with empty NVMe disks**, so the Cache used the root prepared by the managed extension, `/var/lib/ssd/cacheserver`. Use this root only on a new, dedicated test cluster with empty disks and no other Cache. Don't assume a new Kubernetes resource makes old disk data cold.

On an existing cluster, set `CACHE_FOLDER_PATH` to an administrator-approved, empty, dedicated NVMe-backed directory, such as `/var/lib/ssd/cacheserver/runai-dacs-20261110`. Have your cluster administrator create it at the same absolute path on every eligible cache node before you apply the manifest. Custom subdirectories aren't created automatically. Keep this directory unchanged between the cold and warm trials, and don't share it with another Cache.

Before creating the cache, check that the DACS management service and disk-preparation components are ready. The first two commands wait for those components; both must finish successfully before you continue. The last command lists the machines selected to store cached data.

```bash
kubectl rollout status deployment/dacs-manager -n kube-system --timeout=10m
kubectl rollout status daemonset/dacs-prereq -n kube-system --timeout=10m
kubectl get nodes -l dacs.azure.com/processing-unit=cpu -o wide
```

This configuration asks DACS to run three cache servers, one on each eligible NVMe machine. The servers store reusable copies of model data in the directory you prepared. The commands wait for the Cache to report Ready and save its connection address in `CACHE_DISCOVERY_URL` for the application to use later.

```bash
# filename: cache.sh
: "${CACHE_FOLDER_PATH:?Set CACHE_FOLDER_PATH to the precreated cache directory on every eligible cache node.}"
cat <<EOF | kubectl apply -f -
apiVersion: storage.azure.com/v1
kind: Cache
metadata:
  name: $CACHE_NAME
  namespace: $CACHE_NAMESPACE
spec:
  scaling:
    static:
      numServers: 3
  serverSizeInGB: 1000
  serverThreads: 80
  cpuLimit: 4
  memoryLimitMB: 32000
  port: 9065
  metricsPort: 9096
  nodeSelectorKey: dacs.azure.com/processing-unit
  nodeSelectorValue: cpu
  storage:
    hostPath:
      nodeCacheFolderPath: "$CACHE_FOLDER_PATH"
EOF
kubectl wait "cache/$CACHE_NAME" -n "$CACHE_NAMESPACE" --for=condition=Ready --timeout=10m
CACHE_DISCOVERY_URL=$(kubectl get cache "$CACHE_NAME" -n "$CACHE_NAMESPACE" -o jsonpath='{.status.discoveryURL}')
kubectl get cache,pods -n "$CACHE_NAMESPACE" -o wide
```

Confirm that the output shows three ready cache servers, one per eligible NVMe machine. Before loading the model, record the starting measurements from **every server belonging to this Cache** using the [DACS metrics endpoint procedure](https://learn.microsoft.com/en-us/azure/storage/container-storage/monitor-distributed-accelerator-for-cloud-storage#metrics-endpoint).

Include cache size and the running totals of uploaded and downloaded bytes. You'll compare these values with later measurements to see how much data entered and left the cache. Also record each server pod's unique identifier (UID) and restart count, so a server replacement or restart doesn't invalidate the comparison. A new Cache resource alone isn't proof that its on-disk data is cold.

## 5. Start the model server on the GPU

This script creates a Kubernetes pod, a running instance of the model server, on your H100 GPU machine. It tells vLLM where to find the model in Blob Storage and how to read its weights through DACS. Before continuing, confirm that the GPU node reports one available `nvidia.com/gpu` device in its allocatable resources.

Save the script as `deploy-vllm.sh`. Run it with `source` as shown after the script, so it can use the settings from your current terminal.

If a pod terminates with Blob authorization errors, inspect its logs and wait for permission propagation, then delete it with `kubectl delete pod "$POD_NAME" -n "$CACHE_NAMESPACE" --wait=true` before sourcing `deploy-vllm.sh` again. The script uses `kubectl create`, so it can't replace an existing failed pod. If a failed attempt read model weights, treat the cache as potentially warm and have your administrator reset only the experiment's dedicated cache before reporting a cold run.

This example accepts requests only from inside the container by listening on `127.0.0.1`. Kubernetes checks the server's `/health` endpoint from inside that container, and you'll send test requests through `kubectl exec`. Keep the server local: it doesn't require authentication, so don't expose it through a Service or ingress.

```bash
# filename: deploy-vllm.sh
POD_NAME="${POD_NAME:-cold}"
CACHE_ENABLED="${CACHE_ENABLED:-1}"
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $CACHE_NAMESPACE
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: runai-reader
  restartPolicy: Never
  nodeSelector:
    agentpool: "$GPU_NODE_POOL"
  tolerations:
    - {key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}
  containers:
    - name: vllm
      image: "$WORKLOAD_IMAGE"
      command: ["vllm", "serve"]
      args:
        - "az://$STORAGE_CONTAINER/$MODEL_PREFIX"
        - "--host"
        - "127.0.0.1"
        - "--load-format"
        - "runai_streamer"
        - "--served-model-name"
        - "cached-model"
        - "--dtype"
        - "bfloat16"
        - "--max-model-len"
        - "2048"
        - "--gpu-memory-utilization"
        - "0.8"
        - "--enforce-eager"
      resources:
        requests: {cpu: "16", memory: 64Gi}
        limits: {cpu: "32", memory: 128Gi, nvidia.com/gpu: 1}
      env:
        - {name: AZURE_STORAGE_ACCOUNT_NAME, value: "$STORAGE_ACCOUNT"}
        - {name: CACHE_DISCOVERY_URL, value: "$CACHE_DISCOVERY_URL"}
        - {name: CACHE_SERVER_PORT, value: "9065"}
        - {name: RUNAI_STREAMER_EXPERIMENTAL_AZURE_CACHE_LIB, value: "$DACS_LIBRARY"}
        - {name: RUNAI_STREAMER_EXPERIMENTAL_AZURE_CACHE_ENABLED, value: "$CACHE_ENABLED"}
        - {name: RUNAI_STREAMER_CHUNK_BYTESIZE, value: "2097152"}
        - {name: SI_streamingChunkSize, value: "2097152"}
        - {name: RUNAI_STREAMER_CONCURRENCY, value: "64"}
        - {name: RUNAI_STREAMER_MEMORY_LIMIT, value: "4294967296"}
        - {name: RUNAI_STREAMER_LOG_LEVEL, value: "INFO"}
        - {name: STORAGE_LOG_LEVEL, value: "INFO"}
        - {name: SI_cacheEnableSyncUpload, value: "true"}
        - {name: SI_cacheMaxUploadBufferSizePerProcessGB, value: "1"}
      readinessProbe:
        exec:
          command:
            - python3
            - -c
            - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).close()"
        periodSeconds: 2
        timeoutSeconds: 5
      volumeMounts:
        - {name: shm, mountPath: /dev/shm}
  volumes:
    - name: shm
      emptyDir: {medium: Memory, sizeLimit: 8Gi}
EOF
```

Now start the first model server. With an empty cache, this load must retrieve model data from Blob Storage. The commands wait until the server reports that it's ready, display its startup messages, and show GPU status.

```bash
POD_NAME="cold"
CACHE_ENABLED="1"
source ./deploy-vllm.sh
kubectl wait "pod/$POD_NAME" -n "$CACHE_NAMESPACE" --for=condition=Ready --timeout=30m
kubectl logs "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm
kubectl exec "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm -- nvidia-smi
```

The example requests **2 MiB** through both environment variables, but Run:ai `0.17.3` enforces a **5 MiB** minimum for its object-storage read blocks, while `SI_streamingChunkSize` keeps DACS chunks at **2 MiB**. These settings don't produce matching effective sizes. Verify the effective sizes before tuning, and repeat the measurements if you change them. For another model, consult the [chunk-size guidance](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-distributed-accelerator-for-cloud-storage-model-streamer#optimize-read-performance).

Our H100 logs selected the Triton MXFP4 MoE backend and reported 13.03 GiB of model memory. The checkpoint retains its MXFP4 quantization; `--dtype bfloat16` doesn't mean all stored weights become bfloat16. The 80% GPU-memory setting also reserves space for vLLM's KV cache. DACS's model-file cache is separate from that KV cache.

The Run:ai URI is `az://<container>/<prefix>`; the account comes from `AZURE_STORAGE_ACCOUNT_NAME`. Don't substitute the native Python client's account-hostname URI format.

By default, Run:ai uses an available cache provider and otherwise streams directly from Azure Blob Storage. This walkthrough explicitly sets `RUNAI_STREAMER_EXPERIMENTAL_AZURE_CACHE_ENABLED=1` to require the provider, so initialization fails if the provider cannot load. This setting doesn't guarantee cache hits or disable DACS's Blob fallback. Confirm the read path with counters.

This example waits for cache uploads to complete rather than allowing uploads to build up in the background. That choice is deliberate: the native client's default asynchronous upload budget isn't a safe pod-memory limit. Budget host memory, streamer buffers, native population buffers, GPU memory, and `/dev/shm` separately. After establishing correctness, tune asynchronous population and concurrency for your workload.

A ready server isn't enough to prove the model can answer requests. This small Python program asks "What is 2 + 2?" and checks that the server returns a nonempty answer and generates tokens, the pieces of text a model produces. Save it as `inference_check.py`.

```python
import json
import urllib.request

body = json.dumps({
    "model": "cached-model",
    "messages": [{"role": "user", "content": "What is 2 + 2? Answer briefly."}],
    "temperature": 0,
    "max_tokens": 128,
}).encode()
request = urllib.request.Request(
    "http://127.0.0.1:8000/v1/chat/completions",
    data=body,
    headers={"Content-Type": "application/json"},
)
with urllib.request.urlopen(request, timeout=600) as response:
    result = json.load(response)
print(json.dumps(result, indent=2))
assert result["choices"][0]["message"]["content"].strip(), result
assert result["usage"]["completion_tokens"] > 0, result
```

Run the test inside the model-server container, where the local-only server is reachable. Inspect the returned answer as well as the program's checks; the checks don't verify that the answer is correct.

```bash
kubectl exec -i "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm -- python3 - < inference_check.py
```

## 6. Prove that the next pod uses the cache

Check the first server's logs to find its model-loading time and where it read model data:

```bash
kubectl logs cold -n "$CACHE_NAMESPACE" -c vllm
```

Confirm that the model answered the test request successfully and that the logs include a vLLM model-loading duration. For this first load, the native client's `ReadChunk` counters must show nonzero **`RemoteClient`** reads, meaning model weights came from Blob Storage. **`RemoteCache`** reads mean weights came from the shared cache. `GetProperties` hits concern file metadata, not weight data, so they don't prove that cached weights were reused.

Keep the first model server running while you check that DACS has stored the data. The cache servers expose metrics, including counters that track running totals of transferred bytes. Compare these with the starting measurements you recorded:

1. Read the metrics from every selected cache server every 10 seconds, for up to ten minutes.
2. Confirm that the total uploaded bytes (`cache_server_upload_request_size_bytes_sum`) and cached data size (`cache_server_cache_size_bytes`) increase from their starting values.
3. After the total increase, require each server's upload-byte counter to stay unchanged for three consecutive intervals. Don't accept the comparison if metrics are missing, counters reset, server UIDs change, or servers restart.
4. Record the new starting value for downloaded bytes (`cache_server_download_request_size_bytes_sum`) before testing the next pod.

Stable counters are a readiness signal, not proof that every chunk is cached. If the observation window expires, stop rather than label the cache warm. Check memory pressure, upload errors, eviction, and competing traffic. Larger models might need a longer observation window.

Once the cache-population checks pass, save the first run's inference result and native read counters. The commands that follow save its pod details, including the UID, and logs, then delete only the model-server pod to free the GPU. Keep the Cache and its servers running so they retain the model data. With only one H100, the next model server can't run until the first exits.

```bash
kubectl get pod cold -n "$CACHE_NAMESPACE" -o json > cold-pod.json
kubectl logs cold -n "$CACHE_NAMESPACE" -c vllm > cold.log
kubectl delete pod cold -n "$CACHE_NAMESPACE" --wait=true
```

Start a **new pod** with the same model and settings. This tests whether a fresh application instance can reuse data cached by the first instance. These commands run the same question again and save the new pod's details and logs for comparison.

```bash
POD_NAME="warm-1"
CACHE_ENABLED="1"
source ./deploy-vllm.sh
kubectl wait "pod/$POD_NAME" -n "$CACHE_NAMESPACE" --for=condition=Ready --timeout=30m
kubectl exec -i "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm -- python3 - < inference_check.py
kubectl get pod "$POD_NAME" -n "$CACHE_NAMESPACE" -o json > warm-pod.json
kubectl logs "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm > warm.log
```

Use these checks to confirm that the new pod loaded its model weights from the cache rather than Blob Storage. Accept a fully warm vLLM load only when:

- The warm pod has a different UID from the cold pod.
- The same image, model revision, and loading configuration produce successful GPU inference.
- Native data-read counters show nonzero `RemoteCache` and **zero `RemoteClient`** reads.
- Cache-server download bytes increase without server restarts or counter resets.

Our five accepted warm loads recorded 8,712-8,713 remote-cache reads and zero backing-store reads each. The first cold load recorded 6,572 backing-store reads; some concurrent cold reads were already cache hits. Cache-server download bytes increased by approximately 13.844 GB for each warm load. The transfer count reflects the loader's read pattern, not a new logical checkpoint size.

For an independent direct-Blob control, delete the current application pod and source the script with a new pod name and `CACHE_ENABLED="0"`. Keep the image, model, resources, and inference request identical. Capture server metrics before and after, require successful inference, and expect no DACS upload/download-byte increase during an isolated test. A successful warm load doesn't imply zero Blob metadata requests.

To repeat warm loads, save each pod's evidence, delete that application pod, and create another uniquely named pod against the unchanged Cache. Don't restart the cache servers between warm trials.

## Measure the loading stage and readiness separately

Compare the model-loading times recorded by vLLM for the two runs. This command extracts the relevant message from each saved log:

```bash
grep "Model loading took" cold.log warm.log
```

Model loading is only part of startup. To measure how long each server took to become available, compare the container's start time (`state.running.startedAt`) with the time its pod became Ready (`lastTransitionTime` of the Ready condition) in the saved pod details. Wait for **Ready**, not `Succeeded`: a model server is supposed to keep running rather than finish and exit.

The measured warm start-to-ready values were 50-52 seconds. That interval includes more than loading, and its timestamp/probe resolution differs from vLLM's high-resolution loader timer. It doesn't include first-request latency, scheduling, or a fresh image download. Test those boundaries separately for your application.

This experiment validates a single H100 reader and sequential fresh-pod reuse. It doesn't characterize concurrent scale-out, multiple GPU workers, production percentiles, or steady-state token throughput. Repeat direct and cold baselines too if you need a statistical performance comparison.

## Clean up

After saving your results, remove the application and cache resources in the experiment's namespace. These commands also remove the Azure identity's Blob read permission and delete the identity. Run them only for the namespace and identity created specifically for this experiment.

```bash
kubectl delete namespace "$CACHE_NAMESPACE" --wait=true
az role assignment delete --ids "$ROLE_ID"
az identity delete --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME"
```

Keep existing models, storage accounts, node pools, and the managed DACS extension. Deleting Kubernetes resources doesn't necessarily erase cached files from the machines' NVMe disks. Coordinate removal of only the experiment's dedicated `CACHE_FOLDER_PATH` directory on each cache machine with your cluster administrator.

Deleting the application doesn't stop charges for the GPU and cache machines. If you created both node pools only for this experiment, delete them too. Don't run these commands against shared or preexisting node pools.

```bash
az aks nodepool delete --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name "$GPU_NODE_POOL"

az aks nodepool delete --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name cachepool

```

If you created an entirely temporary cluster and supporting Azure resources, remove that dedicated setup through your infrastructure teardown process. Our validation removed its entire task-owned setup and verified that both its resource group and AKS-managed node resource group were gone.

## Try it with your model

Ready to see how caching affects your inference service? Use the Run:ai streaming loader with DACS to compare startup with an empty cache and a populated shared cache. Start with a representative model in an isolated test environment, verify where the checkpoint came from, and confirm that inference runs on the GPU and model reads use the expected storage or cache path. Then measure the difference in startup time to see what this approach offers your workload, and share your feedback with the Azure Container Storage product team!

- [DACS overview](https://learn.microsoft.com/en-us/azure/storage/container-storage/distributed-accelerator-for-cloud-storage-overview)
- [DACS quickstart](https://learn.microsoft.com/en-us/azure/storage/container-storage/distributed-accelerator-for-cloud-storage-quickstart)
- [Run:ai integration and tuning](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-distributed-accelerator-for-cloud-storage-model-streamer)
- [Monitor DACS](https://learn.microsoft.com/en-us/azure/storage/container-storage/monitor-distributed-accelerator-for-cloud-storage)
