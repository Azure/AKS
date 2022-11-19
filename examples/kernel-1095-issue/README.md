The kernel version '5.4.0-1095-azure' has a [bug](https://bugs.launchpad.net/ubuntu/+source/containerd/+bug/1996678).

AKS users can check for nodepools that are impacted by running 'kubectl get nodes -o wide' command to find all nodes running with the kernel version '5.4.0-1095-azure'. If impacted, AKS users can use the script `remediate.sh` to remediate the issue. The script identifies the impacted nodes in the cluster, cordon and drain the node, and re-image the VMSS instance.

**NOTE**: The user needs to review the script and understand what it's going to do. The script must be run in testing environment to confirm that it won't cause any issue in production.