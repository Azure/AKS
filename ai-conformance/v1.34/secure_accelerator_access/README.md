**MUST Requirement:** Ensure that access to accelerators from within containers is properly isolated and mediated by the Kubernetes resource management framework (device plugin or DRA) and container runtime, preventing unauthorized access or interference between workloads.

## Tests Executed
### Test 1: Ensure that access to accelerators from within containers mediated by the Kubernetes resource management framework (device plugin or DRA) and container runtime.

#### Step 1. Create a 1.34 AKS cluster

```bash
az aks create --resource-group <resource-group> --name <cluster-name> -k 1.34.0 --no-ssh
```

#### Step 2. Add a GPU node pool and skip installing the default driver

```bash
az aks nodepool add --resource-group <resource-group> --cluster-name <cluster-name> \
 --name gpupool --gpu-driver None -c 1 -s standard_nc96ads_a100_v4
```

#### Step 3. Install the NVIDIA GPU operator and install the NVIDIA DRA driver

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>

helm install gpu-operator gpu-operator --repo https://helm.ngc.nvidia.com/nvidia \
 --version v25.3.3 -n gpu-operator --create-namespace --set devicePlugin.enabled=false --set-string 'toolkit.env[0].name=ACCEPT_NVIDIA_VISIBLE_DEVICES_ENVVAR_WHEN_UNPRIVILEGED,toolkit.env[0].value=false'

helm install nvidia-dra-driver-gpu oci://ghcr.io/nvidia/k8s-dra-driver-gpu --version 25.8.0-dev-13a73595-chart \
 -n k8s-dra-driver-gpu --create-namespace -f <(cat <<EOF
controller:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.azure.com/mode
            operator: In
            values:
            - system
gpuResourcesEnabledOverride: true
nvidiaDriverRoot: /run/nvidia/driver
EOF
)
```

#### Step 4. Confirm that the DRA driver pods are running

```bash
kubectl get pods -n k8s-dra-driver-gpu
```

Output:

```output
NAME                                               READY   STATUS    RESTARTS   AGE
nvidia-dra-driver-gpu-controller-b8cd996fc-b46v6   1/1     Running   0          3m53s
nvidia-dra-driver-gpu-kubelet-plugin-wgxg5         2/2     Running   0          3m53s
```

#### Step 5. Create a resource claim template and a deployment that requests the GPU resource

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: gpu-claim-template
spec:
  spec:
    devices:
      requests:
      - name: single-gpu
        exactly:
          deviceClassName: gpu.nvidia.com
          allocationMode: ExactCount
          count: 1
```

Update the deployment to request a resource:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pytorch-cuda-check
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pytorch-cuda-check
  template:
    metadata:
      labels:
        app: pytorch-cuda-check
    spec:
      containers:
        - name: pytorch-cuda-check
          image: nvcr.io/nvidia/pytorch:25.09-py3
          command: ["/bin/sh", "-c"]
          args:
            - |
              while true; do
                python3 -c "import torch; print(torch.cuda.device_count())"
                sleep 30
              done
          resources:
            claims:
              - name: single-gpu
      resourceClaims:
        - name: single-gpu
          resourceClaimTemplateName: gpu-claim-template
```

Observe that the deployment is running:

```bash
kubectl get pods -w
```

Output:

```output                                    
NAME                                  READY   STATUS    RESTARTS   AGE
pytorch-cuda-check-64f4757498-stx82   1/1     Running   0          4m12s
```


#### Step 6. Update the Deployment to remove the resource claim request in the Pod spec, the command in the container should fail.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pytorch-cuda-check
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pytorch-cuda-check
  template:
    metadata:
      labels:
        app: pytorch-cuda-check
    spec:
      containers:
        - name: pytorch-cuda-check
          image: nvcr.io/nvidia/pytorch:25.09-py3
          command: ["/bin/sh", "-c"]
          args:
            - |
              while true; do
                python3 -c "import torch; print(torch.cuda.device_count())"
                sleep 30
              done
          # resources:
          #   claims:
          #     - name: single-gpu
      resourceClaims:
        - name: single-gpu
          resourceClaimTemplateName: gpu-claim-template
```

Retrieve the logs, they should show a failure:

```bash
kubectl logs pytorch-cuda-check-64f4757498-n82f6
```

Output:

```output
/usr/local/lib/python3.12/dist-packages/torch/cuda/__init__.py:63: FutureWarning: The pynvml package is deprecated. Please install nvidia-ml-py instead. If you did not install pynvml directly, please report this to the maintainers of the package that installed pynvml for you.
  import pynvml  # type: ignore[import]
0
```

### Test 2: Ensure that access to accelerators from within containers is properly isolated.

#### Step 1. Create two Pods, each is allocated an accelerator resource. Execute a command in one Pod to attempt to access the other Pod’s accelerator, and should be denied

This can be verified by running this test [https://github.com/kubernetes/kubernetes/blob/v1.34.1/test/e2e/dra/dra.go#L180](https://github.com/kubernetes/kubernetes/blob/v1.34.1/test/e2e/dra/dra.go#L180) 

With a 1.34 AKS cluster:

```
% make WHAT="github.com/onsi/ginkgo/v2/ginkgo k8s.io/kubernetes/test/e2e/e2e.test" && KUBERNETES_PROVIDER=local hack/ginkgo-e2e.sh -ginkgo.focus='must map configs and devices to the right containers'
go: downloading go1.24.6 (darwin/arm64)
+++ [1009 19:56:33] Building go targets for darwin/arm64
    github.com/onsi/ginkgo/v2/ginkgo (non-static)
    k8s.io/kubernetes/test/e2e/e2e.test (test)
Setting up for KUBERNETES_PROVIDER="local".
Skeleton Provider: prepare-e2e not implemented
KUBE_MASTER_IP: 
KUBE_MASTER: 
  I1009 19:57:36.676316    5600 e2e.go:109] Starting e2e run "fe617654-9887-496f-bb8b-a74dd8e996c5" on Ginkgo node 1
Running Suite: Kubernetes e2e suite - /Users/jon/github/kubernetes/_output/bin
==============================================================================
Random Seed: 1760057855 - will randomize all specs

Will run 1 of 7137 specs
•

Ran 1 of 7137 Specs in 76.469 seconds
SUCCESS! -- 1 Passed | 0 Failed | 0 Pending | 7136 Skipped
PASS

Ginkgo ran 1 suite in 1m17.568495042s
Test Suite Passed
```
