#!/bin/bash

set -euo pipefail

# Please Add
# Your AKS Cluster Subscription:
sub="<YOUR-SUBSCRIPTION-ID>"
# Your AKS Cluster Resource Group:
rg="<YOUR-RESOURCE-GROUP-NAME>"
# Your AKS Cluster Name:
cn="<YOUR-AKS-CLUSTER-NAME>"

# Set AKS kubectl creds
az account set --subscription "$sub"
az aks get-credentials --resource-group "$rg" --name "$cn"

mcrg=$(az aks show --name "$cn" --resource-group "$rg" --query "nodeResourceGroup" -o tsv)
echo "MC RG $mcrg"

# Check each nodepool individually
for np in $(az aks nodepool list --cluster-name "$cn" --resource-group "$rg" --query "[].name" -o tsv)
do
    echo "Going to cleanup for node pool $np"
    # Count nodes with wc only. A missed grep cannot become totalNodes=0
    # and scale the pool to 1. kubectl failure still fails the pipeline.
    totalNodes=$(kubectl get nodes -l "kubernetes.azure.com/agentpool=${np}" --no-headers | wc -l | tr -d ' ')
    echo "Total nodes of node pool $np is $totalNodes"
    if [ "$totalNodes" -eq 0 ]; then
        echo "No nodes found for node pool $np, skipping"
        continue
    fi
    nodeList=$(kubectl get nodes -l "kubernetes.azure.com/agentpool=${np}" -o wide --no-headers | awk '/5.4.0-1095-azure/ {print $1}')
    echo "node list: $nodeList"

    autoScalerEnabled=$(az aks nodepool show --cluster-name "$cn" --resource-group "$rg" --name "$np" --query "enableAutoScaling" -o tsv)
    echo "auto-scaler enabled: $autoScalerEnabled"

    if [ "$autoScalerEnabled" != "true" ]; then
        echo "Scale cluster by 1 node for removal of bad node"
        az aks scale --resource-group "$rg" --name "$cn" --node-count $((totalNodes+1)) --nodepool-name "$np"
    fi

    # Clean up each node with bad kernel
    for ns in $nodeList
    do
        echo "Going to cleanup for node $ns"

        echo "Cordoning $ns"
        kubectl cordon "$ns"
        # Drain timeout or reimage failure must not leave the node unschedulable.
        trap 'kubectl uncordon "$ns" || true' EXIT

        echo "Draining $ns"
        kubectl drain "$ns" --ignore-daemonsets --delete-emptydir-data --timeout=5m

        providerID=$(kubectl get node "$ns" -o jsonpath='{.spec.providerID}')
        vmssName=$(awk -F '/' '{print $(NF-2)}' <<<"$providerID")
        instanceId=$(awk -F '/' '{print $NF}' <<<"$providerID")
        echo "Re-image $vmssName/$instanceId"
        az vmss reimage --instance-id "$instanceId" --name "$vmssName" --resource-group "$mcrg"

        echo "Uncordoning $ns"
        kubectl uncordon "$ns"
        trap - EXIT

        echo "Cleanup for $ns ($vmssName/$instanceId) done"
    done

    if [ "$autoScalerEnabled" != "true" ]; then
        echo "Scale cluster to $totalNodes nodes"
        az aks scale --resource-group "$rg" --name "$cn" --node-count "$totalNodes" --nodepool-name "$np"
    fi
done
