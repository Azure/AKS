# Revert Kubernetes 1.25 to cgroup v1

As cgroup v2 is GA in 1.25+, and is also the default on Ubuntu 22.04, customers may have to downgrade to cgroups v1 due to compatibility issues with older software.

To perform a cgroups version downgrade on your nodes, use this [Daemonset](./revert-cgroup-v1.yaml).

## Important note

The Daemonset by default will apply to all nodes in your cluster and will reboot them to apply the cgroup change.  Please set a nodeSelector to control how this gets applied.

## Java related issues

If you observe memory issues with Java-based systems and products, you may have to update your JDK installation to a newer minor version that supports cgroups v2.

* JDK 8: 1.8.0_372 or later
* JDK 11: 11.0.18 or later

If updating the JDK is not an option, an alternative is by downgrading to cgroups v1.
