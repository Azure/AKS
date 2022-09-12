# Example: Place HelloWorld application to  on Fleet

This directory contains the instructions on how to deploy a Hello World application using Fleet resource placement.

The application is from https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/.

## Before you begin
* Install [kubectl](https://kubernetes.io/docs/tasks/tools/).
* Create a fleet with three members following [this doc](???): `aks-member-1`, `aks-member-2`, and `aks-member-3`.
* Configure kubectl to communicate with your hub cluster.
* Get kubeconfig for member clusters.

## Objectives
* Deploy a Hello World application with a LB service in the hub cluster.
* Place the application to selected member clusters.
* Access the running application.

## Steps

### 1. Deploy to the Hub Cluster

Download and customize the application to use namespace hello-world.
```
wget https://k8s.io/examples/service/load-balancer-example.yaml

cat <<EOF >./kustomization.yaml
namespace: hello-world
resources:
- load-balancer-example.yaml
EOF
```

Deploy the application and expose a service: 
```
kubectl create namespace hello-world
kubectl apply -k ./

kubectl expose deployment hello-world -n hello-world --type=LoadBalancer --name=my-service
```

Verify the application is deployed but not running:
```
kubectl get all -n hello-world
```

Here is the expected output.
Note that the deployment is not deployed (`READY: 0/5`) and the service doesn't have an external IP (`EXTERNAL-IP: <pending>`).
This is working as expected as the objective to deploy the application to member clusters not the hub cluster.

```
NAME                 TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
service/my-service   LoadBalancer   10.0.184.49   <pending>     8080:32614/TCP   4s

NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-world   0/5     0            0           28s
```

### 2. Place to Selected Member Clusters

Place to all the member clusters:
```
kubectl apply -f https://k8s.io/examples/service/load-balancer-example.yaml
```

### 3. Access the Application