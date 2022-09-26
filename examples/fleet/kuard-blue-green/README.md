# Example: Creating a multi-cluster service that exposes endpoints from a number of Kubernetes clusters

This directory contains step-by-step instructions and example YAML files to expose a workload deployed in multiple clusters through a Layer 4 load balancer.

This quick start is using [kuard](https://github.com/kubernetes-up-and-running/kuard) as an exemplary service to demonstrate the typical user experience flow.

## Before you begin
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/).
* Create a fleet with two members: `aks-member-blue` and `aks-member-green` using [Azure CNI networking](https://review.learn.microsoft.com/en-us/azure/aks/configure-azure-cni).
* Member clusters **MUST** reside either in the same virtual network, or [peered](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview) virtual networks such that pods from different clusters can communicate directly with each other using pod IPs.
* Download `kubeconfig` file for your hub cluster as `hub` using:

  `az fleet get-credentials -g ${GROUP} -n ${FLEET} --file hub`
* Download `kubeconfig` files for member clusters as `member-blue` and `member-green` respectively.

## Objectives
* Deploy a Kuard demo application using blue image in the `aks-member-blue`.
* Deploy a Kuard demo application using green image in the `aks-member-green`.
* Create a `ClusterIP` type service to expose the deployment and export the service.
* Expose fleet-wide endpoints from exported services with a multi-cluster service.

## Steps

### 1. Create namespace in the hub cluster

1. Switch to the hub cluster context to create namespace:

   ```shell
   KUBECONFIG=hub kubectl create namespace net
   ```

### 2. Deploy the demo application to the member clusters

1. Switch to `aks-member-blue` context to create deployment using kuard:blue,

   ```shell
   KUBECONFIG=member-blue kubectl create namespace net

   KUBECONFIG=member-blue kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard-blue-green/kuard-blue.yaml
   ```

2. Switch to the `aks-member-green` context to create deployment using kuard:green,

   ```shell
   KUBECONFIG=member-green kubectl create namespace net

   KUBECONFIG=member-green kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard-blue-green/kuard-green.yaml
   ```

### 3. Create service and service export in the member clusters

1. Switch to `aks-member-blue` context to create the kuard service and its service export:

   ```shell
   KUBECONFIG=member-blue kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard-blue-green/kuard-export.yaml
   ```

2. Verify the service is created:

   ```shell
   KUBECONFIG=member-blue kubectl get service -n net
   ```

    The output is similar to:

    ```console
    NAME    TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
    kuard   LoadBalancer   10.0.107.1   <none>        8080:32450/TCP   78s
    ```
3. Verify the service export is valid and has no conflicts:

   ```shell
   KUBECONFIG=member-blue kubectl get serviceexport -n net
   ```

   The output is similar to:

    ```console
    NAME    IS-VALID   IS-CONFLICTED   AGE
    kuard   True       False           31s
    ```
4. Switch to `aks-member-green` context to create the kuard service and its service export:   

   ```shell
   KUBECONFIG=member-green kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard-blue-green/kuard-export.yaml
   ```
   
   Verify the service and service export following the instructions above. 

### 4. Expose fleet-wide endpoints from exported services with a multi-cluster service

1. Switch to `aks-member-green` context to create a multi-cluster service. The endpoints will then be exposed with a L4 load balancer using `aks-member-green` nodes.

   ```shell
   KUBECONFIG=member-green kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard-blue-green/kuard-mcs.yaml
   ```
2. Verify the mutli-cluster service is valid

    ```shell
   KUBECONFIG=member-green kubectl get mcs -n net
   ```

   The output is similar to:

   ```console
   NAME    SERVICE-IMPORT   EXTERNAL-IP   IS-VALID   AGE
   kuard   kuard            20.81.3.74    True       26s
   ```
3. Access the running service:

   ```shell
   curl 20.81.3.74:8080
   ```
   Or access the http://20.81.3.74:8080 in the browser.

   The request will randomly hit different hostnames with blue or green version and the number of hits is proportional to the number of pods in each deployment.

Congratulations, you have created your first multi-cluster service.