
# Advanced Examples

## DRA for AMD GPU

Kubernetes Dynamic Resource Allocation (DRA) provides a structured way for workloads to request and consume specialized hardware such as AMD GPUs. Unlike traditional extended resources, DRA uses resource classes and claims to describe device requirements, allowing compatible drivers to prepare and assign devices to Pods with greater flexibility.


```bash
kubectl edit deviceconfigs -n kube-amd-gpu default
```

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
  selector:
    feature.node.kubernetes.io/amd-gpu: "true"
```

```bash
kubectl get pod -n kube-amd-gpu
NAME                                                              READY   STATUS    RESTARTS   AGE
default-dra-driver-fvq6l                                          1/1     Running   0          2d
```

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  namespace: default
  name: shared-gpu-claim # A distinct name for the shared claim
spec:
  devices:
    requests:
    - name: gpu
      exactly:
        deviceClassName: gpu.amd.com
        allocationMode: ExactCount
        count: 1
```