# Example: Exporting service using Fleet resource placement

This directory contains step-by-step instructions and example YAML files to expose a workload deployed in multiple clusters through a Layer 4 load balancer using Azure fleet management's Kubernetes native interface.

This quick start is using [kuard](https://github.com/kubernetes-up-and-running/kuard) as an exemplary service to demonstrate the typical user experience flow.

## Before you begin
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/).
* Create a fleet with three members: `aks-member-1`, `aks-member-2`, and `aks-member-3` using [Azure CNI networking](https://review.learn.microsoft.com/en-us/azure/aks/configure-azure-cni).
* Member clusters **MUST** reside either in the same virtual network, or [peered](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview) virtual networks such that pods from different clusters can communicate directly with each other using pod IPs.
* Download `kubeconfig` file for your hub cluster as `hub` using: 

  `az fleet get-credentials -g ${GROUP} -n ${FLEET} --file hub`
* Download `kubeconfig` files for member clusters as `member1`, `member2`, and `member3` respectively.

## Objectives
* Deploy a Kuard demo application with a `ClusterIP` type service in the member clusters and export the service.
* Expose fleet-wide endpoints from exported services with a multi-cluster service.

## Steps

### 1. Deploy to the Hub Cluster

1. Switch to the hub cluster context to create namespace:

   ```shell
   KUBECONFIG=hub kubectl create namespace kuard-demo
   ```

2. Deploy a Kuard demo application with a `ClusterIP` type service and export the service.

   ```shell
   KUBECONFIG=hub kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-export-service.yaml
   ```

3. Verify the application is deployed but not running:
   
   ```shell
   KUBECONFIG=hub kubectl get all -n kuard-demo
   ```

   The output is similar to:

   ```console
   NAME            TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
   service/kuard   LoadBalancer   10.0.72.28   <none>     8080:32629/TCP   23s

   NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
   deployment.apps/kuard   0/2     0            0           25s
   ```
   Note that the deployment does not result in any pod created on the hub cluster (`READY: 0/2`).
   This is working as expected as the objective is to deploy the application to member clusters not the hub cluster.

4. Verify the service export is created but not running:
    ```shell
   KUBECONFIG=hub kubectl get serviceexport -n kuard-demo
   ```

   The output is similar to:

   ```console
   NAME    IS-VALID   IS-CONFLICTED   AGE
   kuard                              2m53s
   ```
   Note that `IS-VALID` and `IS-CONFLICTED` are empty. 
   This is working as expected as the objective is to deploy the service export to member clusters not the hub cluster.

### 2. Place to Member Clusters

1. Place the application to all the member clusters through a ClusterResourcePlacement CR:

    ```shell
   KUBECONFIG=hub kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-crp.yaml
   ```
   
2. Verify the placement status:

   ```shell
   KUBECONFIG=hub kubectl get crp kuard -o yaml | grep status -A 1000
   ```

   The output is similar to:

   ```yaml
   status:
   conditions:
     - lastTransitionTime: "2022-09-20T06:31:57Z"
       message: Successfully scheduled resources for placement
       observedGeneration: 1
       reason: ScheduleSucceeded
       status: "True"
       type: Scheduled
     - lastTransitionTime: "2022-09-20T06:31:58Z"
       message: Successfully applied resources to member clusters
       observedGeneration: 1
       reason: ApplySucceeded
       status: "True"
       type: Applied
   selectedResources:
     - group: networking.fleet.azure.com
       kind: ServiceExport
       name: kuard
       namespace: kuard-demo
       version: v1
     - kind: Service
       name: kuard
       namespace: kuard-demo
       version: v1
     - kind: Namespace
       name: kuard-demo
       version: v1
   targetClusters:
     - aks-member-3
     - aks-member-2
     - aks-member-1
   ```
   
    All the resources under namespace `kuard-demo` (including the namespace) are selected and placed to all the member clusters.

3. Switch to the member clusters to verify the resource has been created:

   ```shell
   KUBECONFIG=member1 kubectl get all -n kuard-demo
   KUBECONFIG=member2 kubectl get all -n kuard-demo
   KUBECONFIG=member3 kubectl get all -n kuard-demo
   ```

   The output is similar to:

   ```console
   NAME                        READY   STATUS    RESTARTS   AGE                  
   pod/kuard-7788d9bc5-bp8qw   1/1     Running   0          13m                  
   pod/kuard-7788d9bc5-tp54d   1/1     Running   0          13m

   NAME            TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
   service/kuard   LoadBalancer   10.0.188.8   <none>        8080:32629/TCP   13m

   NAME                    READY   UP-TO-DATE   AVAILABLE   AGE                  
   deployment.apps/kuard   2/2     2            2           13m

   NAME                              DESIRED   CURRENT   READY   AGE             
   replicaset.apps/kuard-7788d9bc5   2         2         2       13m
   ```
4. Switch to the member clusters to verify the service export has been created:
   
   ```shell
   KUBECONFIG=member1 kubectl get serviceexport -n kuard-demo
   KUBECONFIG=member2 kubectl get serviceexport -n kuard-demo
   KUBECONFIG=member3 kubectl get serviceexport -n kuard-demo
   ```

   The output is similar to:
   ```console
   NAME    IS-VALID   IS-CONFLICTED   AGE
   kuard   True       False           13m
   ```
   The service is valid for export (`IS-VALID` field is true) and has no conflicts with other exports (`IS-CONFLICT` is false).

### 3. Expose fleet-wide endpoints from exported services with a multi-cluster service

1. Switch to `aks-member-1` context to create a multi-cluster service. The endpoints will then be exposed with a L4 load balancer using `aks-member-1` nodes.

   ```shell
   KUBECONFIG=member1 kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-mcs.yaml
   ```

2. Verify the mutli-cluster service is valid:

   ```shell
   KUBECONFIG=member1 kubectl get mcs -n kuard-demo
   ```

   The output is similar to:

   ```console
   NAME    SERVICE-IMPORT   EXTERNAL-IP   IS-VALID   AGE
   kuard   kuard            20.253.64.1    True       26s
   ```
3. Access the running service:

   ```shell
   curl 20.253.64.1:8080
   ```
   Or access the http://20.253.64.1:8080 in the browser.

   The request will randomly hit different pods.

Congratulations, you have created your first multi-cluster service using Azure fleet management.
