#!/bin/bash
set -euo pipefail

# --- Infrastructure Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-ray-example-rg}"
LOCATION="${LOCATION:-eastus}"
CLUSTER_NAME="${CLUSTER_NAME:-demo}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_VM_SIZE="${NODE_VM_SIZE:-Standard_D4ds_v4}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.35}"
NODEPOOL_NAME="${NODEPOOL_NAME:-cpu-pool}"
NODEPOOL_NODE_COUNT="${NODEPOOL_NODE_COUNT:-2}"
NODEPOOL_VM_SIZE="${NODEPOOL_VM_SIZE:-Standard_D16ds_v7}"

# --- Helm Charts Configuration ---
HELM_REGISTRY="${HELM_REGISTRY:-oci://mcr.microsoft.com/aks/ai-runtime/helm}"
KUEUE_VERSION="${KUEUE_VERSION:-0.17.1}"
KUBERAY_OPERATOR_VERSION="${KUBERAY_OPERATOR_VERSION:-1.6.1}"

# --- Inference CPU Configuration ---
RAY_IMAGE="${RAY_IMAGE:-mcr.microsoft.com/aks/ai-runtime/ray:py3.12-ray2.54.0}"
RAY_VERSION="${RAY_VERSION:-2.54.0}"
INFERENCE_NAMESPACE="ray"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

create_infra() {
    echo "=== Creating resource group ==="
    az group create \
      --name "$RESOURCE_GROUP" \
      --location "$LOCATION"

    echo "=== Creating AKS cluster ==="
    az aks create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME" \
      --location "$LOCATION" \
      --node-count "$NODE_COUNT" \
      --node-vm-size "$NODE_VM_SIZE" \
      --kubernetes-version "$KUBERNETES_VERSION" \
      --generate-ssh-keys \
      --enable-managed-identity

    echo "=== Adding cpu worker node pool ==="
    az aks nodepool add \
      --resource-group "$RESOURCE_GROUP" \
      --cluster-name "$CLUSTER_NAME" \
      --name "$NODEPOOL_NAME" \
      --node-count "$NODEPOOL_NODE_COUNT" \
      --node-vm-size "$NODEPOOL_VM_SIZE"

    echo "=== Getting cluster credentials ==="
    az aks get-credentials \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CLUSTER_NAME" \
      --overwrite-existing
}

install_operators() {
    echo "=== Installing Kueue (v${KUEUE_VERSION}) ==="
    helm upgrade --install kueue "$HELM_REGISTRY/kueue" \
      --version "$KUEUE_VERSION" \
      --namespace kueue-system \
      --create-namespace \
      --wait

    echo "=== Installing KubeRay Operator (v${KUBERAY_OPERATOR_VERSION}) ==="
    helm upgrade --install kuberay-operator "$HELM_REGISTRY/kuberay-operator" \
      --version "$KUBERAY_OPERATOR_VERSION" \
      --namespace kuberay-system \
      --create-namespace \
      --wait
}

status() {
    echo "=== Cluster status ==="
    kubectl get nodes
    echo ""
    kubectl get pods -n kueue-system
    echo ""
    kubectl get pods -n kuberay-system
}

run_inference_cpu() {
    echo "=== Deploying Kueue resources ==="
    kubectl apply -f "$SCRIPT_DIR/inference-cpu/stack-kueue-resources.yaml"

    echo "=== Creating inference script ConfigMap ==="
    kubectl create configmap cpu-inference-script \
      --from-file=inference_job.py="$SCRIPT_DIR/inference-cpu/inference_job.py" \
      --namespace "$INFERENCE_NAMESPACE" \
      --dry-run=client -o yaml | kubectl apply -f -

    echo "=== Submitting RayJob ==="
    sed "s|{{RAY_IMAGE}}|${RAY_IMAGE}|g; s|{{RAY_VERSION}}|${RAY_VERSION}|g" \
      "$SCRIPT_DIR/inference-cpu/inference-rayjob.yaml" | kubectl apply -f -

    echo "=== Waiting for RayJob to complete ==="
    kubectl wait --for=jsonpath='{.status.jobStatus}'=SUCCEEDED \
      rayjob/cpu-inference \
      --namespace "$INFERENCE_NAMESPACE" \
      --timeout=600s

    echo "=== Job logs ==="
    kubectl logs -l job-name=cpu-inference --namespace "$INFERENCE_NAMESPACE" --tail=50
}

all() {
    check_prerequisites
    create_infra
    install_operators
    status
}

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  check_prerequisites  Check and install required tools (az, helm)"
    echo "  create_infra       Create resource group, AKS cluster, node pool, and fetch credentials"
    echo "  install_operators    Install Kueue and KubeRay from MCR"
    echo "  run_inference_cpu    Deploy and run the CPU inference example"
    echo "  status               Show cluster and operator pod status"
    echo "  all                Run all steps end-to-end"
    echo ""
    echo "Examples:"
    echo "  $0 install_operators   # Just install Kueue + KubeRay"
    echo "  $0 run_inference_cpu   # Run CPU inference example"
    echo "  $0 all                 # Full setup from scratch"
}

# --- Prerequisites ---
install_az_cli() {
    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

install_helm() {
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

check_prerequisites() {
    if ! command -v az &> /dev/null; then
        echo "Azure CLI (az) not found. Installing..."
        install_az_cli
    fi

    if ! command -v helm &> /dev/null; then
        echo "Helm not found. Installing..."
        install_helm
    fi

    echo "Prerequisites satisfied: az $(az version --query '"azure-cli"' -o tsv), helm $(helm version --short)"
}

COMMAND="${1:-}"
case "$COMMAND" in
    check_prerequisites|create_infra|install_operators|run_inference_cpu|status|all)
        "$COMMAND"
        ;;
    *)
        usage
        exit 1
        ;;
esac