# AKS Troubleshooting guide

## Problems

### Exposed service is not reachable from Internet

When the exposed service is not reacheable, the first thing to verify is whether the NSG rules are modified outs

If the NSG rules are OK, you can check if your service is reacheable using service's cluster IP from another pod. 
If that's not reacheable, it's likely that the iptable is out of sync. 
Try to delete the kube-proxy pod under `kube-system` namespace.

