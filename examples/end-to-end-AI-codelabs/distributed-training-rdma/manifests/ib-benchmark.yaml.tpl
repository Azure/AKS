apiVersion: v1
kind: Service
metadata:
  name: ib-benchmark-server
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  selector: {app: ib-benchmark, role: server}
  ports:
  - {name: control, port: 18515, targetPort: 18515}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: ib-benchmark-server
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  backoffLimit: 0
  template:
    metadata:
      labels: {app: ib-benchmark, role: server}
    spec:
      restartPolicy: Never
      activeDeadlineSeconds: 1200
      nodeSelector:
        "__NODE_SELECTOR_KEY__": "__NODE_SELECTOR_VALUE__"
        node.kubernetes.io/instance-type: __GPU_SKU__
      tolerations:
      - {key: sku, operator: Equal, value: gpu, effect: NoSchedule}
      - {key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: {app: ib-benchmark}
            topologyKey: kubernetes.io/hostname
      containers:
      - name: ibtools
        image: __PYTORCH_IMAGE__
        imagePullPolicy: IfNotPresent
        command: [/bin/bash, -lc]
        args:
        - |
          set -euo pipefail
          hca=$(for device in $(ibv_devices | awk 'NR>2 {print $1}'); do
            ibv_devinfo -d "$device" 2>/dev/null | grep -q 'link_layer:[[:space:]]*InfiniBand' &&
            ibstat "$device" | grep -q 'State: Active' && { echo "$device"; break; }
          done)
          test -n "$hca"
          echo "IB_DEVICE=$hca"
          ibstat "$hca"
          echo BEGIN_IB_READ_LAT
          ib_read_lat -d "$hca" -F -n 1000
          echo BEGIN_IB_WRITE_BW
          ib_write_bw -d "$hca" -F --report_gbits -s 8388608 -n 1000
        securityContext: {capabilities: {add: [IPC_LOCK]}}
        resources:
          requests: {cpu: 500m, memory: 256Mi, "__RDMA_RESOURCE__": "1"}
          limits: {cpu: "2", memory: 1Gi, "__RDMA_RESOURCE__": "1"}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: ib-benchmark-client
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  backoffLimit: 0
  template:
    metadata:
      labels: {app: ib-benchmark, role: client}
    spec:
      restartPolicy: Never
      activeDeadlineSeconds: 1200
      nodeSelector:
        "__NODE_SELECTOR_KEY__": "__NODE_SELECTOR_VALUE__"
        node.kubernetes.io/instance-type: __GPU_SKU__
      tolerations:
      - {key: sku, operator: Equal, value: gpu, effect: NoSchedule}
      - {key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: {app: ib-benchmark}
            topologyKey: kubernetes.io/hostname
      containers:
      - name: ibtools
        image: __PYTORCH_IMAGE__
        imagePullPolicy: IfNotPresent
        command: [/bin/bash, -lc]
        args:
        - |
          set -euo pipefail
          hca=$(for device in $(ibv_devices | awk 'NR>2 {print $1}'); do
            ibv_devinfo -d "$device" 2>/dev/null | grep -q 'link_layer:[[:space:]]*InfiniBand' &&
            ibstat "$device" | grep -q 'State: Active' && { echo "$device"; break; }
          done)
          test -n "$hca"
          echo "IB_DEVICE=$hca"
          run_with_retry() {
            for _ in $(seq 1 120); do
              "$@" && return 0
              echo "Waiting for the perftest server..."
              sleep 2
            done
            return 1
          }
          echo BEGIN_IB_READ_LAT
          run_with_retry ib_read_lat -d "$hca" -F -n 1000 ib-benchmark-server
          echo BEGIN_IB_WRITE_BW
          run_with_retry ib_write_bw -d "$hca" -F --report_gbits -s 8388608 -n 1000 ib-benchmark-server
        securityContext: {capabilities: {add: [IPC_LOCK]}}
        resources:
          requests: {cpu: 500m, memory: 256Mi, "__RDMA_RESOURCE__": "1"}
          limits: {cpu: "2", memory: 1Gi, "__RDMA_RESOURCE__": "1"}
