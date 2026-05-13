#!/bin/bash

# Check if the user is logged into Azure CLI
if ! az account show > /dev/null 2>&1; then
    echo "Please login to Azure CLI using 'az login' before running this script."
    exit 1
fi

# Initialize Terraform
terraform init

# Create a Terraform plan
terraform plan -out main.tfplan

# Apply the Terraform plan
terraform apply main.tfplan

# Retrieve the Terraform outputs and store in variables
resource_group_name=$(terraform output -raw resource_group_name)
system_node_pool_name=$(terraform output -raw system_node_pool_name)
aks_cluster_name=$(terraform output -raw kubernetes_cluster_name)

# Get AKS credentials for the cluster
az aks get-credentials \
    --resource-group $resource_group_name \
    --name $aks_cluster_name

# Create the kuberay namespace
kuberay_namespace="kuberay"
kubectl create namespace $kuberay_namespace

# Output the current Kubernetes context
current_context=$(kubectl config current-context)
echo "Current Kubernetes Context: $current_context"

# Output the nodes in the cluster
kubectl get nodes

# Check Helm version
helm version

# Add the KubeRay Helm repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/

# Update the Helm repository
helm repo update

# Install or upgrade the KubeRay operator using Helm
helm upgrade \
--install \
--cleanup-on-fail \
--wait \
--timeout 10m0s \
--namespace "$kuberay_namespace" \
--create-namespace kuberay-operator kuberay/kuberay-operator \
--version 1.1.1

# Output the pods in the kuberay namespace
kubectl get pods -n $kuberay_namespace

# Download the PyTorch MNIST job YAML file
curl -LO https://raw.githubusercontent.com/ray-project/kuberay/master/ray-operator/config/samples/pytorch-mnist/ray-job.pytorch-mnist.yaml

# Train a PyTorch Model on Fashion MNIST
kubectl apply -n $kuberay_namespace -f ray-job.pytorch-mnist.yaml

# Output the pods in the kuberay namespace
kubectl get pods -n $kuberay_namespace

# Get the status of the Ray job
job_status=$(kubectl get rayjobs -n $kuberay_namespace -o jsonpath='{.items[0].status.jobDeploymentStatus}')

# Wait for the Ray job to complete
while [ "$job_status" != "Complete" ]; do
    echo -ne "Job Status: $job_status\\r"
    sleep 30
    job_status=$(kubectl get rayjobs -n $kuberay_namespace -o jsonpath='{.items[0].status.jobDeploymentStatus}')
done
echo "Job Status: $job_status"

# Check if the job succeeded
job_status=$(kubectl get rayjobs -n $kuberay_namespace -o jsonpath='{.items[0].status.jobStatus}')

if [ "$job_status" != "SUCCEEDED" ]; then
    echo "Job Failed!"
    exit 1
fi

# If the job succeeded, get the Ray cluster head service
rayclusterhead=$(kubectl get service -n $kuberay_namespace | grep 'rayjob-pytorch-mnist-raycluster' | grep 'ClusterIP' | awk '{print $1}')

# Now create a service of type NodePort for the Ray cluster head
kubectl expose service $rayclusterhead \
-n $kuberay_namespace \
--port=80 \
--target-port=8265 \
--type=NodePort \
--name=ray-dash

# Create an ingress for the KubeRay dashboard
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ray-dash
  namespace: kuberay
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
  - http:
      paths:
      - backend:
          service:
            name: ray-dash
            port:
              number: 80
        path: /
        pathType: Prefix
EOF

# Now find the public IP address of the ingress controller
lb_public_ip=$(kubectl get svc -n app-routing-system -o jsonpath='{.items[?(@.metadata.name == "nginx")].status.loadBalancer.ingress[0].ip}')

echo "KubeRay Dashboard URL: http://$lb_public_ip/"

exit 0