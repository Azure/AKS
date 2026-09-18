
This document creates an AKS cluster with one  
`Standard_ND96isr_MI300X_v5` node, and install [AMD GPU Operator](https://github.com/ROCm/gpu-operator) to build and deploy the AMD driver.

# Prerequisites
- Azure subscription with `az login` completed, permission to create AKS clusters and ACR.
- Azure CLI ≥ 2.85.0.
- kubectl and Helm 3 installed.
- [`Standard_ND96isr_MI300X_v5`](https://learn.microsoft.com/azure/virtual-machines/sizes/gpu-accelerated/ndmi300xv5-series) quota in this subscription. 


**Before you begin**

Define the following environment variables:

| Variable name | Description | Example value |
|---|---|---|
| `SUBSCRIPTION` | Azure subscription ID | `00000000-0000-0000-0000-000000000000` |
| `LOCATION` | Azure region in which to create the resources | `francecentral` |
| `RESOURCE_GROUP` | Name of the Azure resource group | `amd_gpu_test` |
| `AKS_NAME` | Name of the AKS cluster | `aks-amd-gpu-test` |
| `GPU_POOL` | Name of the AKS GPU node pool | `gpunp` |
| `ACR_NAME` | Name of the Azure Container Registry | `amdmi300test` |
| `ACR_REPOSITORY` | ACR repository for the AMD GPU driver image | `amd/amdgpu-kmod` |

# Create AKS Cluster 

In the following steps, you create the Azure resource group, deploy an AKS cluster, and add a dedicated GPU node pool for the `MI300X` VM size with no GPU driver installed. By the end of this section, you should have a running AKS cluster with at least one GPU-capable node available for the AMD GPU Operator.

```bash
az group create \
--subscription "$SUBSCRIPTION" \
--name "$RESOURCE_GROUP" \
--location "$LOCATION"


az aks create \
--subscription "$SUBSCRIPTION" \
--resource-group "$RESOURCE_GROUP" \
--name "$AKS_NAME" \
--location "$LOCATION" \
--generate-ssh-keys


az aks nodepool add \
--subscription "$SUBSCRIPTION" \
--resource-group "$RESOURCE_GROUP" \
--cluster-name "$AKS_NAME" \
--name "$GPU_POOL" \
--node-count 1 \
--node-vm-size Standard_ND96isr_MI300X_v5 \
--gpu-driver none
```

Get the AKS cluster 
```bash
 az aks get-credentials --admin \
    --subscription "${SUBSCRIPTION}" \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_NAME}" \
    --overwrite-existing
```

Confirm that the nodes are ready before installing the GPU Operator:

```bash
kubectl get node

NAME                                STATUS   ROLES    AGE    VERSION
aks-gpunp-14033257-vmss000000       Ready    <none>   2d1h   v1.35.7
aks-nodepool1-16790056-vmss000000   Ready    <none>   2d1h   v1.35.7
aks-nodepool1-16790056-vmss000001   Ready    <none>   2d1h   v1.35.7
aks-nodepool1-16790056-vmss000002   Ready    <none>   2d1h   v1.35.7
```

# Create ACR and grant AKS pull access

Create an Azure Container Registry (ACR) to store the AMD GPU driver image, then attach the registry to the AKS cluster so its managed identity can pull images from it. Finally, retrieve the registry login server and save it in `ACR_SERVER` for use in the following steps.


```bash
az acr create \
--subscription "$SUBSCRIPTION" \
--resource-group "$RESOURCE_GROUP" \
--name "$ACR_NAME" \
--sku Premium


az aks update \
--subscription "$SUBSCRIPTION" \
--resource-group "$RESOURCE_GROUP" \
--name "$AKS_NAME" \
--attach-acr "$ACR_NAME"
  

ACR_SERVER=$(az acr show \
--subscription "$SUBSCRIPTION" \
--name "$ACR_NAME" \
--query loginServer -o tsv)
```

# Configure ACR credentials

Create a repository-scoped token that allows the AMD GPU Operator to read and write the driver image in ACR. Then generate a token password and save it in `ACR_PASSWORD` for creating the Kubernetes registry secret.

```bash
az acr scope-map create \
--subscription "$SUBSCRIPTION" \
--registry "$ACR_NAME" \
--name amd-driver-scope \
--repository "$ACR_REPOSITORY" \
content/read content/write metadata/read metadata/write


az acr token create \
--subscription "$SUBSCRIPTION" \
--registry "$ACR_NAME" \
--name amd-gpu-operator \
--scope-map amd-driver-scope


ACR_PASSWORD=$(az acr token credential generate \
--subscription "$SUBSCRIPTION" \
--registry "$ACR_NAME" \
--name amd-gpu-operator \
--query 'passwords[0].value' -o tsv)
```

# Add the secret configmap

Create the `kube-amd-gpu` namespace, then add a Kubernetes image pull secret that the AMD GPU Operator can use to authenticate with ACR when building and deploying the driver image.

```
kubectl create namespace kube-amd-gpu 

kubectl create secret docker-registry amd-driver-registry \
--namespace kube-amd-gpu \
--docker-server="$ACR_SERVER" \
--docker-username=amd-gpu-operator \
--docker-password="$ACR_PASSWORD"
```

# Install cert-manager and AMD GPU Operator
Install cert-manager to manage the TLS certificates required by the AMD GPU Operator webhooks. Then add the AMD ROCm Helm repository and install the GPU Operator, configuring it to build and deploy the AMD driver from ACR and target the MI300X VF-passthrough node.


```bash
helm repo add jetstack https://charts.jetstack.io --force-update

helm install cert-manager jetstack/cert-manager \
--namespace cert-manager \
--create-namespace \
--version v1.15.1 \
--set crds.enabled=true

helm repo add rocm https://rocm.github.io/gpu-operator

helm repo update

helm install amd-gpu-operator rocm/gpu-operator-charts \
--namespace kube-amd-gpu \
--create-namespace \
--version v1.5.1 \
--set deviceConfig.spec.driver.enable=true \
--set deviceConfig.spec.driver.blacklist=true \
--set deviceConfig.spec.driver.version=6.4 \
--set deviceConfig.spec.driver.image="$ACR_SERVER/$ACR_REPOSITORY" \
--set deviceConfig.spec.driver.imageRegistrySecret.name=amd-driver-registry \
--set-json 'deviceConfig.spec.selector={"feature.node.kubernetes.io/amd-gpu":null,"feature.node.kubernetes.io/amd-vgpu":"true"}'
```


> The `"feature.node.kubernetes.io/amd-vgpu":"true"}` selector is required for Azure's MI300X VF-passthrough node.

# Verify that the operator is running and GPUs are schedulable

Verify that the `device-plugin` pod is running:

```bash
kubectl get pods -n kube-amd-gpu
default-device-plugin-jv9dr                                       1/1     Running   0          85s
```

# Run a sample workload 
```yaml
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: amd-smi
spec:
  restartPolicy: Never
  containers:
  - name: amd-smi
    image: rocm/rocm-terminal:latest
    command: ["/bin/bash", "-c"]
    args: ["amd-smi version && amd-smi monitor -ptum"]
    resources:
      requests:
        amd.com/gpu: 8
      limits:
        amd.com/gpu: 8
EOF
```

Inspect the `amd-smi` logs to confirm that all GPU accelerators are available (the `MI300X` VM size offers 8 GPU devices):

```
kubectl logs amd-smi

AMDSMI Tool: 25.3.0+ede62f2 | AMDSMI Library version: 25.3.0 | ROCm version: 6.4.0 | amdgpu version: 6.12.12 | amd_hsmp version: N/A
WARNING: User is missing the following required groups: render. Please add user to these groups.
GPU  POWER   GPU_T   MEM_T   GFX_CLK   GFX%   MEM%  MEM_CLOCK
  0  140 W   39 °C   33 °C   204 MHz    0 %    0 %    903 MHz
  1  145 W   36 °C   34 °C   190 MHz    0 %    0 %    900 MHz
  2  140 W   38 °C   32 °C   172 MHz    0 %    0 %    901 MHz
  3  141 W   38 °C   33 °C   192 MHz    0 %    0 %    901 MHz
  4  142 W   35 °C   32 °C   190 MHz    0 %    0 %    903 MHz
  5  148 W   40 °C   32 °C   174 MHz    0 %    0 %    901 MHz
  6  138 W   37 °C   32 °C   175 MHz    0 %    0 %    900 MHz
  7  138 W   37 °C   32 °C   183 MHz    0 %    0 %    902 MHz
```

# Clean Up 

Delete the AKS cluster and ACR resource. 

```bash
az acr delete --subscription "$SUBSCRIPTION" --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --yes

az group delete --subscription "$SUBSCRIPTION" --name "$RESOURCE_GROUP" --yes --no-wait
```