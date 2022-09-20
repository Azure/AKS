# Azure Kubernetes Fleet Manager Examples

This directory contains a number of examples of how to deploy applications to multiple clusters with Azure Kubernetes Fleet Manager.

## Examples

Before using any of the examples, you need to create a fleet with a few member clusters. See the section below on how to accomplish that.

| Name                               | Description            | Notable Features Used                                       | Complexity Level|
------------------------------------|------------------------|-------------------------------------------------------------| ------------ |
| [HelloWorld](helloworld/) | Hello World app | Resource Placement: Deployment, Service                     | Beginner |

## Create a Fleet

### Before you begin
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/).
* Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).
* Install Fleet extension for Azure CLI: `az extension add --name fleet`.

## Objectives
* Create a fleet.
* Create three AKS clusters.
* Add three AKS clusters as members of the fleet.

## Steps

### 1. Register for Fleet Preview

Register for Fleet Preview in your Azure subscription:

```shell
export SUBSCRIPTION="<your-subscription-id>"
az account set -s ${SUBSCRIPTION}

az feature register --name FleetResourcePreview --namespace Microsoft.ContainerService 
```

Verify the registration succeeded:

```shell
az feature show --name FleetResourcePreview --namespace Microsoft.ContainerService  --output table
```

The output is similar to:
```console
Name                                             RegistrationState
-----------------------------------------------  -------------------
Microsoft.ContainerService/FleetResourcePreview  Registered
```

### 2. Create a resource group

Create a group to contain the fleet:

```shell
export GROUP="fleet-group"
export LOCATION="westcentralus"
az group create -g ${GROUP} -l ${LOCATION}
```

The output is similar to:

```console
{
  "id": "/subscriptions/<your-subscription-id>/resourceGroups/fleet-group",
  "location": "westcentralus",
  "managedBy": null,
  "name": "fleet-group",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

### 3. Create a fleet
Create a fleet in the group (note that this step will take several minutes as it will create an AKS cluster as the fleet hub cluster):

```shell
export FLEET="fleet"
az fleet create -g ${GROUP} -n ${FLEET}
```

Verify the fleet is created successfully:

```shell
az fleet show -g ${GROUP} -n ${FLEET}
```

The output is similar to:

```console
{
  "etag": "\"00002101-0000-0600-0000-6329fcb80000\"",
  "hubProfile": {
    "dnsPrefix": "fleet-fleet-group-8ecadf",
    "fqdn": "fleet-fleet-group-8ecadf-98ab99cd.hcp.westcentralus.azmk8s.io",
    "kubernetesVersion": "1.23.8"
  },
  "id": "/subscriptions/<your-subscription-id>/resourceGroups/fleet-group/providers/Microsoft.ContainerService/fleets/fleet",
  "location": "westcentralus",
  "name": "fleet",
  "provisioningState": "Succeeded",
  "resourceGroup": "fleet-group",
  "systemData": {
    "createdAt": "2022-09-20T17:39:03.342999+00:00",
    "createdBy": "foo@bar.com",
    "createdByType": "User",
    "lastModifiedAt": "2022-09-20T17:39:03.342999+00:00",
    "lastModifiedBy": "foo@bar.com",
    "lastModifiedByType": "User"
  },
  "tags": null,
  "type": "Microsoft.ContainerService/fleets"
}
```

### (Optional) 4. Create three AKS clusters

You can skip this step if you already have three [managed-identity-enabled](https://learn.microsoft.com/en-us/azure/aks/use-managed-identity) AKS clusters.
The AKS clusters must be in the same tenant as the fleet, but they can be in different subscriptions or different locations from the fleet.

```shell
export MEMBER1=aks-member-1
az aks create -l ${LOCATION} -g ${GROUP} -n ${MEMBER1} --generate-ssh-keys --network-plugin azure --node-count 1 --no-wait
```

```shell
export MEMBER2=aks-member-2
az aks create -l ${LOCATION} -g ${GROUP} -n ${MEMBER2} --generate-ssh-keys --network-plugin azure --node-count 1 --no-wait
```

```shell
export MEMBER3=aks-member-3
export LOCATION3=eastus
az aks create -l ${LOCATION3} -g ${GROUP} -n ${MEMBER3} --generate-ssh-keys --network-plugin azure --node-count 1
```

Note that we are creating three clusters simultaneously with `--no-wait` for the first two.
This step will take several minutes. You can wait for the 3rd one to be done and proceed.

Verify the clusters are successfully created:

```shell
az aks list -g ${GROUP} -o table
```

The output is similar to (note that `ProvisioningState` should change from `Creating` to `Succeeded`):

```console
Name          Location       ResourceGroup    KubernetesVersion    CurrentKubernetesVersion    ProvisioningState    Fqdn
------------  -------------  ---------------  -------------------  --------------------------  -------------------  ------------------------------------------------------------------
aks-member-3  eastus         fleet-group      1.23.8               1.23.8                      Succeeded            aks-member-fleet-group-8ecadf-d771b794.hcp.eastus.azmk8s.io
aks-member-1  westcentralus  fleet-group      1.23.8               1.23.8                      Succeeded            aks-member-fleet-group-8ecadf-a7af50a9.hcp.westcentralus.azmk8s.io
aks-member-2  westcentralus  fleet-group      1.23.8               1.23.8                      Succeeded            aks-member-fleet-group-8ecadf-4e806f1a.hcp.westcentralus.azmk8s.io
```

Export the cluster resource IDs to be used by the next step:
```shell
export MEMBER_ID1=/subscriptions/${SUBSCRIPTION}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/managedClusters/${MEMBER1}; echo ${MEMBER_ID1}
export MEMBER_ID2=/subscriptions/${SUBSCRIPTION}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/managedClusters/${MEMBER2}; echo ${MEMBER_ID2}
export MEMBER_ID3=/subscriptions/${SUBSCRIPTION}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/managedClusters/${MEMBER3}; echo ${MEMBER_ID3}
```

### 5. Add three AKS clusters as members of the fleet

If you have skipped Step 4, you need to export the following variables to point to your own AKS clusters:

```shell
export MEMBER_ID1=/subscriptions/<subscription-id1>/resourceGroups/<group1>/providers/Microsoft.ContainerService/managedClusters/<cluster1>
export MEMBER_ID2=/subscriptions/<subscription-id2>/resourceGroups/<group2>/providers/Microsoft.ContainerService/managedClusters/<cluster2>
export MEMBER_ID3=/subscriptions/<subscription-id3>/resourceGroups/<group3>/providers/Microsoft.ContainerService/managedClusters/<cluster3>
```

Make sure they contain a proper AKS cluster resource ID:

```shell
echo ${MEMBER_ID1}
echo ${MEMBER_ID2}
echo ${MEMBER_ID3}
```

The output is similar to:

```console
/subscriptions/<subscription-id1>/resourceGroups/<group1>/providers/Microsoft.ContainerService/managedClusters/<cluster1>
/subscriptions/<subscription-id2>/resourceGroups/<group2>/providers/Microsoft.ContainerService/managedClusters/<cluster2>
/subscriptions/<subscription-id3>/resourceGroups/<group3>/providers/Microsoft.ContainerService/managedClusters/<cluster3>
```

Join three clusters simultaneously with `--no-wait` for the first two.
This step will take several minutes. You can wait for the 3rd one to be done and proceed.

```shell
export MEMBER1=aks-member-1
az fleet member create -g ${GROUP} --fleet-name ${FLEET} --member-cluster-id=${MEMBER_ID1} -n ${MEMBER1} --no-wait

export MEMBER2=aks-member-2
az fleet member create -g ${GROUP} --fleet-name ${FLEET} --member-cluster-id=${MEMBER_ID2} -n ${MEMBER2} --no-wait

export MEMBER3=aks-member-3
az fleet member create -g ${GROUP} --fleet-name ${FLEET} --member-cluster-id=${MEMBER_ID3} -n ${MEMBER3}
```

Verify the members have joined successfully:

```shell
az fleet member list -g ${GROUP} --fleet-name ${FLEET} -o table
```

The output is similar to (note that `ProvisioningState` should change from `Joining` to `Succeeded`):

```console
ClusterResourceId                                                                                                              Name          ProvisioningState    ResourceGroup
-----------------------------------------------------------------------------------------------------------------------------  ------------  -------------------  ---------------
/subscriptions/<subscription-id>/resourceGroups/fleet-group/providers/Microsoft.ContainerService/managedClusters/aks-member-1  aks-member-1  Succeeded            fleet-group
/subscriptions/<subscription-id>/resourceGroups/fleet-group/providers/Microsoft.ContainerService/managedClusters/aks-member-2  aks-member-2  Succeeded            fleet-group
/subscriptions/<subscription-id>/resourceGroups/fleet-group/providers/Microsoft.ContainerService/managedClusters/aks-member-3  aks-member-3  Succeeded            fleet-group
```

### 6. Get credentials to access the hub cluster

To be able to access the hub cluster API server to read and write Kubernetes objects, you must grant yourself the following role upon the fleet:

```shell
# Use your own email address.
export ME=foo@bar.com
export CLUSTER_ADMIN_ROLE="Azure Kubernetes Fleet Manager RBAC Cluster Admin"
export FLEET_ID=/subscriptions/${SUBSCRIPTION}/resourcegroups/${GROUP}/providers/Microsoft.ContainerService/fleets/${FLEET}; echo ${FLEET_ID}

az role assignment create --role "${CLUSTER_ADMIN_ROLE}" --assignee ${ME} --scope ${FLEET_ID}
```

The output is similar to:

```console
/subscriptions/<your-subscription-id>/resourcegroups/fleet-group/providers/Microsoft.ContainerService/fleets/fleet
{
  "canDelegate": null,
  "condition": null,
  "conditionVersion": null,
  "description": null,
  "id": "/subscriptions/<your-subscription-id>/resourcegroups/fleet-group/providers/Microsoft.ContainerService/fleets/fleet/providers/Microsoft.Authorization/roleAssignments/36e6151c-a236-4ae3-b60e-e830067cd08f",
  "name": "36e6151c-a236-4ae3-b60e-e830067cd08f",
  "principalId": "<your-principal-id>",
  "principalType": "User",
  "resourceGroup": "fleet-group",
  "roleDefinitionId": "/subscriptions/<your-subscription-id>/providers/Microsoft.Authorization/roleDefinitions/18ab4d3d-a1bf-4477-8ad9-8359bc988f69",
  "scope": "/subscriptions/<your-subscription-id>/resourcegroups/fleet-group/providers/Microsoft.ContainerService/fleets/fleet",
  "type": "Microsoft.Authorization/roleAssignments"
}
```

Get kubeconfig to access the hub cluster:

```shell
az fleet get-credentials -g ${GROUP} -n ${FLEET}
```

The output is similar to:

```console
Merged "hub" as current context in /Users/<your-user-name>/.kube/config
```

Verify that you can access the hub cluster API server:

```shell
kubectl cluster-info
```

The output is similar to (note that you must do device login as the hub cluster is an [Azure AD-enabled](https://learn.microsoft.com/en-us/azure/aks/managed-aad) cluster):

```console
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code ABCDEFG2 to authenticate.
Kubernetes control plane is running at https://fleet-fleet-group-8ecadf-98ab99cd.hcp.westcentralus.azmk8s.io:443
CoreDNS is running at https://fleet-fleet-group-8ecadf-98ab99cd.hcp.westcentralus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://fleet-fleet-group-8ecadf-98ab99cd.hcp.westcentralus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Each fleet member Azure resource has a corresponding MemberCluster Kubernetes custom resource in the hub cluster.
View the list of MemberClusters (add `-o yaml` if you want to view more details):

```shell
kubectl get memberclusters
```

The output is similar to:

```console
NAME           JOINED   AGE
aks-member-1   True     11m
aks-member-2   True     11m
aks-member-3   True     11m
```

### 7. Get credentials to access member clusters

```shell
az aks get-credentials -g ${GROUP} -n ${MEMBER1} --file member1
KUBECONFIG=member1 kubectl cluster-info

az aks get-credentials -g ${GROUP} -n ${MEMBER2} --file member2
KUBECONFIG=member2 kubectl cluster-info

az aks get-credentials -g ${GROUP} -n ${MEMBER3} --file member3
KUBECONFIG=member3 kubectl cluster-info
```

The output is similar to:

```console
Merged "aks-member-1" as current context in member1
Kubernetes control plane is running at https://aks-member-fleet-group-8ecadf-a7af50a9.hcp.westcentralus.azmk8s.io:443
CoreDNS is running at https://aks-member-fleet-group-8ecadf-a7af50a9.hcp.westcentralus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://aks-member-fleet-group-8ecadf-a7af50a9.hcp.westcentralus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

Merged "aks-member-2" as current context in member2
Kubernetes control plane is running at https://aks-member-fleet-group-8ecadf-4e806f1a.hcp.westcentralus.azmk8s.io:443
CoreDNS is running at https://aks-member-fleet-group-8ecadf-4e806f1a.hcp.westcentralus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://aks-member-fleet-group-8ecadf-4e806f1a.hcp.westcentralus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

Merged "aks-member-3" as current context in member3
Kubernetes control plane is running at https://aks-member-fleet-group-8ecadf-d771b794.hcp.eastus.azmk8s.io:443
CoreDNS is running at https://aks-member-fleet-group-8ecadf-d771b794.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://aks-member-fleet-group-8ecadf-d771b794.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

To easily switch among multiple member clusters, you can use a command like the following (i.e., always add `KUBECONFIG=memberx` as a prefix to `kubectl`):

```shell
KUBECONFIG=member1 kubectl get nodes
```
```console
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-18683466-vmss000000   Ready    agent   54m   v1.23.8
```

Congratulations, you have created your first fleet with three member clusters! Now you can proceed to use the examples listed earlier in this doc.