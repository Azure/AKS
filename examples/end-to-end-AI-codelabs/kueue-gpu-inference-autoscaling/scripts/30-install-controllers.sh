#!/usr/bin/env bash
# Install the NVIDIA device plugin and Kueue.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

step "Installing NVIDIA device plugin"
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin >/dev/null
helm repo update nvdp >/dev/null
helm upgrade --install nvidia-device-plugin nvdp/nvidia-device-plugin \
  --namespace kube-system \
  --version "$NVIDIA_DEVICE_PLUGIN_VERSION" \
  --set-string nodeSelector.workload=gpu-inference \
  --set-json 'tolerations=[{"key":"sku","operator":"Equal","value":"gpu","effect":"NoSchedule"}]'
pass "Installed NVIDIA device plugin $NVIDIA_DEVICE_PLUGIN_VERSION"

step "Installing Kueue"
helm upgrade --install kueue \
  oci://mcr.microsoft.com/aks/ai-runtime/helm/kueue \
  --version "$KUEUE_VERSION" \
  --namespace kueue-system \
  --create-namespace \
  --wait \
  --timeout 10m
pass "Installed Kueue $KUEUE_VERSION"

kubectl wait --for=condition=Available deployment/kueue-controller-manager \
  --namespace kueue-system --timeout=5m
pass "Kueue controller is available"
