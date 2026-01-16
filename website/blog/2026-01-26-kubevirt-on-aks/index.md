---
title: "Deploying KubeVirt on AKS"
date: "2026-01-26"
description: "Learn how to set up KubeVirt on an AKS cluster."
authors: ["jack-jiang", "harshit-gupta"]
tags: ["general", "operations"]
---

As the adoption of Kubernetes and cloud-native infrastructure continues to grow, it is also clear that not every setup can simply be re-archituctured immediately to be deployed in a Kubernetes-esque manner. For the myraid of reasons that folks might want or have to remain in virtual-machine based deployments, there are many approaches to addressing that need. This post will walk through KubeVirt, an OSS project that enables uesrs to run, deploy, and manage VMs while leaning on Kubernetes as the orchestrator. 

## What is KubeVirt?

[KubeVirt](https://github.com/kubevirt/kubevirt) is an OSS project, sponsored by the [Cloud Native Computing Foundation (CNCF)](https://www.cncf.io/projects/kubevirt/), that allows users to run, deploy, and manage VMs in their Kubernetes clusters. 

VMs deployed on KubeVirt act much the same way as VMs deployed in more traditional manners would, but can run and be managed alongside other containerized applications through traditional Kubernetes tools. Capabilities, like scheduling, that users know and love on Kubernetes can also be applied to these VMs. Management of these otherwise disprit deployments can be simplified and unified. This capability to mix and match your workloads in a "hybrid" setting can also allow organizations that might have more complex, legacy VM-based applications to incrementally transition to containers.

## Resources

- [What is KubeVirt?](https://www.redhat.com/en/topics/virtualization/what-is-kubevirt)
