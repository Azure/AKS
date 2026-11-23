apiVersion: mellanox.com/v1alpha1
kind: NicClusterPolicy
metadata:
  name: nic-cluster-policy
  labels:
    app.kubernetes.io/part-of: distributed-training-rdma
    aks-codelab: distributed-training-rdma
spec:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: feature.node.kubernetes.io/pci-15b3.present
          operator: In
          values: ["true"]
        - key: "__NODE_SELECTOR_KEY__"
          operator: In
          values: ["__NODE_SELECTOR_VALUE__"]
  tolerations:
  - operator: Exists
  ofedDriver:
    repository: nvcr.io/nvidia/mellanox
    image: doca-driver
    version: doca3.2.0-25.10-1.2.8.0-2
    env:
    - name: OFED_BLACKLIST_MODULES_FILE
      value: /host/etc/modprobe.d/blacklist-ofed-modules.conf
    forcePrecompiled: false
    upgradePolicy:
      autoUpgrade: true
      drain:
        deleteEmptyDir: true
        enable: true
        force: true
        timeoutSeconds: 300
      maxParallelUpgrades: 1
    startupProbe: {initialDelaySeconds: 10, periodSeconds: 20}
    livenessProbe: {initialDelaySeconds: 30, periodSeconds: 30}
    readinessProbe: {initialDelaySeconds: 10, periodSeconds: 30}
  rdmaSharedDevicePlugin:
    repository: nvcr.io/nvidia/mellanox
    image: k8s-rdma-shared-dev-plugin
    version: network-operator-v25.10.0
    config: |
      {
        "configList": [
          {
            "resourceName": "shared_ib",
            "rdmaHcaMax": 63,
            "selectors": {
              "vendors": ["15b3"],
              "linkTypes": ["infiniband"]
            }
          }
        ]
      }
