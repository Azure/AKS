# Example: Place HelloWorld application to  on Fleet

This directory contains the instructions on how to deploy a Hello World application using Fleet resource placement.

The application is from https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/.

## Before you begin
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/).
* Create a fleet with three members following [this doc](???): `aks-member-1`, `aks-member-2`, and `aks-member-3`.
* Configure kubectl to communicate with your hub cluster.
* Get kubeconfig files for member clusters as `member1`, `member2`, and `member3`.

## Objectives
* Deploy a Hello World application with a LB service in the hub cluster.
* Place the application to selected member clusters, and access the running application.

## Steps

### 1. Deploy to the Hub Cluster

Download and customize the application to use namespace hello-world.
```bash
wget https://k8s.io/examples/service/load-balancer-example.yaml

cat <<EOF >./kustomization.yaml
namespace: hello-world
resources:
- load-balancer-example.yaml
EOF
```

Deploy the application and expose a service: 
```bash
kubectl create namespace hello-world
kubectl apply -k ./

kubectl expose deployment hello-world -n hello-world --type=LoadBalancer --name=my-service
```

Verify the application is deployed but not running:
```bash
kubectl get all -n hello-world
```

Here is the expected output.
Note that the deployment is not deployed (`READY: 0/5`) and the service doesn't have an external IP (`EXTERNAL-IP: <pending>`).
This is working as expected as the objective to deploy the application to member clusters not the hub cluster.

```text
NAME                 TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
service/my-service   LoadBalancer   10.0.184.49   <pending>     8080:32614/TCP   4s

NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-world   0/5     0            0           28s
```

### 2. Place to Member Clusters

#### Scenario A: Place to all member clusters

Place to all the member clusters:
```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/liqian/fleet/examples/fleet/helloworld/hello-world-crp-all-clusters.yaml
```

```yaml:hello-world-crp-all-clusters.yaml
```

Verify the placement status:
```bash
kubectl get crp hello-world -o yaml | grep status -A 1000
```

Here is the expected output.
All the resources under namespace `hello-world` (including the namespace) are selected and placed to all the member clusters.
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

Verify the application is deployed in the selected clusters:
```bash
KUBECONFIG=member1 kubectl get all -n hello-world
```

Here is the expected output.
```text
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

Access the running app:
```bash
curl 13.78.193.35:8080
```
```text
Hello Kubernetes!
```
Congratulations, you have deployed your first app through fleet workload placement.

#### Scenario B: Place to member clusters selected by names
```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/liqian/fleet/examples/fleet/helloworld/hello-world-crp-by-cluster-names.yaml
```

#### Scenario C: Place to member clusters selected by labels
```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/liqian/fleet/examples/fleet/helloworld/hello-world-crp-by-cluster-labels.yaml
```