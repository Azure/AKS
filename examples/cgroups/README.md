# Revert Kubernetes 1.25 to cgroup v1

JDK 10 introduced ```UseContainerSupport``` which provided support for running Java applications within containers. 

The Java runtime will use the cgroup filesystem to understand the memory and cpu availability.

With the introduction of cgroup v2, the location of these files has changed and Java applications prior to JDK 15 will exhibit significant memory consumption which may make your environments unstable.

As cgroup v2 is GA in 1.25, and is also the default on Ubuntu 22.04, customers should migrate their applications to JDK 15+.

An alternative temporary solution is to revert the cgroup version on your nodes using this  [Daemonset](./revert-cgroup-v1.yaml).



## IMPORTANT NOTE

The Daemonset by default will apply to all nodes in your cluster and will reboot them to apply the cgroup change.  Please set a nodeSelector to control how this gets applied.