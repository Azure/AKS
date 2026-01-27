---
title: "Navigating Capacity Challenges on AKS with Node Auto Provisioning or Virtual Machine Node Pools"
description: "Learn how Node auto provisioning and Virtual Machine node pools can address capacity constraints when scaling an AKS cluster"
date: 2026-01-30
authors: ["wilson-darko"]
tags:
  - node-auto-provisioning
  - vm-node-pools
---

## When Growth Meets a Wall

Imagine this: your application is thriving, traffic spikes, and Kubernetes promises elasticity. You hit “scale,” expecting magic—only to be greeted by cryptic errors like:

- **Insufficient regional capacity**: Azure can’t allocate the VM size you requested in a particular region or zone.
- **Quota exceeded**: Your subscription has hit its compute limits for a particular location or VM size.
- **Zonal allocation failure**: The VM size (also referred to as VM SKU) you chose isn’t available in the zone.

For customers, these aren’t just error messages - they’re roadblocks. Pods remain pending, deployments stall, and SLAs tremble. Scaling isn’t just about adding nodes; it’s about finding capacity in a dynamic, multi-tenant cloud where demand often outpaces supply. In the case of quota gaps, usually a user can increase their quota in a particular location - but what about when a specific virtual machine size (also known as "VM SKU") is simply unavailable? This can cause many challenges for users.

---

<!-- truncate -->

:::info

Learn more in the official documentation: [Node Auto Provisioning](https://learn.microsoft.com/azure/aks/node-auto-provisioning) or [Virtual Machine Node Pool](https://learn.microsoft.com/azure/aks/virtual-machines-node-pools)

:::

---

## The Hidden Complexity Behind Capacity

When using Kubernetes, every node pool is typically tied to a specific VM SKU, region, and zone, which can require some effort to update. In some scaling scenarios, high-demand VM SKUs can become unavailable in certain regions or zones. In this case node pools being limited to one VM size is now a bottleneck that can result in capacity errors and an outage. You’re left juggling trade-offs: Do you overprovision SKUs “just in case” to ensure availability? Or risk underprovisioning and inability to scale? AKS offers two solutions that aim to address these capacity scaling challenges.

---

## Breaking the Mold: Features That Change the Game

### Node auto provisioning (NAP): Smarter Scaling

NAP offers a more intelligent scaling experience. Instead of you guessing the right VM size, NAP uses **pending pod resource requests** to dynamically provision nodes that fit your workloads. Built on the open-source **Karpenter** project, NAP:

- **Automates VM selection**: Chooses optimal SKUs based on CPU, memory, and constraints.
- **Consolidates intelligently**: Removes underutilized nodes, reducing cost.
- **Adapts in real time**: Responds to pod pressure without manual intervention.

Think of NAP as Kubernetes with foresight: provisioning what you need, when you need it, without the spreadsheet gymnastics. Without NAP, a single unavailable VM SKU can block scaling entirely. With NAP, AKS dynamically adapts to capacity fluctuations, ensuring workloads keep running on available VM sizes, even during regional/zonal shortages.

#### How NAP handles capacity errors

When a requested VM SKU isn’t available due to regional or zonal capacity constraints, NAP doesn’t fail outright. Instead, NAP will automatically:

- Evaluate pending pod resource requirements (CPU, memory, GPU, etc.)
- Check if pending pods can fit on existing nodes
- Search across multiple VM SKUs within the allowed families defined in your NAP configuration files (custom resource definitions referred to as the NodePool and AKSNodeClass CRDs)
- Provision an alternative SKU that meets the workload requirements and policy constraints
- In the event that no VM sizes that match your requirements are available, NAP will only then send an error detailing that "No available SKU that meets your configuration definition is available".  **Mitigation**: Make sure you reference a broad range of size options in the NAP configuration files (e.g. D-series, multiple SKU families)

This flexibility is key to avoiding hard failures during scale-out. In the scenario where there is no SKUs available based on your configuration requirements, NAP will return an error stating that there were no available SKUs that matched your requirements. Typically this means the configuration requirements probably can be broader, to allow for more available VM sizes.

For more on enabling NAP on your cluster, visit our [NAP documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning) as well as our docs on configuring the [NodePool CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools) and [AKSNodeClass CRD](https://learn.microsoft.com/azure/aks/node-auto-provisioning-aksnodeclass).

### Virtual machine node pools: Flexibility at scale

Traditional node pools are rigid: one SKU per pool. Virtual Machine node pools break that limitation. With multi-SKU support, you can:

- Mix VM sizes within a single pool for diverse workloads
- Fine-tune capacity without creating dozens of pools
- Reduce operational overhead while improving resilience

This isn’t just flexibility - it’s versatility in capacity-constrained regions.

#### How virtual machine node pools handle capacity errors

You can manually add or update alternative VM SKUs into your new or existing node pools. When a requested VM SKU isn't available due to a regional or zonal capacity constraint, you will receive a capacity error, and can resolve this error by simply adding and updating the VM SKUs in your node pools.

For more on enabling Virtual Machine node pools on your cluster, visit our [Virtual Machine node pools documentation](https://learn.microsoft.com/azure/aks/virtual-machines-node-pools).

## Quick guidance: When to Use What

Generally, using NAP or Virtual Machine node pools are mutually exclusive. You can use NAP to create standalone VMs which NAP manages instead of traditional node pools, which allows for **mixed SKU autoscaling**. Virtual Machine node pools uses traditional node pools, but allows for **mixed SKU manual scaling**.

- (Recommended) Choose NAP for dynamic environments where manual SKU planning is impractical
- Choose Virtual Machine node pools when you need fine-tuned control with exact VM SKUs for compliance, predictable performance, or cost modeling

Avoid NAP if you require strict SKU governance or have regulatory constraints that cannot allow for dynamic autoscaling. Avoid VM node pools if you want full automation without manual profiles.

## Best practice for resilience

To maximize NAP's ability to handle capacity errors:

- Define broad SKU families (e.g., D, E) in your NodePool requirements
- Avoid overly restrictive affinity rules. Visit our [affinity rules documentation](https://learn.microsoft.com/azure/aks/operator-best-practices-advanced-scheduler#control-pod-scheduling-using-node-selectors-and-affinity) on best practices
- Enable multiple NodePools with different priorities for fallback. Visit our [NAP Node Pool documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools) to learn more

To maximize Virtual Machine node pool's ability to adapt to capacity errors:

- Be clear on a list of VM SKUs that can tolerate your workloads. Visit our [Azure VM Sizes documentation](https://learn.microsoft.com/azure/virtual-machines/sizes/overview#list-of-vm-size-families-by-type) for more details
- Create virtual machine node pools to offer resiliency to your workloads. Visit our [Virtual machine node pool documentation](https://learn.microsoft.com/azure/aks/virtual-machines-node-pools) on how to add a mixed SKU node pool

## Getting started with node auto provisioning

Before you begin, visit our [NAP documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning#limitations-and-unsupported-features) on minimum cluster requirements.

### Create a new NAP-managed AKS cluster

The following command creates a new NAP-managed AKS cluster by setting the `--node-provisioning-mode` field to `Auto`. This command also sets the network configuration to the recommended Azure CNI Overlay with a Cilium dataplane (optional). View our [NAP networking documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning-networking#supported-networking-configurations-for-nap) for more on supported CNI options.

```azure-cli
az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --node-provisioning-mode Auto --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium
```

### Update an existing cluster to be a NAP-managed cluster

The following command updates an existing cluster to enable NAP:

```azure-cli
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --node-provisioning-mode Auto
```

### Configure NAP custom resource definitions

NAP uses custom resource definition (CRDs) and your application deployment file requirements for its decision-making around which virtual machines to provision and schedule your workloads to. This includes:

- NodePool - for setting rules around the range of VM sizes,  capacity type (spot vs. on-demand), compute architecture, availability zones, etc
- AKSNodeClass - for setting rules around certain Azure specific settings such as more detailed networking (virtual networks) setup, node image family type, operating system configurations, and other resource-related definitions

Visit our [NAP NodePool Documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning-node-pools) and [NAP AKSNodeClass documentation](https://learn.microsoft.com/azure/aks/node-auto-provisioning-aksnodeclass) for more on configuring these files.

## Getting started with virtual machine node pools

### Create a new AKS cluster with virtual machine node pools

The following example creates a new cluster named myAKSCluster with a Virtual Machines node pool containing two nodes with size "Standard_D4s_v3", and sets the Kubernetes version to 1.31.0:

```azure-cli
az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type "VirtualMachines" --vm-sizes "Standard_D4s_v3"
    --node-count 2 --kubernetes-version 1.31.0
```

### Add a new virtual machine node pool to an existing cluster

The following example adds a Virtual Machines node pool named myvmpool to the myAKSCluster cluster. The node pool creates a ManualScaleProfile with --vm-sizes set to Standard_D4s_v3 and a --node-count of 3:

```azure-cli
az aks nodepool add --resource-group myResourceGroup --cluster-name myAKSCluster --name myvmpool --vm-set-type "VirtualMachines" --vm-sizes "Standard_D4s_v3" --node-count 3
```

With Virtual Machine node pools you can also perform some of the following commands:

- Add multiple VM sizes in an existing or new node pool
- Update VM sizes in an existing node pool
- Single-SKU autoscaling (public preview)
- Delete VM sizes in an existing node pool

Visit our [Virtual Machine node pools documentation](https://learn.microsoft.com/azure/aks/virtual-machines-node-pools) for more info.

## What’s next on the AKS roadmap

NAP: Expect deeper integration with cost optimization tools and advanced disruption policies for even smarter consolidation.
Virtual Machine node pools: Multi-SKU auto-scaling (general availability) is on the horizon, reducing manual configuration and enabling adaptive scaling across mixed SKUs.

## Next steps

Ready to get started?

1. **Try one of these features now:** Follow the [Enable node auto provisioning steps](https://learn.microsoft.com/azure/aks/use-node-auto-provisioning) or [create a Virtual Machine node pool](https://learn.microsoft.com/azure/aks/virtual-machines-node-pools).
1. **Share feedback:** Open issues or ideas in [AKS GitHub Issues](https://github.com/Azure/AKS/issues).
1. **Join the community:** Subscribe to the [AKS Community YouTube](https://www.youtube.com/@theakscommunity) and follow [@theakscommunity](https://x.com/theakscommunity) on X.
