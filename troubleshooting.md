# AKS Troubleshooting guide

## Problems

### Exposed service is not reachable from Internet

When the exposed service is not reachable, the first thing to verify is whether the NSG rules are modified from the stock configurations maintained by Kubernetes.

If the NSG rules are OK, you can check if your service is reachable using the service cluster IP from another pod. 
If that's not reachable, it's likely that iptables is out of sync. 
Try to delete the kube-proxy pod under `kube-system` namespace.

