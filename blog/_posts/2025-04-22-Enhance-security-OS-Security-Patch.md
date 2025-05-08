---
title: "Enhancing Your Operating System's Security with OS Security Patches in AKS"
description: "Learn the what, the whys, and the hows of configuring OS Security Patch Auto upgrade channel.  The article also covers some reasons for OS Security Patch, with some primary benefits being increased performance, better security, and minimal disruption to workloads."
date: 2025-04-22
authors:
- Kaarthikeyan Subramanian
- Ye Wang
categories: 
- Security
- Operations
---


## Traditional patching and the need for Managed patching.

Operating System (OS) security patches are critical for safeguarding systems against vulnerabilities that malicious actors could exploit. These patches help ensure your system remains protected against emerging threats. Traditionally, customers have relied on nightly updates, such as [unattended upgrades in Ubuntu](https://help.ubuntu.com/community/AutomaticSecurityUpdates) or [Automatic Guest OS Patching](https://learn.microsoft.com/en-us/azure/virtual-machines/automatic-vm-guest-patching) at the virtual machine (VM) level. However, when kernel security packages were updated, a host machine reboot was often required, typically managed using tools like [kured](https://github.com/kubereboot/kured). 

This approach, while effective, introduced challenges. Untested or uncontrolled security packages occasionally caused outages, emphasizing the need for a more reliable and managed patching mechanism at the node level. Additionally, maintaining reboot daemonsets like [kured](https://github.com/kubereboot/kured) added operational overhead for many customers. Ideally, customers prefer managed Kubernetes services, such as Azure Kubernetes Service (AKS), to handle OS security patching comprehensively and seamlessly.

## Automatic Node OS Security Patching mechanisms at AKS

AKS provides two managed and tested mechanisms to deliver the latest security packages to your Node Operating System. 

**Automatic Node Image Channel** - AKS updates nodes weekly with a newly patched VHD for security and bug fixes. This update follows maintenance windows and upgrade configuration settings. Automatic Node image upgrades are supported as long as the cluster's Kubernetes minor version is in support. These AKS-tested node images are fully managed and applied with safe deployment practices.

**OS Security Patch Channel** - Several customers may need only the security packages for their OS without additional bug fixes and updates. The OS Security Patch channel provides a fully managed, attended Node OS security-only solution. The Security-Patch channel reimages nodes only when necessary and provides live security patching updates with zero disruption, respecting planned maintenance windows and follows azure safe deployment practices.


## When to use OS Security Patch or Automatic Node Image Channel?

Choosing between the OS Security Patch channel and the Automatic Node Image channel depends on your specific requirements and operational constraints. Here's a breakdown based on common scenarios:

- **Speed of Patching is Paramount**: If addressing critical vulnerabilities (CVEs) promptly is a priority, the OS Security Patch channel is the better choice. It delivers updates 1 to 2 weeks faster than the Node Image channel, ensuring your workloads remain secure against emerging threats.

- **Require Comprehensive Security Fixes and Bug Fixes**: For environments where both security patches and additional bug fixes or binaries are essential, the Node Image channel is ideal. It provides a more comprehensive update approach, ensuring both security and functionality improvements.

- **Workload Sensitive to Multiple Reimages in a Month**: If your workloads cannot tolerate frequent disruptions, the OS Security Patch channel is preferable. It minimizes disruptions by focusing solely on security packages, reimaging nodes 60-70% less frequently, and performing live security patching during other times.

- **Using Windows Environment for Running Workloads**: Currently, the OS Security Patch channel is better suited for Linux-based workloads. For Windows environments, the Node Image channel is recommended until OS Security Patch support for Windows is introduced.

- **Operating in a Capacity-Constrained Region or SKU**: In regions or SKUs with limited capacity, the OS Security Patch channel is advantageous. Its reduced frequency of node reimages helps mitigate surging and ensures smoother operations in constrained environments.

By carefully evaluating these factors, you can select the channel that best aligns with your operational needs and workload requirements.

## How to Enable OS Security Patch Channel?
You can enable the OS Security Patch Channel using the API, CLI, or the AKS portal. For detailed CLI configuration steps, refer to this [guide](https://learn.microsoft.com/azure/aks/auto-upgrade-node-os-image?tabs=azure-cli#set-the-node-os-autoupgrade-channel-on-a-new-cluster).

## Best Practices when using OS Security Patch Channel
   
 Here are some tips to go about doing this. 

- **Configure Maintenance Windows**: Configure [Planned Maintenance window](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli) to apply security patches during periods of low activity. This minimizes the impact on workloads and ensures that updates are applied seamlessly. 
- **Configure Cluster Auto-Upgrade Channel**: To maximize the benefits of OS security patches, it is recommended to enable the SecurityPatch channel alongside the [Kubernetes cluster auto upgrade channel](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster?tabs=azure-cli). This dual-channel approach ensures that both the control plane and node pools are kept up-to-date with the latest security patches.
- **Configure Upgrade Monitoring**: Regularly monitor the status of ongoing upgrades to ensure that patches are applied successfully. Utilize tools such as the [AKS Communication Manager](https://learn.microsoft.com/azure/aks/aks-communication-manager) to get periodic notifications on OS Patching updates. 
- **Use Release Tracker**: [AKS release tracker](https://releases.aks.azure.com/webpage/index.html) provides region by region updates on what security patch version runs in a particular region. These real-time updates are crucial for closely tracking CVEs. There is also a AKS CVE status tab.![Screenshot of the AKS release tracker showing region-specific security patch updates!](/AKS/assets/images/enhance-security-with-os-security-patch/sec-patch-reltracker.jpg).


### What Is Coming Next for OS Security Patch?

The future of OS security patches promises several enhancements aimed at improving the patching process and ensuring even greater security:

- [Support for Network Isolated Cluster](https://github.com/Azure/AKS/issues/4962).
- [Snapshotting similar to Ubuntu in Azure Linux](https://github.com/Azure/AKS/issues/4963).
- [Kubelet and ContainerD patching via OS security patch](https://github.com/Azure/AKS/issues/4964).
- [Support for Windows environment](https://github.com/Azure/AKS/issues/4989).
 
 To learn more OS Security patch intricacies as well as other interesting AKS topics refer to this Youtube [video](https://www.youtube.com/watch?v=Cw4pnfMVHxg).