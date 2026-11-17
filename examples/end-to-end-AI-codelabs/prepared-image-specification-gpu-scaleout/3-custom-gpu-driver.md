# Example 3: Bake a pinned custom GPU driver

**Goal:** Bake a specific NVIDIA driver version into the node image, have it
**survive the AKS node bootstrap**, and run GPU pods on it. **Time:** ~45 min.

AKS installs and manages a GPU driver for you (the default, and the simplest
choice). But if you need an *exact* driver version baked into the image — for
reproducibility, or to match a CUDA stack — you can bake it with PIS. This
example shows the current behavior on up-to-date node images, where a baked
driver survives a `--gpu-driver None` pool.

Complete the [shared one-time setup](README.md#one-time-setup) first.

## Pick a driver version that *builds* on the node's kernel

> ⚠️ **Check your kernel before you bake — a mismatch is the expected case, not
> the exception.** A custom GPU driver is compiled against the running kernel, and
> AKS patches node images frequently, so a cluster you create today will very
> likely run a *newer* kernel than the `6.8.0-1073-azure` this example was pinned
> to — and there is no supported way to pin the exact node-image kernel. The
> pinned `595.91.07` is **not guaranteed to build** on a different kernel. **Stop
> and check first:**
>
> ```bash
> kubectl get nodes -o wide   # look at the KERNEL-VERSION column
> ```
>
> If it is **not** `6.8.0-1073-azure`, pick a driver that matches *your* kernel
> and test it on a throwaway VM with that exact kernel **before** baking (the bake
> is a ~25-minute feedback loop). The rest of this example still applies, but you
> must update **`DRIVER_VERSION`, its download URL, and `DRIVER_SHA256` together**
> in the script — it verifies the checksum under `set -e`, so a stale
> `DRIVER_SHA256` aborts the bake before the new driver installs.

Why `595.91.07` and not older branches: `570.x` / `580.95` **fail to compile** on
`6.8.0-1073-azure` — the Azure kernel backported a 4-argument `pci_resize_resource`
and those drivers' conftests only know the 3-arg form (`nv-pci.c: too few
arguments to function 'pci_resize_resource'`). `595.91.07` builds and supports
H100 (Hopper).

> A compile-free alternative that sidesteps the conftest wall is Canonical's
> precompiled modules (`linux-modules-nvidia-595-server-open-<kernel>-azure` +
> `nvidia-driver-595-server-open`) — these are built per kernel ABI, so they dodge
> the build problem entirely.
>
> The bake also needs outbound HTTPS from the build VM to
> `us.download.nvidia.com` (the `.run` download); an egress-restricted
> subscription will fail the driver bake.

## 1. The customization script

[`scripts/customize-driver.sh`](scripts/customize-driver.sh) installs `595.91.07`
via the `.run --dkms` installer into the **standard root**, and adds a
`modules-load.d` entry so the modules reload after a reboot. It does **not** need
any `rm dkms-marker` workaround — on a current VHD the marker is already absent.

## 2. Create the PIS and attach a `--gpu-driver None` pool

```bash
jq -n --arg s "$(cat scripts/customize-driver.sh)" \
  '[{name:"bake-custom-driver",script:$s,scriptType:"Bash",
     executionPoint:"NodeImageBuildTime",postScriptAction:"None"}]' > driver-scripts.json

az aks prepared-image-specification create \
  -g $RG --subscription $SUB --name driver-prepared-image-specification --location $LOC --version v1 \
  --customization-scripts @driver-scripts.json
```

Grant the cluster identity **Reader** on `driver-prepared-image-specification` (see
[the grant](README.md#the-pis-read-permission-grant)).

```bash
PIS_VER_ID=$(az aks prepared-image-specification version show -g $RG \
  --subscription $SUB --pis-name driver-prepared-image-specification --name v1 --query id -o tsv)

az aks nodepool add -g $RG --cluster-name $CLUSTER --subscription $SUB \
  --name driverpool --mode User \
  --node-count 1 --node-vm-size $GPU_SKU --zones $ZONE \
  --gpu-driver None \
  --prepared-image-specification-id "$PIS_VER_ID"
```

The bake took **~27 min** in this run (driver only, no model/image).

## 3. Verify the baked driver survived the bootstrap

```bash
MCRG="MC_${RG}_${CLUSTER}_${LOC}"
VMSS=$(az vmss list -g $MCRG --subscription $SUB \
  --query "[?contains(name,'driverpool') && !starts_with(name,'pis')].name" -o tsv)
az vmss run-command invoke -g $MCRG -n "$VMSS" --subscription $SUB \
  --command-id RunShellScript --instance-id 0 \
  --scripts 'nvidia-smi --query-gpu=name,driver_version --format=csv,noheader;
             dkms status | head;
             ls -la /opt/azure/aks-gpu/dkms-marker 2>&1 | tail -1;
             grep -iE "cleanUpPrebakedGPUDriver|AKS_GPU_PREBAKE|Removing pre-baked" \
               /var/log/azure/cluster-provision*.log | tail -5' \
  --query "value[0].message" -o tsv
```

**Checkpoint — what you should see:**

```text
NVIDIA H100 NVL, 595.91.07
nvidia/595.91.07, 6.8.0-1073-azure, x86_64: installed
ls: cannot access '/opt/azure/aks-gpu/dkms-marker': No such file or directory
# cleanUpGPUDrivers ran but printed NO "Removing pre-baked" / teardown line
```

The driver is your pinned `595.91.07`, the marker is absent, and the destructive
teardown never fired — **no workaround required.**

## 4. Make the node schedulable with the GPU Operator (`driver.enabled=false`)

A `--gpu-driver None` node has your driver but **no** container toolkit, device
plugin, or containerd nvidia runtime. The supported way to supply those *without*
installing a second driver is the **NVIDIA GPU Operator with
`driver.enabled=false`** — it uses your baked host driver.

The GPU Operator must stay off any **managed** GPU pool (Examples 1–2) in the same
cluster — otherwise its device plugin/toolkit collide with AKS's managed GPU
stack. Examples 1–2 already set `nvidia.com/gpu.deploy.operands=false` on their
pools at creation, so the Operator skips them automatically. The loop below is a
safety net that (re-)applies the label to any managed pool that's missing it —
it's a no-op if they already have it:

```bash
for POOL in imgpool modelpool; do
  az aks nodepool show -g $RG --cluster-name $CLUSTER -n $POOL --subscription $SUB >/dev/null 2>&1 \
    && az aks nodepool update -g $RG --cluster-name $CLUSTER -n $POOL --subscription $SUB \
         --labels nvidia.com/gpu.deploy.operands=false
done

helm repo add nvidia https://nvidia.github.io/gpu-operator 2>/dev/null; helm repo update
helm install gpu-operator nvidia/gpu-operator -n gpu-operator --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true \
  --wait --timeout 15m
```

> The loop only covers pools that **exist now**. If you create a managed pool
> *after* installing the Operator, label it then too (Examples 1–2 do this at pool
> creation), so the Operator never lands on a managed node.

**Checkpoint:** the operator validators go green and the node advertises a GPU:

```bash
kubectl -n gpu-operator get pods | grep -E "validator|device-plugin|toolkit"
kubectl get nodes -l agentpool=driverpool \
  -o jsonpath='{.items[0].status.allocatable.nvidia\.com/gpu}'   # -> 1
```

## 5. Run a GPU pod on the pinned driver

```bash
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: gpu-custom
  labels: { app: gpu-custom }
spec:
  restartPolicy: Never
  nodeSelector: { agentpool: driverpool }
  containers:
    - name: smi
      image: nvcr.io/nvidia/cuda:12.6.2-base-ubuntu24.04
      command: ["nvidia-smi"]
      resources:
        requests: { cpu: 250m, memory: 256Mi }
        limits: { cpu: 500m, memory: 512Mi, nvidia.com/gpu: 1 }
YAML
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gpu-custom --timeout=180s
kubectl logs gpu-custom | grep -E "Driver Version|H100"
```

**Checkpoint:**

```text
| NVIDIA-SMI 595.91.07   Driver Version: 595.91.07   CUDA Version: 13.2 |
|   0  NVIDIA H100 NVL ...
```

The pod runs on your pinned **595.91.07** — not AKS's managed driver. (The CUDA
version `nvidia-smi` prints is the *driver's* maximum supported CUDA, not the
toolkit in the container — so it can differ from the managed-driver node in
Example 2, which is expected.)

> **Note:** your wiki/past runs on older containerd needed a manual
> `/etc/containerd/conf.d` import fix for the Operator's nvidia runtime. On the
> node image used here (containerd **2.3.7** + current toolkit) that was **not
> needed** — the `nvidia-cuda-validator` completed without any containerd edit.

## Troubleshoot

| Symptom | Cause | Fix |
|---|---|---|
| Bake fails, `too few arguments to function 'pci_resize_resource'` | Driver branch too old for the kernel | Use `595.91.07`+, or Canonical precompiled `linux-modules-nvidia-*-azure` |
| After boot, `nvidia-smi` gone / no driver | Baked under `/usr/local/nvidia` or `/opt/gpu`, or VHD carried the marker | Install into the **standard root**; verify `dkms-marker` is absent |
| Pod `no runtime for "nvidia"` | Operator runtime drop-in not imported (older containerd) | Add `imports = ["/etc/containerd/conf.d/*.toml"]` to `config.toml`, reconcile `version`, restart containerd |
| Operator installs its own driver | `driver.enabled` left true | Set `--set driver.enabled=false` so it uses your host driver |

## Clean up

```bash
kubectl delete pod gpu-custom --ignore-not-found
helm uninstall gpu-operator -n gpu-operator 2>/dev/null || true
kubectl delete ns gpu-operator --ignore-not-found
# drop --no-wait so you can confirm the (billable) H100 node is actually gone:
az aks nodepool delete -g $RG --cluster-name $CLUSTER -n driverpool --subscription $SUB
az aks prepared-image-specification delete -g $RG --name driver-prepared-image-specification --subscription $SUB --yes
```

> **If you're keeping Examples 1–2's pools** (not deleting the whole RG), also
> remove the `nvidia.com/gpu.deploy.operands=false` label you set on them, e.g.
> `kubectl label node -l agentpool=imgpool nvidia.com/gpu.deploy.operands-`
> (the `key-` suffix deletes a single label reliably; `az aks nodepool update
> --labels ""` behavior varies by CLI version and would replace the pool's whole
> label set).
>
> The quickest, most reliable teardown is still the whole-resource-group delete
> in the [top-level README](README.md#clean-up) — it removes the node resource
> group, any leftover PIS build VM, the device plugin, and the GPU Operator in one
> shot (and makes the label cleanup moot).

## Validation status

Validated on `Standard_NC40ads_H100_v5` (H100 NVL 94 GB), `westeurope` zone 3,
AKS 1.35.6, kernel `6.8.0-1073-azure`, containerd 2.3.7:

- PIS `driver-prepared-image-specification` baked NVIDIA `595.91.07` (`.run --dkms`, standard root).
- Bake + node ready: **26m56s**.
- On the `--gpu-driver None` node: `nvidia-smi` → H100 NVL `595.91.07`, DKMS
  `installed`, `/opt/azure/aks-gpu/dkms-marker` **absent**, `cleanUpGPUDrivers`
  ran with no teardown — **no workaround**.
- GPU Operator `driver.enabled=false` made the node schedulable; a GPU pod ran
  `nvidia-smi` reporting **Driver Version 595.91.07 / CUDA 13.2**.
- No `/etc/containerd/conf.d` import fix was required on this toolkit/containerd.

## Next

The examples are independent — try another, or combine them:

- [Example 1: Bake model weights onto NVMe](1-bake-model-weights.md)
- [Example 2: Pre-cache a container image](2-precache-container-image.md)
- [Back to the codelab overview](README.md)

Don't forget to [clean up](#clean-up) the H100 pool and GPU Operator when you're done.
