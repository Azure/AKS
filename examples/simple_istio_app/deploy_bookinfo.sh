#!/bin/bash

set -e

# configurable
AZURE_SUBSCRIPTION_ID= #guid format
LOCATION=canadaeast #example location
RESOURCE_GROUP_NAME=testIstioApp
CLUSTER_NAME=testBookinfo

ISTIO_VERSION=0.8.0 #changing the version might break the script

echo ........ Logging into Azure
az login
az account set --subscription $AZURE_SUBSCRIPTION_ID
echo ........

echo ........ Creating resource group
az group create -l $LOCATION -n $RESOURCE_GROUP_NAME
echo ........

echo ........ Creating AKS cluster
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --enable-rbac --node-count 4
echo ........

echo ........ Getting KubeConfig
scriptDir="$( cd "$(dirname "$0")" ; pwd -P )"
kubeConfigPath="$scriptDir/config"

az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --file kubeConfigPath

export KUBECONFIG=kubeConfigPath
echo ........

echo ........ Downloading Istio locally - **IGNORE instructions
curl -L https://git.io/getIstio | sh -
echo ........

echo ........ Installing Helm
kubectl apply -f istio-$ISTIO_VERSION/install/kubernetes/helm/helm-service-account.yaml
helm init --service-account tiller --wait
echo ........

echo ........ Installing Istio - command might timeout but still work
helm install --wait istio-$ISTIO_VERSION/install/kubernetes/helm/istio --name istio --namespace istio-system --debug --timeout 1000 --set global.tag=$ISTIO_VERSION || true
echo ........

echo ........ Waiting for Istio to be ready
# wait logic until all pods are running
n=0
until [ $n -ge 20 ]
do
  kubectl get pods --namespace istio-system | tail -n +2 | awk '{ if ($3!="Running") exit 1}' && break
  echo ........ Still waiting for Istio to be ready
  n=$[$n+1]
  sleep 30
done
echo ........

echo ........ Deploying BookInfo app
kubectl apply -f istio-$ISTIO_VERSION/samples/bookinfo/kube/bookinfo.yaml

istio-$ISTIO_VERSION/bin/istioctl create -f istio-$ISTIO_VERSION/samples/bookinfo/routing/bookinfo-gateway.yaml

# wait logic until all pods are running
n=0
until [ $n -ge 20 ]
do
  kubectl get pods | tail -n +2 | awk '{ if ($3!="Running") exit 1}' && break
  echo ........ Still waiting for app deployment to be ready
  n=$[$n+1]
  sleep 30
done
echo ........

echo ........ Testing BookInfo app response code
ip="$(kubectl get svc --namespace istio-system | awk '{if ($1 ~ /^istio-ingressgateway/) print $4 }')"

response_code="$(curl -o /dev/null -s -w "%{http_code}\n" http://${ip}/productpage)"

if [ $response_code != "200" ]; then
  echo Wrong response code, expecting 200
  exit 1
fi

echo Done
echo "Visit http://$ip/productpage"
echo ........
