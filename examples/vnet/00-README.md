This example respository contains two ARM templates which demonstrate new functionality in AKS to use an existing VNet with custom IP addressing and Azure CNI for IP address allocation.

## Address ranges

The IP address plan used for this cluster consists of a VNET, a Subnet (VNET-Local) reserved for other resources, and a Subnet (AKS-Nodes) reserved for AKS agent nodes and Pods.

| Address Range | First address | Last address | Address count | Description |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| 172.15.0.0/16 | 172.15.0.1 | 172.14.255.254 | 65534 | Address range for the entire VNet. |
| 172.15.0.0/22 | 172.15.0.1 | 172.15.3.254 | 1022 | Address range set aside for other resources, not used in this template. For example purposes only. |
| 172.15.4.0/22 | 172.15.4.1 | 172.15.7.254 | 1022 | Address range set aside for AKS agent nodes and Pods. |
| 172.15.8.0/22 | 172.15.8.1 | 172.15.11.254 | 1022 | Address range set aside for Kubernetes Services. |

## Static IPs

| Address | Description |
| ------- | ----------- |
| 172.16.0.1/24 | IP address and netmask (CIDR notation) for the Docker bridge address. |
| 172.15.8.2 | IP address reserved from the Kubernets Service range used for DNS. |

## Environment

The following environment variables are used for the `az` CLI commands to follow and specify the parameters for this example.

```
export SPN_PW=
export SPN_CLIENT_ID=

export AKS_SUB=

export AKS_RG=contoso-prod-eastus
export AKS_NAME=aks-vnet01

export AKS_VNET_RG=contoso-prod-eastus-vnet
export AKS_VNET_LOCATION=eastus
export AKS_VNET_NAME=ExistingVNET

export AKS_VNET_RANGE=172.15.0.0/16
export AKS_SUBNET1_NAME=VNET-Local
export AKS_SUBNET1_RANGE=172.15.0.0/22
export AKS_SUBNET2_NAME=AKS-Nodes
export AKS_SUBNET2_RANGE=172.15.4.0/22

export AKS_SVC_RANGE=172.15.8.0/22
export AKS_SUBNET=/subscriptions/${AKS_SUB}/resourceGroups/${AKS_VNET_RG}/providers/Microsoft.Network/virtualNetworks/${AKS_VNET_NAME}/subnets/${AKS_SUBNET2_NAME}
export AKS_BRIDGE_IP=172.16.0.1/24
export AKS_DNS_IP=172.15.8.2
```

## Create VNET resources

```
az group create -n ${AKS_VNET_RG} -l ${AKS_VNET_LOCATION}
az group deployment create -n 01-aks-vnet -g ${AKS_VNET_RG} --template-file 01-aks-vnet.json \
    --parameters \
    vnetName=${AKS_VNET_NAME} \
    vnetAddressPrefix=${AKS_VNET_RANGE} \
    subnet1Name=${AKS_SUBNET1_NAME} \
    subnet1Prefix=${AKS_SUBNET1_RANGE} \
    subnet2Name=${AKS_SUBNET2_NAME} \
    subnet2Prefix=${AKS_SUBNET2_RANGE}
```

## Grant AKS cluster Service Princpal access to VNET RG

```
az role assignment create --role=Contributor --scope=/subscriptions/${AKS_SUB}/resourceGroups/${AKS_VNET_RG} --assignee ${SPN_CLIENT_ID}
```

## Create AKS cluster

```
az group deployment create -n 02-aks-custom-vnet -g ${AKS_RG} --template-file 02-aks-custom-vnet.json \
    --parameters \
    resourceName=${AKS_NAME} \
    dnsPrefix=${AKS_NAME} \
    servicePrincipalClientId=${SPN_CLIENT_ID} \
    servicePrincipalClientSecret=${SPN_PW} \
    networkPlugin=azure \
    serviceCidr=${AKS_SVC_RANGE} \
    dnsServiceIP=${AKS_DNS_IP} \
    dockerBridgeCidr=${AKS_BRIDGE_IP} \
    vnetSubnetID=/subscriptions/${AKS_SUB}/resourceGroups/${AKS_VNET_RG}/providers/Microsoft.Network/virtualNetworks/${AKS_VNET_NAME}/subnets/${AKS_SUBNET2_NAME} \
    enableHttpApplicationRouting=false \
    enableOmsAgent=false
```

## GET AKS Cluster

```
az resource show --api-version 2018-03-31 --id /subscriptions/${AKS_SUB}/resourceGroups/${AKS_RG}/providers/Microsoft.ContainerService/managedClusters/${AKS_NAME}
```