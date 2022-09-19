# Example: Place HelloWorld application to multiple clusters in a fleet

This directory contains the instructions on how to deploy a Hello World application using Fleet resource placement.

The application is from https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/.

## Before you begin
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/).
* Create a fleet with three members: `aks-member-1`, `aks-member-2`, and `aks-member-3`.
* Configure kubectl to communicate with your hub cluster.
* Download `kubeconfig` files for member clusters as `member1`, `member2`, and `member3` respectively.

## Objectives
* Deploy a Hello World application with a LB service in the hub cluster.
* Place the application to selected member clusters, and access the running application.

## Steps

### 1. Deploy to the Hub Cluster

1. Download and customize the application to use namespace hello-world:

   ```shell
   wget https://k8s.io/examples/service/load-balancer-example.yaml

   cat <<EOF >./kustomization.yaml
   namespace: hello-world
   resources:
   - load-balancer-example.yaml
   EOF
   ```

2. Deploy the application and expose a LoadBalancer service: 

   ```shell
   kubectl create namespace hello-world
   kubectl apply -k ./
   
   kubectl expose deployment hello-world -n hello-world --type=LoadBalancer --name=my-service
   ```

3. Verify the application is deployed but not running:

   ```shell
   kubectl get all -n hello-world
   ```
   
   The output is similar to:
   
   ```console
   NAME                 TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
   service/my-service   LoadBalancer   10.0.184.49   <pending>     8080:32614/TCP   4s
   
   NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
   deployment.apps/hello-world   0/5     0            0           28s
   ```

   Note that the deployment does not result in any pod created on the hub cluster (`READY: 0/5`) and the service doesn't have an external IP (`EXTERNAL-IP: <pending>`).
   This is working as expected as the objective is to deploy the application to member clusters not the hub cluster.

### 2. Place to Member Clusters

#### Scenario A: Place to all member clusters

1. Place to all the member clusters ([hello-world-crp-all-clusters.yaml](https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/helloworld/hello-world-crp-all-clusters.yaml)):

   ```shell
   kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/helloworld/hello-world-crp-all-clusters.yaml
   ```

2. Verify the placement status:

   ```shell
   kubectl get crp hello-world -o yaml | grep status -A 1000
   ```

   The output is similar to:

   ```yaml
   status:
     conditions:
     - lastTransitionTime: "2022-09-12T23:31:18Z"
       message: Successfully scheduled resources for placement
       observedGeneration: 1
       reason: ScheduleSucceeded
       status: "True"
       type: Scheduled
     - lastTransitionTime: "2022-09-12T23:31:19Z"
       message: Successfully applied resources to member clusters
       observedGeneration: 1
       reason: ApplySucceeded
       status: "True"
       type: Applied
     selectedResources:
     - group: apps
       kind: Deployment
       name: hello-world
       namespace: hello-world
       version: v1
     - kind: Service
       name: my-service
       namespace: hello-world
       version: v1
     - kind: Namespace
       name: hello-world
       version: v1
     targetClusters:
     - aks-member-3
     - aks-member-2
     - aks-member-1
   ```
   
   All the resources under namespace `hello-world` (including the namespace) are selected and placed to all the member clusters.

3. Verify the application is deployed in the selected clusters:

   ```shell
   KUBECONFIG=member1 kubectl get all -n hello-world
   KUBECONFIG=member2 kubectl get all -n hello-world
   KUBECONFIG=member3 kubectl get all -n hello-world
   ```
   
   The output is similar to:

   ```console
   NAME                               READY   STATUS    RESTARTS   AGE
   pod/hello-world-6755976cfc-8qhht   1/1     Running   0          15m
   pod/hello-world-6755976cfc-c5p5j   1/1     Running   0          15m
   pod/hello-world-6755976cfc-df95b   1/1     Running   0          15m
   pod/hello-world-6755976cfc-mzwfd   1/1     Running   0          15m
   pod/hello-world-6755976cfc-rxtrj   1/1     Running   0          15m
   
   NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)          AGE
   service/my-service   LoadBalancer   10.0.190.234   13.78.193.35   8080:32614/TCP   15m
   
   NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
   deployment.apps/hello-world   5/5     5            5           15m
   
   NAME                                     DESIRED   CURRENT   READY   AGE
   replicaset.apps/hello-world-6755976cfc   5         5         5       15m
   ```

4. Access the running app:

   ```shell
   curl 13.78.193.35:8080
   ```

   ```console
   Hello Kubernetes!
   ```

Congratulations, you have deployed your first app through fleet workload placement.

#### Scenario B: Place to member clusters selected by names

Place to member clusters selected by names: `aks-member-1` and `aks-member-3` ([hello-world-crp-by-cluster-names.yaml](https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/helloworld/hello-world-crp-by-cluster-names.yaml)):

```shell
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/helloworld/hello-world-crp-by-cluster-names.yaml
```

Follow the instructions in scenario A to verify the outputs.

#### Scenario C: Place to member clusters selected by labels
Place to member cluster selected by label selectors: `fleet.azure.com/location: westcentralus` ([hello-world-crp-by-cluster-labels.yaml](https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/helloworld/hello-world-crp-by-cluster-labels.yaml)):

```shell
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/helloworld/hello-world-crp-by-cluster-labels.yaml
```

Follow the instructions in scenario A to verify the outputs.