
In [0-install-gpu-driver-and-device-plugin.md](0-install-gpu-driver-and-device-plugin.md), we created an AKS cluster with an AMD GPU node pool, then installed the GPU driver and device plugin to make the GPU resources available to Kubernetes workloads. In this section, we will explore more advanced GPU capabilities.

# DRA for AMD GPU

Kubernetes Dynamic Resource Allocation (DRA) provides a structured way for workloads to request and consume specialized hardware such as AMD GPUs. Unlike traditional device plugin, DRA uses resource classes and claims to describe device requirements, allowing compatible drivers to prepare and assign devices to Pods with greater flexibility.
 
## Enable DRA Driver
The device-plugin is currently enabled by default if you follow the instructions in [0-install-gpu-driver-and-device-plugin.md](0-install-gpu-driver-and-device-plugin.md). Before switching allocation mechanisms, delete the long-running sample Pod with `kubectl delete pod amd-smi`. Then **disable** `device-plugin` and **enable** DRA.

Edit the `deviceconfigs` 
```bash
kubectl edit deviceconfigs -n kube-amd-gpu default
```

Set `draDriver.enable` to `true` and `devicePlugin.enableDevicePlugin` to `false`:

```yaml
apiVersion: amd.com/v1alpha1
kind: DeviceConfig
metadata:
  name: default
  namespace: kube-amd-gpu
spec:
  draDriver:
    enable: true # change to true 
    image: rocm/k8s-gpu-dra-driver:latest
  devicePlugin:
    enableDevicePlugin: false # change to false
```

Double check the `default-dra-driver` Pod is running.

```bash
kubectl get pod -n kube-amd-gpu
NAME                                                              READY   STATUS    RESTARTS   AGE
default-dra-driver-fvq6l                                          1/1     Running   0          2d
```

DRA Driver will automatically create `deviceclass` and `resourceslice` in your AKS. Verify these two objects exist

```bash
kubectl get deviceclass
NAME          AGE
gpu.amd.com   2d22h

kubectl get resourceslice
NAME                                                    NODE                            DRIVER        POOL                            AGE
00000-gpu.amd.com-aks-gpunp-14033257-vmss000000-jjmzj   aks-gpunp-14033257-vmss000000   gpu.amd.com   aks-gpunp-14033257-vmss000000   2d21h
```

## Create Workloads

Firstly, we define a `ResourceClaim` called `shared-gpu-claim`, it requests 1 GPU resource from the `deviceclass` `gpu.amd.com`

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  namespace: default
  name: shared-gpu-claim 
spec:
  devices:
    requests:
    - name: gpu
      exactly:
        deviceClassName: gpu.amd.com
        allocationMode: ExactCount
        count: 1
```

Then, we create two Pods, both of which claim the resource `shared-gpu-claim`.

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ctr0
    image: docker.io/rocm/pytorch:latest
    resources:
      claims:
      - name: gpu # This name must match the name in the `resourceClaims` list below
  resourceClaims:
  - name: gpu
    # Request the resource
    resourceClaimName: shared-gpu-claim

```

You can simply apply the yaml file [manifests/1-dra-multiple-pods-share.yaml](manifests/1-dra-multiple-pods-share.yaml).
```bash
kubectl apply -f manifests/1-dra-multiple-pods-share.yaml
```

Verify the two Pods are running.
```bash
kubectl get pods
NAME   READY   STATUS    RESTARTS   AGE
pod1   1/1     Running   0          17h
pod2   1/1     Running   0          17h
```

Check the logs and verify that the Pods are sharing the same GPU resource.

```bash
kubectl logs pod1
--- Pod 1 ---
GPU: 0
    BDF: 0008:00:00.0
    UUID: 690074b5-0000-1000-8062-1496304bd0ab
    KFD_ID: 32548
    NODE_ID: 8
    PARTITION_ID: 0

Pod 1 complete. Sleeping...

kubectl logs pod2
--- Pod 2 ---
GPU: 0
    BDF: 0008:00:00.0
    UUID: 690074b5-0000-1000-8062-1496304bd0ab
    KFD_ID: 32548
    NODE_ID: 8
    PARTITION_ID: 0

Pod 2 complete. Sleeping...
```


# Clean Up 

Delete the AKS cluster and ACR resource. 

```bash
az acr delete --subscription "$SUBSCRIPTION" --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --yes

az group delete --subscription "$SUBSCRIPTION" --name "$RESOURCE_GROUP" --yes --no-wait
```