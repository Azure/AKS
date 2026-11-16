# Example 1: Bake model weights onto local NVMe

**Goal:** Bake a 15 GB model checkpoint into the node image and have it land on
the node's fast **local NVMe**, so inference pods load weights from local disk
instead of downloading them over the network at startup. **Time:** ~50 min
(mostly the one-time bake).

Large-model nodes normally download tens of GB of weights at startup. With PIS
the weights are already on disk when the node boots — but *where* on disk matters
a lot. This example shows how to get them onto the fast NVMe automatically.

Complete the [shared one-time setup](README.md#one-time-setup) first.

## The storage gotcha (why this example is more than "just bake the files")

A GPU node has more than one disk, and they are **not** equally fast:

| Device | Role | Cold sequential read |
|---|---|---|
| OS disk on the **CacheDisk** | default ephemeral/managed OS disk | host-cache-bound (hundreds of MB/s at best, far less uncached) |
| Local **NVMe** | `Standard_NC40ads_H100_v5` ships ~3.5 TB of it | **~1.0 GB/s cold, ~7.9 GB/s warm** |

If the baked weights sit on the slow OS disk, a cold read can erase the benefit
of skipping the download. You want them on the **NVMe**.

**The good news on this SKU:** `Standard_NC40ads_H100_v5` advertises `NvmeDisk`
in its supported ephemeral-OS-disk placements. So if you ask for an **Ephemeral
OS disk larger than the cache disk**, AKS places the *entire OS disk* — and
therefore the baked weights on it — on the NVMe automatically. **No mount script,
no `fstab` edits.**

An Ephemeral OS disk is local and not persisted: its contents are re-created from
the prepared VHD on every boot (that's exactly what you want here — the baked
weights reappear on each node), but anything written at runtime is lost on
reimage/deallocate. For read-only baked weights this is ideal.

> This differs from some earlier GPU SKUs (e.g. `NC24ads_A100_v4`) that do **not**
> advertise `NvmeDisk`. On those, a large Ephemeral OS disk is rejected and you
> must mount the NVMe (`/dev/nvme0n1`) explicitly in a boot-time script. Check
> your SKU's placements **and its cache size** before choosing the OS-disk size:
>
> ```bash
> az vm list-skus -l $LOC --subscription $SUB --size $GPU_SKU \
>   --query "[0].capabilities[?name=='SupportedEphemeralOSDiskPlacements' || name=='CachedDiskBytes']"
> ```
>
> You need `NvmeDisk` in the placements, and an OS-disk size **larger than
> `CachedDiskBytes`** (and the temp disk) to force NVMe placement. On
> `NC40ads_H100_v5` the cache is ~322 GB, so this codelab uses 400 GB — size
> above *your* SKU's reported cache, don't assume 400 GB is enough.

## 1. The customization script

[`scripts/customize-model.sh`](scripts/customize-model.sh) runs at
`NodeImageBuildTime` and downloads the weights into `/opt/models/qwen`. Three
things it gets right that commonly break a bake:

- The node image ships `python3` but **not** the `venv` module, so it installs
  `python3-venv` first (otherwise `python3 -m venv` fails with
  `ensurepip is not available` and the bake fast-fails in ~2 min).
- Ubuntu 24.04 is **PEP-668** managed, so it installs into a **venv** rather than
  `pip install` into the system Python.
- `huggingface_hub` 1.x dropped the `[cli]` extra and the `huggingface-cli`
  command, so it uses the current **`hf download`** CLI — with **no trailing
  positional arguments** (those are treated as filenames).

> **Prerequisites for the bake:** the build VM needs outbound HTTPS to
> `huggingface.co`. This example uses a **public** model
> (`Qwen/Qwen2.5-7B-Instruct`) and is intentionally credential-free. Hugging Face
> rate-limiting can fail a bake late (after ~35 min of work), so pin a specific
> model revision for repeatable results.
>
> **Gated/private models — do not inline a token.** The customization script runs
> with `set -x` and is serialized verbatim into the PIS resource, so an inline
> `HF_TOKEN`/`--token` would leak into build logs and the stored spec. If you must
> pull a gated model, fetch the token at bake time from a secret store (e.g. an
> IMDS-authenticated call to Key Vault) with tracing disabled around it
> (`set +x` … `set -x`), and don't persist it to disk or the marker.

## 2. Create the PIS

```bash
# Build the scripts payload (array of script objects)
jq -n --arg s "$(cat scripts/customize-model.sh)" \
  '[{name:"bake-qwen-weights",script:$s,scriptType:"Bash",
     executionPoint:"NodeImageBuildTime",postScriptAction:"None"}]' > model-scripts.json

az aks prepared-image-specification create \
  -g $RG --subscription $SUB --name model-prepared-image-specification --location $LOC --version v1 \
  --container-images docker.io/vllm/vllm-openai:v0.11.0 \
  --customization-scripts @model-scripts.json
```

(The vLLM image is cached too, so this node can also *serve* the baked model.)

Grant the cluster identity **Reader** on `model-prepared-image-specification` (see
[the grant](README.md#the-pis-read-permission-grant)).

## 3. Attach a GPU pool with an NVMe-sized Ephemeral OS disk

The key flags are `--node-osdisk-type Ephemeral` and a size **larger than the
cache disk** (the cache on this SKU is ~322 GB, so 400 GB forces NVMe placement):

```bash
PIS_VER_ID=$(az aks prepared-image-specification version show -g $RG \
  --subscription $SUB --pis-name model-prepared-image-specification --name v1 --query id -o tsv)

az aks nodepool add -g $RG --cluster-name $CLUSTER --subscription $SUB \
  --name modelpool --mode User \
  --node-count 1 --node-vm-size $GPU_SKU --zones $ZONE \
  --node-osdisk-type Ephemeral --node-osdisk-size 400 \
  --prepared-image-specification-id "$PIS_VER_ID"
```

The bake takes ~35–40 min (the 15 GB download dominates). In this run: **~38 min**.

**Checkpoint — confirm the OS disk landed on NVMe:**

```bash
MCRG="MC_${RG}_${CLUSTER}_${LOC}"
VMSS=$(az vmss list -g $MCRG --subscription $SUB \
  --query "[?contains(name,'modelpool') && !starts_with(name,'pis')].name" -o tsv)
az vmss show -g $MCRG -n "$VMSS" --subscription $SUB \
  --query "virtualMachineProfile.storageProfile.osDisk.diffDiskSettings" -o json
# expected: { "option": "Local", "placement": "NvmeDisk" }
```

## 4. Confirm the weights are present and fast

```bash
az vmss run-command invoke -g $MCRG -n "$VMSS" --subscription $SUB \
  --command-id RunShellScript --instance-id 0 \
  --scripts 'du -sh /opt/models/qwen; ls /opt/models/qwen | head;
             F=$(ls /opt/models/qwen/*.safetensors | head -1);
             sync; echo 3 > /proc/sys/vm/drop_caches;
             dd if="$F" of=/dev/null bs=8M 2>&1 | tail -1' \
  --query "value[0].message" -o tsv
```

**Checkpoint:** `/opt/models/qwen` is ~15 GB with all four safetensors shards,
and the cold buffered read is ~1.0 GB/s.

> **Note on measuring disk speed:** use a *buffered* read (as above). A single
> `dd ... iflag=direct bs=1M` stream reports a misleadingly low number
> (~26 MB/s here) because it defeats read-ahead — it is not what the model loader
> experiences.

## 5. Serve the baked model (zero network)

Make the node schedulable (device plugin, same as Example 2), then run vLLM
against the baked weights via a `hostPath` mount:

```bash
# The shared device-plugin manifest is scoped (by nodeAffinity) to the
# imgpool/modelpool names used in this codelab; it makes modelpool schedulable.
kubectl apply -f manifests/nvidia-device-plugin.yaml   # if not already applied

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vllm-model
  labels: { app: vllm-model }
spec:
  restartPolicy: Never
  nodeSelector: { agentpool: modelpool }
  containers:
    - name: vllm
      image: docker.io/vllm/vllm-openai:v0.11.0
      imagePullPolicy: IfNotPresent
      args: ["--model","/models/qwen","--served-model-name","qwen",
             "--gpu-memory-utilization","0.9","--max-model-len","4096"]
      ports: [{ containerPort: 8000 }]
      volumeMounts: [{ name: models, mountPath: /models, readOnly: true }]
      resources:
        requests: { cpu: "2", memory: 8Gi }
        limits: { cpu: "8", memory: 32Gi, nvidia.com/gpu: 1 }
  volumes:
    - name: models
      # read-only host mount of the baked weights; nothing writes to it
      hostPath: { path: /opt/models, type: Directory }
YAML

# wait until the container is actually running, otherwise `logs -f` can exit
# with PodInitializing/ContainerCreating before vLLM prints anything:
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vllm-model --timeout=300s
kubectl logs -f vllm-model | grep -iE "Loading weights took|Model loading took"
```

**Checkpoint** (your exact numbers will vary; the point is the order of magnitude
and "zero network"):

```text
Loading weights took ~15 seconds
Model loading took ~14 GiB memory and ~30 seconds
```

The 15 GB checkpoint loads from the baked NVMe disk in **~15 s with zero network
traffic** (we measured 15.31 s). (Total time to `/health` is longer, but that
extra time is vLLM's `torch.compile` / CUDA-graph capture — model-and-framework
specific, unrelated to PIS.)

## Troubleshoot

| Symptom | Cause | Fix |
|---|---|---|
| Bake fast-fails ~2 min, `ensurepip is not available` | Node image has no `venv` module | `apt-get install -y python3-venv` at the top of the script (the sample does this) |
| Bake fails `externally-managed-environment` | Ubuntu 24.04 PEP-668 | Install into a venv (the sample does this) |
| `hf download` fails `File not found .../original/*` | Trailing positionals parsed as filenames | Use `hf download REPO --local-dir DIR` only |
| `VMCannotFitEphemeralOSDisk` | SKU doesn't advertise `NvmeDisk`, or size < cache | Use an NVMe-capable SKU, or mount `/dev/nvme0n1` in a boot script instead |
| `diffDiskSettings` shows `CacheDisk`, load is slow | OS disk small enough to fit the cache | Increase `--node-osdisk-size` above the cache size to force NVMe |
| On bake failure, where are the logs? | AKS **deallocates** (not deletes) the build VM | `az vmss start -g <MCRG> -n pismodelpool --instance-ids 0`, then `run-command` to read `/var/lib/waagent/.../pis-script-0/0/std{out,err}` |

## Clean up

Don't use `--no-wait` on the pool delete, so you can confirm the (expensive) H100
node is actually gone before you walk away:

```bash
kubectl delete pod vllm-model --ignore-not-found
az aks nodepool delete -g $RG --cluster-name $CLUSTER -n modelpool --subscription $SUB
az aks prepared-image-specification delete -g $RG --name model-prepared-image-specification --subscription $SUB --yes
```

(If you applied it, the device-plugin DaemonSet is cluster-scoped — remove it with
`kubectl delete -f manifests/nvidia-device-plugin.yaml`, or let the whole-RG
delete in the [top-level README](README.md#clean-up) take it.)

## Validation status

Validated on `Standard_NC40ads_H100_v5` (H100 NVL 94 GB), `westeurope` zone 3,
AKS 1.35.6, kernel `6.8.0-1073-azure`:

- PIS `model-prepared-image-specification` baked `Qwen/Qwen2.5-7B-Instruct` (~15 GB) + cached the vLLM image.
- Bake + node ready: **38m3s**.
- `--node-osdisk-type Ephemeral --node-osdisk-size 400` →
  `diffDiskSettings = { option: Local, placement: NvmeDisk }` (OS disk on NVMe,
  **no mount script**).
- Baked weights present (15 GB, 4 shards); cold buffered read **1.0 GB/s**, warm
  **7.9 GB/s**.
- vLLM cold weight-load from the baked NVMe disk: **15.31 s**, zero network.
- The baked vLLM image was `already present on machine` (zero image pull).

## Next

The examples are independent — try another, or combine them:

- [Example 2: Pre-cache a container image](2-precache-container-image.md)
- [Example 3: Bake a custom GPU driver](3-custom-gpu-driver.md)
- [Back to the codelab overview](README.md)

Don't forget to [clean up](#clean-up) the H100 pool when you're done.
