apiVersion: v1
kind: Service
metadata:
  name: gradient-__MODE__-master
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  selector:
    app: gradient-sync
    run: __MODE__
    rank: "0"
  ports:
  - name: rendezvous
    port: 29500
    targetPort: 29500
---
apiVersion: batch/v1
kind: Job
metadata:
  name: gradient-__MODE__-rank0
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: gradient-sync
        run: __MODE__
        rank: "0"
    spec:
      restartPolicy: Never
      activeDeadlineSeconds: 1800
      nodeSelector:
        "__NODE_SELECTOR_KEY__": "__NODE_SELECTOR_VALUE__"
        node.kubernetes.io/instance-type: __GPU_SKU__
        kubernetes.io/hostname: __RANK0_NODE__
      tolerations:
      - {key: sku, operator: Equal, value: gpu, effect: NoSchedule}
      - {key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: {app: gradient-sync, run: __MODE__}
            topologyKey: kubernetes.io/hostname
      containers:
      - name: trainer
        image: __PYTORCH_IMAGE__
        imagePullPolicy: IfNotPresent
        command: [/bin/bash, -lc]
        args: [python3 /opt/lab/gradient_sync.py]
        env:
        - {name: RANK, value: "0"}
        - {name: WORLD_SIZE, value: "2"}
        - {name: MASTER_ADDR, value: gradient-__MODE__-master}
        - {name: MASTER_PORT, value: "29500"}
        - {name: TRANSPORT_MODE, value: __MODE__}
        - {name: GRADIENT_MIB, value: "__GRADIENT_MIB__"}
        - {name: WARMUP_STEPS, value: "__WARMUP_STEPS__"}
        - {name: MEASURE_STEPS, value: "__MEASURE_STEPS__"}
        - {name: NCCL_DEBUG, value: INFO}
        - {name: NCCL_DEBUG_SUBSYS, value: "INIT,NET"}
        - {name: NCCL_IB_DISABLE, value: "__IB_DISABLE__"}
        - {name: NCCL_NET_GDR_LEVEL, value: SYS}
        - {name: NCCL_SOCKET_IFNAME, value: eth0}
        - {name: NCCL_IB_PCI_RELAXED_ORDERING, value: "1"}
        - {name: TORCH_NCCL_ASYNC_ERROR_HANDLING, value: "1"}
        securityContext:
          capabilities: {add: [IPC_LOCK]}
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
            nvidia.com/gpu: "1"
            "__RDMA_RESOURCE__": "1"
          limits:
            cpu: "4"
            memory: 8Gi
            nvidia.com/gpu: "1"
            "__RDMA_RESOURCE__": "1"
        volumeMounts:
        - {name: script, mountPath: /opt/lab, readOnly: true}
        - {name: shm, mountPath: /dev/shm}
      volumes:
      - name: script
        configMap: {name: gradient-sync-code}
      - name: shm
        emptyDir: {medium: Memory, sizeLimit: 2Gi}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: gradient-__MODE__-rank1
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: gradient-sync
        run: __MODE__
        rank: "1"
    spec:
      restartPolicy: Never
      activeDeadlineSeconds: 1800
      nodeSelector:
        "__NODE_SELECTOR_KEY__": "__NODE_SELECTOR_VALUE__"
        node.kubernetes.io/instance-type: __GPU_SKU__
        kubernetes.io/hostname: __RANK1_NODE__
      tolerations:
      - {key: sku, operator: Equal, value: gpu, effect: NoSchedule}
      - {key: nvidia.com/gpu, operator: Exists, effect: NoSchedule}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: {app: gradient-sync, run: __MODE__}
            topologyKey: kubernetes.io/hostname
      containers:
      - name: trainer
        image: __PYTORCH_IMAGE__
        imagePullPolicy: IfNotPresent
        command: [/bin/bash, -lc]
        args: [python3 /opt/lab/gradient_sync.py]
        env:
        - {name: RANK, value: "1"}
        - {name: WORLD_SIZE, value: "2"}
        - {name: MASTER_ADDR, value: gradient-__MODE__-master}
        - {name: MASTER_PORT, value: "29500"}
        - {name: TRANSPORT_MODE, value: __MODE__}
        - {name: GRADIENT_MIB, value: "__GRADIENT_MIB__"}
        - {name: WARMUP_STEPS, value: "__WARMUP_STEPS__"}
        - {name: MEASURE_STEPS, value: "__MEASURE_STEPS__"}
        - {name: NCCL_DEBUG, value: INFO}
        - {name: NCCL_DEBUG_SUBSYS, value: "INIT,NET"}
        - {name: NCCL_IB_DISABLE, value: "__IB_DISABLE__"}
        - {name: NCCL_NET_GDR_LEVEL, value: SYS}
        - {name: NCCL_SOCKET_IFNAME, value: eth0}
        - {name: NCCL_IB_PCI_RELAXED_ORDERING, value: "1"}
        - {name: TORCH_NCCL_ASYNC_ERROR_HANDLING, value: "1"}
        securityContext:
          capabilities: {add: [IPC_LOCK]}
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
            nvidia.com/gpu: "1"
            "__RDMA_RESOURCE__": "1"
          limits:
            cpu: "4"
            memory: 8Gi
            nvidia.com/gpu: "1"
            "__RDMA_RESOURCE__": "1"
        volumeMounts:
        - {name: script, mountPath: /opt/lab, readOnly: true}
        - {name: shm, mountPath: /dev/shm}
      volumes:
      - name: script
        configMap: {name: gradient-sync-code}
      - name: shm
        emptyDir: {medium: Memory, sizeLimit: 2Gi}
