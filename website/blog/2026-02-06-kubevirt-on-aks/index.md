---
title: "Deploying KubeVirt on AKS"
date: "2026-02-06"
description: "Learn how to use KubeVirt to host virtual machines on Azure Kubernetes Service (AKS)"
authors: ["jack-jiang", "harshit-gupta"]
tags: ["kubevirt", "general", "operations"]
---

Many organizations still depend on virtual machines (VMs) to run applications to meet technical, regulatory, or operational requirements. While Kubernetes adoption continues to grow, not every workload can or should be redesigned for containers.

[KubeVirt](https://github.com/kubevirt/kubevirt) is a [Cloud Native Computing Foundation (CNCF) incubating](https://www.cncf.io/projects/kubevirt/) open-source project that allows users to run, deploy, and manage VMs in their Kubernetes clusters.

In this post, you will learn how KubeVirt lets you run, deploy, and manage VMs in AKS.
<!-- truncate -->

:::note
If you're using KubeVirt on AKS or are interested in trying it, [we'd love to hear from you](https://github.com/Azure/AKS/issues/5445)! Your feedback will help the AKS team plan how to best support this feature on our platform.
:::

## Why KubeVirt matters

KubeVirt can help organizations that are in various stages of their Kubernetes journey manage their infrastructure more effectively. It allows customers to manage legacy VM workloads alongside containerized applications using the same Kubernetes API.

VMs deployed on KubeVirt act much the same way as VMs deployed in more traditional manners would but can run and be managed alongside other containerized applications through traditional Kubernetes tools. Capabilities like scheduling that users are familiar with on Kubernetes can also be applied to these VMs.

Management of these otherwise disparate deployments can be simplified and unified. This unified management can help teams avoid the sprawl that would otherwise come with managing multiple platforms.

The capability to mix and match your workloads in a "hybrid" setting can also allow organizations that might have more complex, legacy VM-based applications to incrementally transition to containers while ensuring their applications remain operational throughout the transition.

## Deploying KubeVirt on AKS

You can deploy KubeVirt on any AKS cluster that has nodes running VM SKUs that support nested virtualization.

### Prerequisites

- KubeVirt on AKS requires a chosen VM SKU to support nested virtualization. You can confirm support on the VM size's Microsoft Learn page, such as [Standard_D4s_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dv5-series?tabs=sizebasic#feature-support).
Using the [Standard_D4s_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dv5-series?tabs=sizebasic#feature-support) SKU as an example, on the SKU page, you can see whether or not nested virtualization is supported in the "Feature support" section.
- Install the `virtctl` binary utility to better access and control your VirtualMachineInstances. You can follow instructions [on the KubeVirt page](https://kubevirt.io/user-guide/user_workloads/virtctl_client_tool/) to install `virtctl`.

![Azure VM SKU documentation page showing nested virtualization feature marked as supported in the feature support table](nested-virt-example.png)

### Creating an AKS cluster

1. Create your AKS cluster.

   ```bash
   az aks create --resource-group <resource-group> --name <cluster-name> --node-vm-size Standard_D4s_v5
   ```

2. After your cluster is up and running, get the access credentials for the cluster.

   ```bash
   az aks get-credentials --resource-group <resource-group> --name <cluster-name>
   ```

### Installing KubeVirt

1. Install the KubeVirt operator.

   ```bash
   # Get the latest release
   export RELEASE=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
   
   # Deploy the KubeVirt operator
   curl -L https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml | \
   sed '8249,8254c\            nodeSelectorTerms:\n            - matchExpressions:\n              - key: node-role.kubernetes.io/worker\n                operator: DoesNotExist' | \
   kubectl apply -f -
   ```

1. Install the KubeVirt custom resource.

   ```bash
   curl -L https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-cr.yaml \
   | yq '.spec.infra.nodePlacement={}' \
   | kubectl apply -f -
   ```

   Notice the empty `nodePlacement: {}` and the update for the node selector. By default, KubeVirt sets the node-affinity of operator/custom resource components to control plane nodes. Because AKS control plane nodes are fully managed by Azure and inaccessible to KubeVirt, this update to utilize worker nodes avoids potential failures.

### Verify KubeVirt installation

Once all the components are installed, you can confirm that all KubeVirt components are up and running properly in your cluster:

```bash
kubectl get pods -n kubevirt -o wide
```

You should see something like this:

```bash
NAME                               READY   STATUS    RESTARTS   AGE     IP             NODE                                NOMINATED NODE   READINESS GATES
virt-api-7f7d56bbc5-s9nr4          1/1     Running   0          4m10s   10.244.0.174   aks-nodepool1-26901818-vmss000000   <none>           <none>
virt-controller-7c5744f574-56dd5   1/1     Running   0          3m39s   10.244.0.204   aks-nodepool1-26901818-vmss000000   <none>           <none>
virt-controller-7c5744f574-ftz6z   1/1     Running   0          3m39s   10.244.0.120   aks-nodepool1-26901818-vmss000000   <none>           <none>
virt-handler-dlkxf                 1/1     Running   0          3m39s   10.244.0.52    aks-nodepool1-26901818-vmss000000   <none>           <none>
virt-operator-7c8bdfb574-54cs6     1/1     Running   0          9m38s   10.244.0.87    aks-nodepool1-26901818-vmss000000   <none>           <none>
virt-operator-7c8bdfb574-wzdxt     1/1     Running   0          9m38s   10.244.0.153   aks-nodepool1-26901818-vmss000000   <none>           <none>
```

### Creating VirtualMachineInstance resources in KubeVirt

With KubeVirt installed on your cluster, you can now create your VirtualMachineInstance (VMI) resources.

1. Create your VMI. Save the following YAML, which will create a VMI based on Fedora OS, as `vmi-fedora.yaml`. The username for this deployment will default to `fedora`, while you can specify a password of your choosing in `password: <my_password>`.

   ```yaml
   apiVersion: kubevirt.io/v1
   kind: VirtualMachineInstance
   metadata:
     labels:
       special: vmi-fedora
     name: vmi-fedora
   spec:
     domain:
       devices:
         disks:
         - disk:
             bus: virtio
           name: containerdisk
         - disk:
             bus: virtio
           name: cloudinitdisk
         interfaces:
         - masquerade: {}
           name: default
         rng: {}
       memory:
         guest: 1024M
       resources: {}
     networks:
     - name: default
       pod: {}
     terminationGracePeriodSeconds: 0
     volumes:
     - containerDisk:
         image: quay.io/kubevirt/fedora-with-test-tooling-container-disk:devel
       name: containerdisk
     - cloudInitNoCloud:
         userData: |-
           #cloud-config
           password: <my_password>
           chpasswd: { expire: False }
       name: cloudinitdisk
   ```

1. Deploy the VMI in your cluster.

   ```bash
   kubectl apply -f vmi-fedora.yaml
   ```

   If successful, you should see an output similar to `virtualmachineinstance.kubevirt.io/vmi-fedora created`.

### Check out the created VMI

1. Test and make sure the VMI is created and running via `kubectl get vmi`. You should see a result similar to:

   ```bash
   NAME         AGE   PHASE     IP             NODENAME                            READY
   vmi-fedora   85s   Running   10.244.0.213   aks-nodepool1-26901818-vmss000000   True
   ```

1. Connect to the newly created VMI and inspect it.

   ```bash
   virtctl console vmi-fedora
   ```

   When prompted with credentials, the default username is `fedora`, while the password was configured in `vmi-fedora.yaml`.

   ```bash
   vmi-fedora login: fedora
   Password: 
   ```

   Once logged in, run `cat /etc/os-release` to display the OS details.

   ```bash
   [fedora@vmi-fedora ~]$ cat /etc/os-release
   NAME=Fedora
   VERSION="32 (Cloud Edition)"
   ID=fedora
   VERSION_ID=32
   VERSION_CODENAME=""
   PLATFORM_ID="platform:f32"
   PRETTY_NAME="Fedora 32 (Cloud Edition)"
   ANSI_COLOR="0;34"
   LOGO=fedora-logo-icon
   CPE_NAME="cpe:/o:fedoraproject:fedora:32"
   HOME_URL="https://fedoraproject.org/"
   DOCUMENTATION_URL="https://docs.fedoraproject.org/en-US/fedora/f32/system-administrators-guide/"
   SUPPORT_URL="https://fedoraproject.org/wiki/Communicating_and_getting_help"
   BUG_REPORT_URL="https://bugzilla.redhat.com/"
   REDHAT_BUGZILLA_PRODUCT="Fedora"
   REDHAT_BUGZILLA_PRODUCT_VERSION=32
   REDHAT_SUPPORT_PRODUCT="Fedora"
   REDHAT_SUPPORT_PRODUCT_VERSION=32
   PRIVACY_POLICY_URL="https://fedoraproject.org/wiki/Legal:PrivacyPolicy"
   VARIANT="Cloud Edition"
   VARIANT_ID=cloud
   ```

## Converting your VMs

At this point, you should have KubeVirt up and running in your AKS cluster and a VMI deployed. KubeVirt can help with a [plethora of scenarios](https://kubevirt.io/) that operational teams may run into. Migrating legacy VMs to KubeVirt can be an involved process, however. [Doing it manually](https://www.spectrocloud.com/blog/how-to-migrate-your-vms-to-kubevirt-with-forklift) involves steps like converting the VM disk and persisting a VM disk to creating a VM template.

Tools like [Forklift](https://github.com/kubev2v/forklift) can automate some of the complexity involved with the migration. Forklift allows VMs to be migrated at scale to KubeVirt. The migration can be done by installing Forklift custom resources and setting up their respective configs in the target cluster. Some great walkthroughs of VM migration can be found in these videos [detailing how Forklift helps deliver a better UX when importing VMs to KubeVirt](https://www.youtube.com/watch?v=S7hVcv2Fu6I) and [breaking down everything from the architecture to a demo of Forklift 2.0](https://www.youtube.com/watch?v=-w4Afj5-0_g).

## Running in prod

When running production grade workloads, stability of both the KubeVirt components and the individual VMs can also be a point of consideration. As we hinted at earlier, KubeVirt typically sets the node-affinity of operator/custom resource components to control-plane nodes. In our deployment, we have the KubeVirt components running on worker nodes.

In order to maintain a control-plane/worker node split, it can be advisable to aim to deploy KubeVirt components in an agentpool that can be designated as the "control-plane" node, while VMs spun up can be ran in designated "worker node" agentpools.

KubeVirt is currently not an officially supported AKS addon/extension, so there is no Microsoft backed SLA/SLO in place for KubeVirt deployments in AKS. If customers need an officially supported offering, [Azure Red Hat OpenShift](https://learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization) is a generally available platform to manage virtualized and containerized applications together.

## Share your feedback

If you're using KubeVirt on AKS or are interested in trying it, we'd love to hear from you! Your feedback will help the AKS team plan how to best support these types of workloads on our platform. Share your thoughts in our [GitHub Issue](https://github.com/Azure/AKS/issues/5445).

## Resources

- [What is KubeVirt?](https://www.redhat.com/topics/virtualization/what-is-kubevirt)
- [KubeVirt user guides](https://kubevirt.io/user-guide/)
- [Roadmap item for KubeVirt on AKS](https://github.com/Azure/AKS/issues/5445)
