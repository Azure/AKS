# Example 2: Pre-cache a container image

**Goal:** Bake a large GPU inference image into the node image so GPU nodes skip
the image pull at scale-out. **Time:** ~45 min (mostly the one-time bake).

GPU inference images are big — `vllm/vllm-openai` is ~9.7 GB. On a normal node
that's a multi-minute pull every time the pool scales out. With PIS the image is
already in containerd when the node boots.

> Start here if you're new to PIS: this example has **no customization script**,
> just a cached image.

Complete the [shared one-time setup](README.md#one-time-setup) first.

## 1. Create a PIS that caches the image

Container images passed to `--container-images` are pulled with `ctr`, which does
**not** default to Docker Hub — always fully-qualify with `docker.io/`.

```bash
az aks prepared-image-specification create \
  -g $RG --subscription $SUB --name image-prepared-image-specification --location $LOC --version v1 \
  --container-images docker.io/vllm/vllm-openai:v0.11.0
```

Grant the cluster identity **Reader** on the PIS (see
[the grant](README.md#the-pis-read-permission-grant)
with `<pis-name>` = `image-prepared-image-specification`).

**Checkpoint:** the version is `Succeeded`:

```bash
az aks prepared-image-specification version show -g $RG --subscription $SUB \
  --pis-name image-prepared-image-specification --name v1 --query "properties.provisioningState" -o tsv
```

## 2. Attach a GPU pool (this triggers the bake)

```bash
PIS_VER_ID=$(az aks prepared-image-specification version show -g $RG \
  --subscription $SUB --pis-name image-prepared-image-specification --name v1 --query id -o tsv)

az aks nodepool add -g $RG --cluster-name $CLUSTER --subscription $SUB \
  --name imgpool --mode User \
  --node-count 1 --node-vm-size $GPU_SKU --zones $ZONE \
  --prepared-image-specification-id "$PIS_VER_ID"
```

> **Do not** pass `--labels accelerator=nvidia`. `accelerator` is a reserved node
> label that AKS sets automatically on GPU nodes; setting it yourself returns
> `BadRequest: Node label ... accelerator ... is not allowed to be changed`.

The bake takes ~25–40 min. In this run it took **~43 min** (build + node ready).

## 3. Make the node schedulable

A managed-driver PIS pool comes up with the driver, container toolkit, and
containerd nvidia runtime wired — but **no GPU device plugin**, so the node
advertises no `nvidia.com/gpu` and is unschedulable. Install the device plugin:

```bash
kubectl apply -f manifests/nvidia-device-plugin.yaml
# wait ~30-60s, then:
kubectl get nodes -l agentpool=imgpool \
  -o jsonpath='{.items[0].status.allocatable.nvidia\.com/gpu}'   # -> 1
```

## 4. Prove the image was pre-cached

Run a GPU pod straight from the baked image:

```bash
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: gpu-smoke
  labels: { app: gpu-smoke }
spec:
  restartPolicy: Never
  nodeSelector: { agentpool: imgpool }
  containers:
    - name: smi
      image: docker.io/vllm/vllm-openai:v0.11.0
      command: ["nvidia-smi"]
      resources:
        requests: { cpu: 250m, memory: 256Mi }
        limits: { cpu: 500m, memory: 512Mi, nvidia.com/gpu: 1 }
YAML

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gpu-smoke --timeout=120s
kubectl logs gpu-smoke | grep -E "Driver Version|H100"
kubectl describe pod gpu-smoke | grep -iE "Pulled|Pulling|already present"
```

**Checkpoint — what you should see:**

```text
| NVIDIA-SMI 580.159.04   Driver Version: 580.159.04   CUDA Version: 13.0 |
|   0  NVIDIA H100 NVL ...  95830MiB |
...
Container image "docker.io/vllm/vllm-openai:v0.11.0" already present on machine
```

Because the image is pinned to a fixed tag (not `:latest`), kubelet defaults to
`imagePullPolicy: IfNotPresent` and finds the 9.74 GB image **already baked into
the VHD** — so it never contacts the registry. A cold pull of the same image is
~130 s.

> **Why pin the tag?** With `:latest`, kubelet defaults to
> `imagePullPolicy: Always` and still makes a registry manifest round-trip even
> when the layers are cached (~574 ms observed here). A fixed tag or digest skips
> the registry entirely — zero network — which is the whole point of caching.

## 5. Measure scale-out (the real payoff)

Scale the pool, then **prove zero-pull on the new node specifically** — node
readiness alone doesn't prove it (an uncached node also reaches `Ready` without
pulling an image nothing scheduled there yet). Pin a pod to the newly added node
and inspect its image events:

```bash
# record the existing node, scale, then find the one that was added
OLD=$(kubectl get nodes -l agentpool=imgpool -o name | sort)
time az aks nodepool scale -g $RG --cluster-name $CLUSTER -n imgpool \
  --subscription $SUB --node-count 2
kubectl wait --for=condition=Ready $(kubectl get nodes -l agentpool=imgpool -o name) --timeout=600s
NEW=$(comm -13 <(echo "$OLD") <(kubectl get nodes -l agentpool=imgpool -o name | sort) | sed 's#node/##')
echo "new node: $NEW"

# schedule a GPU pod ONTO the new node and check how its image resolved
kubectl apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata: { name: gpu-smoke-new, labels: { app: gpu-smoke-new } }
spec:
  restartPolicy: Never
  # Target the new node via a hostname selector (NOT nodeName): this keeps the
  # scheduler in the loop, so the pod waits as Pending until the device plugin
  # has registered nvidia.com/gpu on that node, instead of kubelet rejecting it.
  nodeSelector: { kubernetes.io/hostname: $NEW }
  containers:
    - name: smi
      image: docker.io/vllm/vllm-openai:v0.11.0
      command: ["nvidia-smi"]
      resources:
        requests: { cpu: 250m, memory: 256Mi }
        limits: { cpu: 500m, memory: 512Mi, nvidia.com/gpu: 1 }
YAML
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gpu-smoke-new --timeout=180s
kubectl describe pod gpu-smoke-new | grep -iE "Pulled|Pulling|already present"
```

**Checkpoint:** the pod on the **new** node reports
`Container image "...v0.11.0" already present on machine` — the image came from
the prepared VHD, not the registry. In this run the second H100 node reached
`Ready` in **438 s** and served the GPU pod with **zero image pull**.

## Troubleshoot

| Symptom | Cause | Fix |
|---|---|---|
| `ResourceMissingPermissionError: .../preparedImageSpecifications/read` | Cluster identity has no rights on the PIS | Grant it **Reader** on the PIS resource; wait 1–2 min |
| `BadRequest: ... accelerator ... not allowed to be changed` | `accelerator` is a reserved GPU label | Remove it from `--labels`; AKS sets it automatically |
| Node `Ready` but pods `Pending` on `nvidia.com/gpu` | Managed-driver PIS pool ships no device plugin | `kubectl apply -f manifests/nvidia-device-plugin.yaml` |
| Image still pulls slowly | Image not fully-qualified, so it wasn't cached | Use `docker.io/<repo>` in `--container-images`; make a new version |
| Pool attach fails `AllocationFailed` | H100 capacity, not quota | Retry, or move to a region/zone with available H100 capacity |

## Clean up

This pool was scaled to **2** nodes in step 5 — both H100 nodes bill until the
pool is deleted. Don't use `--no-wait` here, so you can confirm the (expensive)
nodes are actually gone before you walk away:

```bash
kubectl delete pod gpu-smoke gpu-smoke-new --ignore-not-found
az aks nodepool delete -g $RG --cluster-name $CLUSTER -n imgpool --subscription $SUB
az aks prepared-image-specification delete -g $RG --name image-prepared-image-specification --subscription $SUB --yes
```

(The device plugin DaemonSet is cluster-scoped; it's removed by the whole-RG
delete in the [top-level README](README.md#clean-up), or
`kubectl delete -f manifests/nvidia-device-plugin.yaml`.)

## Validation status

Validated on `Standard_NC40ads_H100_v5` (H100 NVL 94 GB), `westeurope` zone 3,
AKS 1.35.6, driver 580.159.04 / CUDA 13.0:

- PIS `image-prepared-image-specification` v1 cached the vLLM OpenAI image (9.74 GB). Measured with the
  `:latest` image at validation time; the codelab pins `v0.11.0` for
  reproducibility (image size / cache behavior are tag-independent).
- Bake + first node ready: **42m44s**.
- Image present in containerd. With `:latest` (`imagePullPolicy: Always`) the
  9.74 GB image "pull" was just a manifest check — **574 ms** (cold pull ≈ 130 s);
  with the pinned tag kubelet reports `already present on machine` and makes no
  registry call at all.
- GPU `nvidia-smi` ran in-pod on the H100 NVL after installing the device plugin.
- Scale-out 1 → 2: second node `Ready` in **438 s**, zero layer pull.

## Next

The examples are independent — try another, or combine them:

- [Example 1: Bake model weights onto NVMe](1-bake-model-weights.md)
- [Example 3: Bake a custom GPU driver](3-custom-gpu-driver.md)
- [Back to the codelab overview](README.md)

Don't forget to [clean up](#clean-up) the H100 pool when you're done.
