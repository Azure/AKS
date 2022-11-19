The kernel version '5.4.0-1095-azure' has a [bug](https://bugs.launchpad.net/ubuntu/+source/containerd/+bug/1996678).

AKS users can check for nodepools that are impacted by running 'kubectl get nodes -o wide' command to find all nodes running with the kernel version '5.4.0-1095-azure'. If impacted, AKS users can use the script `remediate.sh` to remediate the issue. The script identifies the impacted nodes in the cluster, cordon and drain the node, and re-image the VMSS instance.

**NOTE**: As this script will cause modification in the environment and AKS deployment, it must be reviewed to understand what it does as well as run in testing environment before to confirm that it won't cause any issue when deployed into production systems.
