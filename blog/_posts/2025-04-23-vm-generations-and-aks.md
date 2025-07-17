---
title: "Azure VM Generations and AKS"
description: "Learn more about Generation 1 and Generation 2 VMs and what they offer, differences between them, upcoming Generation 1 VM retirements, and how to move your AKS workloads to Generation 2 VMs."
date: 2025-04-23 # date is important. future dates will not be published
authors: 
   - Jack Jiang
   - Ally Ford
   - Sarah Zhou
categories: 
- operations
---
## What are Virtual Machine Generations?

If you are a user of Azure, you may be familiar with virtual machines. What you may not have known is the fact that Azure now offers two generations of virtual machines! 

Before going further, let's first break down virtual machines. Azure virtual machines are offered in various "sizes," which are broken down by the amount and type of each resource allocated, such as CPU, memory, storage, and network bandwidth. These resources are
tied to a portion of a physical server's hardware capabilities. Physical servers may be broken down into many different VM *size series* or
configurations available utilizing its resources. 

As the physical hardware ages and newer components become available, older hardware and VMs get retired, while newer generation hardware and VM products are made available.

In this blog, we will go over Generation 1 and newer Generation 2 virtual machines. Both have their own use cases, and [picking the right one](https://learn.microsoft.com/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v) 
to suit your workloads is critical in ensuring you get the best possible experience, capabilities, and cost.  

### Virtual Machine Generation Overview

Azure VM sizes (v5 and older) have largely supported both Generation 1 and Generation 2 VMs. [This page](https://learn.microsoft.com/azure/virtual-machines/generation-2)
gives a thorough breakdown on VM series and the generation they support. 

The latest v6 VMs (whether they are 
[Intel](https://techcommunity.microsoft.com/blog/azurecompute/announcing-general-availability-of-azure-dlde-v6-vms-powered-by-intel-emr-proces/4376186), 
[AMD](https://techcommunity.microsoft.com/blog/azurecompute/new-daeafav6-vms-with-increased-performance-and-azure-boost-are-now-generally-av/4309381), or 
[ARM](https://azure.microsoft.com/blog/azure-cobalt-100-based-virtual-machines-are-now-generally-available/?msockid=150f515112e461e5201d45b1136e602c)
will exclusively support Generation 2 VMs.

### Comparing Generation 1 & Generation 2
Generation 2 VMs offer exclusive features over Generation 1 VMs, such as increased memory, improved CPU performance, support for NVMe disks, and support for Trusted 
Launch. With some [exceptions](https://learn.microsoft.com/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v),
it is generally recommended to migrate to Generation 2 VMs to take advantage of the newest features and functionalities in Azure VMs.

The table below summarizes some key differences between Generation 1 and Generation 2 VMs. For a more detailed comparison, please refer to this [page](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn282285(v=ws.11)).

| **Feature** | **Generation 2 VM** | **Generation 1 VM** |
|--------------------|-----------------------|-----------------------|
| Firmware Interface | UEFI (Unified Extensible Firmware Interface)-based boot ([Additional security features and faster boot times](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-uefi#uefi-benefits)) | BIOS (Basic Input/Output System)-based boot (Legacy) |
| Latest v6 VM Support | v6 VMs support Generation 2 VMs | v6 VMs do **NOT** support Generation 1 VMs |
| Trusted Launch | Can enable [Trusted Launch](https://learn.microsoft.com/azure/virtual-machines/trusted-launch), which includes protections like virtual Trusted Platform Module (vTPM) | Can **NOT** enable Trusted Launch |
| NVMe Interface Support | Supports [NVMe disks](https://learn.microsoft.com/azure/virtual-machines/nvme-overview), which requires NVM-enabled Generation 2 image | Does **NOT** support NVMe disks |

### Implications for your Virtual Machines
If you are already running on Generation 2 VMs, you are all set to deploy on the majority of Azure VMs, including the latest v6 VMs. You can also enable [Trusted Launch](https://learn.microsoft.com/azure/aks/use-trusted-launch) and the NVMe Interface. 

If you are running on Generation 1 VMs, you can continue running on most v5 and older Azure VMs. Migration to Generation 2 VMs is recommended, especially if any of the following requirements apply: 
- You require Trusted Launch for your workloads 
- You require NVMe interface for your workloads
- You want/need to migrate to the latest v6 VMs 

## VM Generation Support on AKS

### Generation 2 Default

AKS supports both Generation 1 and 2 VMs with all operating systems on AKS. The VM size and operating system that you select when creating an AKS node pool determines which VM Generation you will use. 
- When creating Linux node pools on AKS, the default will be a Generation 2 VM unless the VM size does not support it. 
- When creating Windows Server 2025 node pools on AKS, the default will be a Generation 2 VM unless the VM size does not support it.  
- When creating Windows Server 2019 and Windows Server 2022 node pools on AKS, the default will be Generation 1 VM unless the VM size does not support it. To use a Generation 2 VM, you must add `--aks-custom-headers UseWindowsGen2VM=true` during node pool creation. 

For more information on Generation 2 default behavior on AKS, see [AKS documentation](https://learn.microsoft.com/azure/aks/generation-2-vm).

For a list of supported VM sizes for Generation 1 and Generation 2, please refer to the table on [this page](https://learn.microsoft.com/azure/virtual-machines/generation-2#generation-2-vm-sizes).

### Generation 1 VM Retirements
When a VM size or series reaches its retirement date, the VM will be deallocated. VM deallocation means that your AKS node pool may experience breakage.

If you would like to confirm whether your Generation 1 VM sizes are retired or are being retired, please search in the [Azure Updates](https://azure.microsoft.com/updates) 
page.

## Migrating From Retired VM Sizes

If you are using a VM size that is retiring/retired, to prevent any potential disruption to your service, it is recommended to resize your node pool(s) to a supported VM size. AKS does not currently support transitioning to a new VM size within the same node pool, so a new node pool will be created and workloads moved to it during the resizing process. 

### What VM sizes are my nodes?
To determine the size of your nodes, navigate to the Azure Portal, access your Resource Group, and then select your AKS resource. Within the "Overview" tab, you will find the size of your node pool.


Alternatively, you may run this command in the Azure CLI. Make sure you fill in the names of your resource group and cluster name: 
```azurecli-interactive
az aks nodepool list \
--resource-group <yourResourceGroupName> \ 
--cluster-name <yourAKSClusterName> \ 
--query "[].{Name:name, VMSize:vmSize}" \ 
--output table 
```

### Resizing your node pools
After you determine the appropriate node pool(s) to take action on, you can [**resize**](https://learn.microsoft.com/azure/aks/resize-node-pool?tabs=azure-cli) your node pool(s) to a supported VM size.


When [**resizing**](https://learn.microsoft.com/azure/aks/resize-node-pool?tabs=azure-cli) a node pool, you'll go through the process of creating a new node
pool with your desired VM size while the existing node pool is cordoned, drained, and ultimately removed.

Depending on the needs of your infrastructure and workloads, when resizing your node pool, please make sure that you pick a new VM size that will best suit your needs.

Note that these instructions are in reference to node pools. If you are using [Virtual Machines node pools](https://learn.microsoft.com/en-us/azure/aks/virtual-machines-node-pools), VMs should all be Generation 2 by default.

