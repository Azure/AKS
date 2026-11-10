---
title: "Accelerate Model Loading on AKS with DACS and Run:ai Model Streamer"
date: "2026-11-10"
description: "Load GPT-OSS-20B into vLLM on an AKS H100 node with Run:ai Model Streamer and DACS. Configure three NVMe cache servers and verify fresh-pod warm-cache loading and inference."
authors: ["francis-yu", "hariharan-sethuraman"]
tags: [acstor, ai, ai-inference]
draft: true
keywords: ["AKS", "DACS", "Azure Container Storage", "Run:ai Model Streamer", "model loading"]
---

When you add an inference replica, replace a node, or roll out a deployment, your application can spend valuable time loading model weights before it serves its first request. Streaming those weights helps avoid a download-then-load pipeline. Reusing weights already cached in your cluster can reduce repeated reads from object storage.

In our [earlier post about Run:ai Model Streamer and vLLM on AKS](https://blog.aks.azure.com/2026/07/13/runai-streamer-vllm), we explored streaming models directly from Azure Blob Storage. This post adds **distributed accelerator for cloud storage (DACS)**: a distributed, read-through NVMe cache managed through Azure Container Storage. You'll configure Run:ai to use DACS, load a model, and verify that a fresh pod reuses cached weights.

<!-- truncate -->

:::caution[Preview and measurement scope]

DACS is in preview. Preview features have no service-level agreement and aren't recommended for production workloads. See the [Microsoft Azure preview terms](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

We validated this walkthrough with **vLLM model loading and inference on an NVIDIA H100**. The model-loading stage and container-start-to-ready interval are different measurements; neither establishes production latency or an SLA.

:::

## Streaming and caching solve different problems

Run:ai Model Streamer reads tensors concurrently and, in a GPU loading workflow, can overlap storage reads with CPU-to-GPU transfers. DACS adds reuse across pods: model chunks remain on the cache nodes' local NVMe disks, even when an application pod restarts or moves.

The paths are:

```text
Cache hit:
vLLM / Run:ai Azure backend -> DACS native client -> cache-node NVMe -> H100 model loader

Cache miss:
vLLM / Run:ai Azure backend -> DACS native client -> Azure Blob Storage -> H100 model loader
                                                  \-> populate distributed cache
```

The DACS controller provisions and reconciles cache servers; it isn't a proxy in this read path. DACS caches model-file data, not inference KV cache or container images. Azure Blob Storage remains the durable source of truth. Cached data is ephemeral and isn't replicated for durability. If chunks are missing or the cache is unavailable, the client can retrieve the data from Blob Storage.

Consider this pattern when replicas repeatedly load the same model version, such as during scale-out, recovery, or rolling updates. Benefits depend on cache warmth, working-set size, CPU and network capacity, and loader configuration. A cache that hasn't been populated can't eliminate the first Blob read. Concurrent cold readers can independently fetch the same missing chunks.

## What we measured

We validated the GPU workflow on November 9, 2026, in an isolated AKS cluster in Australia East. Three `Standard_L16s_v3` workers hosted the cache servers; one `Standard_NC40ads_H100_v5` worker hosted vLLM on an NVIDIA H100 NVL. A separate small system node ran cluster services. We used Kubernetes 1.36.5, the managed DACS extension and native client `0.1.0`, vLLM `0.32.0`, Torch `2.13.0+cu130`, and Run:ai core and Azure backend `0.17.0`.

Each fresh pod served the same GPT-OSS-20B checkpoint, revision `6cee5e81ee83917806bbde320786a8fb61efebee`. Its three SafeTensors shards contain approximately **13.761 GB of weight data**. We verified the source files against full-file SHA-256 values before uploading them to private Blob Storage, checked the uploaded names and sizes, and tested actual token generation on the GPU.

| Loading path | Observations | vLLM model-loading stage | Container start to ready |
| --- | ---: | ---: | ---: |
| Direct Blob, DACS disabled | 1 | 17.41 s | 61 s |
| DACS, initially cold | 1 | 17.51 s | 60 s |
| DACS, warm cache | 5 | **8.08 s mean** | **50.6 s mean** |

The five warm model loads ranged from **7.59 to 9.48 seconds**, with a **7.80-second median**. The single cold observation divided by the warm mean gives a **2.17x time ratio** for the model-loading stage. The direct-Blob control was a single observation too, not a statistical baseline. We retained all five warm samples, including the slower first sample. These results illustrate cache reuse; they aren't a guaranteed speedup for another model or deployment.

We took the loading duration from vLLM's `Model loading took ... seconds` log. This loader stage includes initialization and GPU weight loading, not just network transfer. We measured readiness separately, from Kubernetes' container `startedAt` timestamp to its Ready-condition timestamp, excluding scheduling and image-pull time. The image was already present on the H100 node. The example uses `--enforce-eager`; different compilation and CUDA-graph settings can change startup behavior.

We measured readiness with a kubelet HTTP probe. This walkthrough uses an exec probe to support loopback-only serving, so remeasure readiness with this manifest.

Every warm pod recorded **zero native backing-store weight reads** and nonzero remote-cache reads, corroborated by cache-server download-byte increases. All seven pods completed the same chat request and returned `4` for "What is 2 + 2? Answer briefly." NVIDIA tooling showed the actual `VLLM::EngineCore` process using H100 memory. The direct-Blob control produced no DACS upload or download traffic.

The smaller readiness improvement matters: accelerating weights doesn't remove tokenizer setup, engine initialization, kernel warmup, or other startup work. The first DACS load also has to retrieve and populate model data; don't expect an empty cache to eliminate the initial Blob read.

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

Run the commands in one Bash session, with the correct subscription and cluster context selected. Replace these values. Keep the GPT-OSS-20B configuration for this example; another model can require different memory, dtype, or loader settings.

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
az account set --subscription "$SUBSCRIPTION_ID"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

Set the required `CACHE_FOLDER_PATH` value before running the cache script. Follow [Create an isolated cache](#4-create-an-isolated-cache) to choose and prepare the directory; the script doesn't default to the managed cache root.

Place all checkpoint files, including configuration, tokenizer, shard index, and weights, under the versioned Blob prefix. For model preparation, follow [Upload model files to Blob Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-distributed-accelerator-for-cloud-storage-model-streamer#upload-model-files-to-blob-storage), using your pinned GPT-OSS-20B revision instead of the guide's small model. Downloading from Hugging Face is a preparation step, not a DACS origin integration.

For a new test cluster, create the cache and GPU pools before enabling DACS. The pool commands we used were:

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

Managed GPU support requires the applicable AKS preview prerequisites. Use the [managed GPU guidance](https://aka.ms/aks/managed-gpu) for your subscription. These commands create billable resources. If AKS reports an in-progress addon operation, wait for it to complete before retrying; don't abort another operation just to continue this experiment.

## 2. Build the GPU workload image

Save this as `Dockerfile` in an empty build directory. The pinned x86-64 GPU vLLM base image already includes Run:ai Model Streamer and its Azure backend at `0.17.0`. The explicit Run:ai requirement in this Dockerfile enforces those tested versions; `dacs-client` adds the DACS native client in the same Python environment. Keep the application's Torch/CUDA constraints.

```dockerfile
FROM vllm/vllm-openai@sha256:6ee133356d49ed24cee03dd0cda3d3980279a11c107ce3e752c89e76540f41c9
# Remove an unused exporter whose requirements conflict with this base image's SDK.
RUN python3 -m pip uninstall -y opentelemetry-exporter-otlp-common
RUN python3 -m pip install --no-cache-dir "runai-model-streamer[azure]==0.17.0" "dacs-client==0.1.0" && python3 -m pip check
```

This base-image digest has a pre-existing OpenTelemetry dependency conflict: `opentelemetry-exporter-otlp-common==0.66b1` requires `opentelemetry-sdk~=1.45.1`, but the image contains SDK `1.40.0`. This isn't a conflict with DACS. Upgrading the telemetry stack violates LMCache's API and exporter constraints, so this Dockerfile removes only the unused exporter and leaves the SDK unchanged. This workaround is specific to the pinned digest, not a general vLLM recommendation. If you choose another base, resolve its own constraints and require `pip check` to pass.

Build, push, and resolve the library path from the actual image:

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

## 3. Bind the application identity

Use a new namespace and an identity name that doesn't already exist in the resource group. The reader role is scoped to the model container, not the storage account or subscription. Uploading the model requires separate write permission. DACS treats the cluster as a single trust domain: Blob RBAC and workload identity don't isolate cached data from other workloads. Use this experiment only in a single-tenant cluster.

```bash
# filename: identity.sh
kubectl create namespace "$CACHE_NAMESPACE"
az identity create --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --output none
CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query principalId -o tsv)
OIDC_ISSUER=$(az aks show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query oidcIssuerProfile.issuerUrl -o tsv)
STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --query id -o tsv)
ROLE_ID=$(az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" \
  --scope "$STORAGE_ID/blobServices/default/containers/$STORAGE_CONTAINER" \
  --query id --output tsv)
az identity federated-credential create \
  --resource-group "$RESOURCE_GROUP" --identity-name "$IDENTITY_NAME" \
  --name runai-reader --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:$CACHE_NAMESPACE:runai-reader" \
  --audiences api://AzureADTokenExchange --output none
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

Role propagation can take several minutes. The pod must select this ServiceAccount and carry `azure.workload.identity/use: "true"`. AKS then injects the identity settings and token. Don't add storage keys, SAS tokens, or client secrets.

## 4. Create an isolated cache

Our GPU test used a **new cluster with empty NVMe disks**, so the Cache used the root prepared by the managed extension, `/var/lib/ssd/cacheserver`. Use this root only on a new, dedicated test cluster with empty disks and no other Cache. Don't assume a new Kubernetes resource makes old disk data cold.

On an existing cluster, set `CACHE_FOLDER_PATH` to an administrator-approved, empty, dedicated NVMe-backed directory, such as `/var/lib/ssd/cacheserver/runai-dacs-20261110`. Have your cluster administrator create it at the same absolute path on every eligible cache node before you apply the manifest. Custom subdirectories aren't created automatically. Keep this directory unchanged between the cold and warm trials, and don't share it with another Cache.

Verify the controller and disk prerequisites before creating the Cache:

```bash
kubectl rollout status deployment/dacs-manager -n kube-system --timeout=10m
kubectl rollout status daemonset/dacs-prereq -n kube-system --timeout=10m
kubectl get nodes -l dacs.azure.com/processing-unit=cpu -o wide
```

Create three cache servers, one per eligible NVMe node:

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

Confirm three ready cache servers, one per eligible NVMe node. Record baseline metrics from **every server belonging to this Cache** using the [DACS metrics endpoint procedure](https://learn.microsoft.com/en-us/azure/storage/container-storage/monitor-distributed-accelerator-for-cloud-storage#metrics-endpoint). Include cache size, uploaded bytes, downloaded bytes, pod UIDs, and restart counts. An empty cache resource alone isn't proof that its on-disk data is cold.

## 5. Load the model into vLLM on the H100

Confirm the GPU node advertises one allocatable `nvidia.com/gpu` device, then deploy a cold vLLM pod. The example pairs Run:ai's read size with the DACS chunk size at **2 MiB**, the documented starting recommendation for GPT-OSS-20B. For another model, consult the [chunk-size guidance](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-distributed-accelerator-for-cloud-storage-model-streamer#optimize-read-performance).

Save this Bash block as `deploy-vllm.sh`. Source it in the same configured shell so the variables from earlier steps remain available.

This local-only test binds vLLM to `127.0.0.1`. The exec readiness probe checks `/health` inside the container, and you run inference through `kubectl exec`. Don't expose this unauthenticated test server through a Service or ingress.

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

```bash
POD_NAME="cold"
CACHE_ENABLED="1"
source ./deploy-vllm.sh
kubectl wait "pod/$POD_NAME" -n "$CACHE_NAMESPACE" --for=condition=Ready --timeout=30m
kubectl logs "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm
kubectl exec "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm -- nvidia-smi
```

Our H100 logs selected the Triton MXFP4 MoE backend and reported 13.03 GiB of model memory. The checkpoint retains its MXFP4 quantization; `--dtype bfloat16` doesn't mean all stored weights become bfloat16. The 80% GPU-memory setting also reserves space for vLLM's KV cache. DACS's model-file cache is separate from that KV cache.

The Run:ai URI is `az://<container>/<prefix>`; the account comes from `AZURE_STORAGE_ACCOUNT_NAME`. Don't substitute the native Python client's account-hostname URI format.

By default, Run:ai uses an available cache provider and otherwise streams directly from Azure Blob Storage. This walkthrough explicitly sets `RUNAI_STREAMER_EXPERIMENTAL_AZURE_CACHE_ENABLED=1` to require the provider, so initialization fails if the provider cannot load. This setting doesn't guarantee cache hits or disable DACS's Blob fallback. Confirm the read path with counters.

Synchronous population is deliberate here: the native client's default asynchronous upload budget isn't a safe pod-memory limit. Budget host memory, streamer buffers, native population buffers, GPU memory, and `/dev/shm` separately. After establishing correctness, tune asynchronous population and concurrency for your workload.

Validate token generation, not just readiness. Save this program as `inference_check.py`:

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

```bash
kubectl exec -i "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm -- python3 - < inference_check.py
```

## 6. Prove that the next pod uses the cache

Read the cold vLLM pod's logs:

```bash
kubectl logs cold -n "$CACHE_NAMESPACE" -c vllm
```

Require successful inference, a vLLM model-loading duration, and nonzero native `ReadChunk` **`RemoteClient`** reads for the cold load. `RemoteClient` describes backing-store weight reads; **`RemoteCache`** describes remote-cache weight reads. `GetProperties` hits describe metadata and don't establish weight-cache reuse.

Keep the cold service running while you verify cache population:

1. Scrape every selected cache server every 10 seconds, for up to ten minutes.
2. Require increases in total `cache_server_upload_request_size_bytes_sum` and `cache_server_cache_size_bytes` relative to the baseline.
3. Require each server's upload-byte counter to stay unchanged for three consecutive intervals after the total increase. Reject missing metrics, counter resets, changed server UIDs, and restarts.
4. Save a post-population baseline for `cache_server_download_request_size_bytes_sum`.

Stable counters are a readiness signal, not proof that every chunk is cached. If the observation window expires, stop rather than label the cache warm. Check memory pressure, upload errors, eviction, and competing traffic. Larger models might need a longer observation window.

Save the cold result, pod UID, and native counters, then delete the cold application pod to release its GPU. Keep the Cache and its servers running. With only one H100, a second pod requesting the same GPU can't run until the first exits.

```bash
kubectl get pod cold -n "$CACHE_NAMESPACE" -o json > cold-pod.json
kubectl logs cold -n "$CACHE_NAMESPACE" -c vllm > cold.log
kubectl delete pod cold -n "$CACHE_NAMESPACE" --wait=true
```

Create a **new pod** using the same deployment script:

```bash
POD_NAME="warm-1"
CACHE_ENABLED="1"
source ./deploy-vllm.sh
kubectl wait "pod/$POD_NAME" -n "$CACHE_NAMESPACE" --for=condition=Ready --timeout=30m
kubectl exec -i "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm -- python3 - < inference_check.py
kubectl get pod "$POD_NAME" -n "$CACHE_NAMESPACE" -o json > warm-pod.json
kubectl logs "$POD_NAME" -n "$CACHE_NAMESPACE" -c vllm > warm.log
```

Accept a fully warm vLLM load only when:

- The warm pod has a different UID from the cold pod.
- The same image, model revision, and loading configuration produce successful GPU inference.
- Native data-read counters show nonzero `RemoteCache` and **zero `RemoteClient`** reads.
- Cache-server download bytes increase without server restarts or counter resets.

Our five accepted warm loads recorded 8,712-8,713 remote-cache reads and zero backing-store reads each. The first cold load recorded 6,572 backing-store reads; some concurrent cold reads were already cache hits. Cache-server download bytes increased by approximately 13.844 GB for each warm load. The transfer count reflects the loader's read pattern, not a new logical checkpoint size.

For an independent direct-Blob control, delete the current application pod and source the script with a new pod name and `CACHE_ENABLED="0"`. Keep the image, model, resources, and inference request identical. Capture server metrics before and after, require successful inference, and expect no DACS upload/download-byte increase during an isolated test. A successful warm load doesn't imply zero Blob metadata requests.

To repeat warm loads, save each pod's evidence, delete that application pod, and create another uniquely named pod against the unchanged Cache. Don't restart the cache servers between warm trials.

## Measure the loading stage and readiness separately

Compare vLLM's loader duration in the captured logs:

```bash
grep "Model loading took" cold.log warm.log
```

For startup timing, use each saved pod's container `state.running.startedAt` and the `lastTransitionTime` of its Ready condition. For a serving vLLM pod, wait for **Ready**, not `Succeeded`: the service is supposed to remain running.

The measured warm start-to-ready values were 50-52 seconds. That interval includes more than loading, and its timestamp/probe resolution differs from vLLM's high-resolution loader timer. It doesn't include first-request latency, scheduling, or a fresh image download. Test those boundaries separately for your application.

This experiment validates a single H100 reader and sequential fresh-pod reuse. It doesn't characterize concurrent scale-out, multiple GPU workers, production percentiles, or steady-state token throughput. Repeat direct and cold baselines too if you need a statistical performance comparison.

## Clean up

After collecting evidence, remove the experiment's namespace and dedicated identity, including its role assignment:

```bash
kubectl delete namespace "$CACHE_NAMESPACE" --wait=true
az role assignment delete --ids "$ROLE_ID"
az identity delete --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME"
```

Use these commands only for resources created specifically for the experiment. Keep existing models, storage accounts, node pools, and the managed DACS extension. Deleting Kubernetes resources doesn't necessarily erase cached files from host NVMe; coordinate removal of only the experiment's dedicated `CACHE_FOLDER_PATH` directory on each cache node with your cluster administrator.

New GPU and cache node pools continue to incur charges after you delete application pods. If you created both pools exclusively for this experiment, delete those pools too; don't run these commands against shared or preexisting pools:

```bash
az aks nodepool delete --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name "$GPU_NODE_POOL" --yes
az aks nodepool delete --resource-group "$RESOURCE_GROUP" --cluster-name "$CLUSTER_NAME" \
  --name cachepool --yes
```

If you created an entirely temporary cluster and supporting Azure resources, remove that dedicated setup through your infrastructure teardown process. Our validation removed its entire task-owned setup and verified that both its resource group and AKS-managed node resource group were gone.

## Take the next step

Run:ai provides the streaming loader; DACS adds a shared cache for repeated model reads. Start with a representative model and an isolated cold/warm experiment, verify checkpoint provenance, GPU inference, and the actual cache path, and then measure the effect on your inference service's startup.

- [DACS overview](https://learn.microsoft.com/en-us/azure/storage/container-storage/distributed-accelerator-for-cloud-storage-overview)
- [DACS quickstart](https://learn.microsoft.com/en-us/azure/storage/container-storage/distributed-accelerator-for-cloud-storage-quickstart)
- [Run:ai integration and tuning](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-distributed-accelerator-for-cloud-storage-model-streamer)
- [Monitor DACS](https://learn.microsoft.com/en-us/azure/storage/container-storage/monitor-distributed-accelerator-for-cloud-storage)
