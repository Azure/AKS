gfd:
  enabled: false
podAnnotations:
  aks-codelab: distributed-training-rdma
nodeSelector:
  "__NODE_SELECTOR_KEY__": "__NODE_SELECTOR_VALUE__"
resources:
  requests: {cpu: 50m, memory: 64Mi}
  limits: {cpu: 250m, memory: 256Mi}
tolerations:
- key: sku
  operator: Equal
  value: gpu
  effect: NoSchedule
- key: nvidia.com/gpu
  operator: Exists
  effect: NoSchedule
