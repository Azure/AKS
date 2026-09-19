apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-peermem-loader
  namespace: gpu-resources
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
spec:
  selector:
    matchLabels:
      app: nvidia-peermem-loader
  template:
    metadata:
      labels:
        app: nvidia-peermem-loader
    spec:
      priorityClassName: system-node-critical
      nodeSelector:
        "__NODE_SELECTOR_KEY__": "__NODE_SELECTOR_VALUE__"
        node.kubernetes.io/instance-type: __GPU_SKU__
      tolerations:
      - key: sku
        operator: Equal
        value: gpu
        effect: NoSchedule
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: loader
        image: __PEERMEM_IMAGE__
        command: [/bin/bash, -lc]
        args:
        - |
          set -euo pipefail
          apt-get update -qq
          DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends kmod
          modprobe nvidia-peermem
          test -d /sys/module/nvidia_peermem
          echo NVIDIA_PEERMEM_READY
          sleep infinity
        securityContext:
          privileged: true
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: "1", memory: 512Mi}
        startupProbe:
          exec:
            command: [/bin/bash, -c, command -v modprobe && modprobe nvidia-peermem && test -d /sys/module/nvidia_peermem]
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 120
          timeoutSeconds: 10
        readinessProbe:
          exec:
            command: [/bin/bash, -c, test -d /sys/module/nvidia_peermem]
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          exec:
            command: [/bin/bash, -c, modprobe nvidia-peermem && test -d /sys/module/nvidia_peermem]
          initialDelaySeconds: 30
          periodSeconds: 30
          failureThreshold: 1
          timeoutSeconds: 10
        volumeMounts:
        - name: modules
          mountPath: /lib/modules
          readOnly: true
      volumes:
      - name: modules
        hostPath:
          path: /lib/modules
          type: Directory
