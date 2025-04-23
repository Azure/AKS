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


## Why Do We Need Security Patches at the Node Operating System Level?

Operating System (OS) security patches are crucial for maintaining the integrity and security of your systems. These patches address vulnerabilities that could be exploited by malicious actors, ensuring that your system remains protected against the latest threats. Regular OS security patches safeguard data, ensure compliance, and prevent disruptions. At Azure Kubernetes service we are constantly working hard and innovating to guarantee maximum security for your Node operating systems. 
Presently there are two ways to apply security patches at the OS level automatically with AKS. Read more [OS Security Patch](https://learn.microsoft.com/azure/aks/auto-upgrade-node-os-image?tabs=azure-cli)

**Auto Node Image Channel** - AKS updates nodes weekly with a newly patched VHD for security and bug fixes. This update, which follows maintenance windows and surge settings, incurs no extra VHD cost. Linux unattended upgrades are disabled by default when using this channel. Node image upgrades are supported as long as the cluster's Kubernetes minor version is in support. These AKS-tested node images are fully managed and applied with safe deployment practices.
**OS Security Patch Channel** - Several customers may need only the security packages for their OS without additional bug fixes and updates. Previously, customers relied on nightly updates and reboot mechanisms, such as KURED, for security updates. Untested package outages highlighted the need for a managed security patch-only channel at the node level. The OS Security Patch channel provides a fully managed, attended Node OS security-only solution. It automates manual processes, eliminating the need for tools like KURED. The Security-Patch channel reimages nodes only when necessary and provides live patch updates with zero disruption, respecting planned maintenance windows.

## OS Security Patch channel - How it fares against Node Image Channel
When comparing OS security patch channel with the Node Image channel, several advantages become apparent:

- **Faster Patching Cadence**: The OS Security Patch channel delivers updates 1 to 2 weeks faster than the Node Image channel, addressing critical vulnerabilities (CVEs) promptly. This ensures quicker protection against threats and reduces exposure time.
- **Minimal Disruptions to workload**: OS security patches focus solely on security packages, avoiding the inclusion of binaries and bug fixes that could potentially disrupt workloads. This targeted approach minimizes disruptions, making it ideal for maintaining Workload Service Level Objectives (SLOs), especially if you are sensitive to dependencies. The OS Security Patch channel reimages approximately 60-70% less frequently than the Auto Node Image channel. In other words, if the Node Image channel reimages 10 times within a certain period, the OS Security Patch channel would likely reimage only 3 or 4 times during the same timeframe.
- **Better way to handle capacity Constraints**: Every reimage typically results in the creation of 'Surge' nodes, which can be problematic if you are operating in a capacity-constrained region or SKU. The OS Security Patch channel reduces surging by reimaging 60-70% less frequently than the Auto Node Image channel. This makes it an ideal solution for workloads with capacity constraints.
- **Livepatching and Ubuntu snapshots**: Canonical snapshots are now [seamlessly integrated for Ubuntu in AKS](https://techcommunity.microsoft.com/blog/linuxandopensourceblog/increased-security-and-resiliency-of-canonical-workloads-on-azure---now-in-previ/3970623). With the OS Security Patch channel, Ubuntu cluster nodes automatically download essential security patches and updates from the Ubuntu snapshot service, ensuring predictability and consistency in cloud deployments. AKS rigorously tests these security packages and releases them through safe deployment practices under Azure. The OS Security Patch channel also features Livepatching capabilities for both Ubuntu and Azure Linux systems, significantly reducing the need for reimaging. Reimaging is only necessary for critical updates, such as Kernel package updates, making maintenance more efficient and less disruptive.

If your requirements go beyond just OS security packages and include bug fixes or additional binary updates, the Node Image channel would be the better choice. While the OS Security Patch channel excels in providing faster security updates with minimal disruptions, the Node Image channel offers a more comprehensive update approach, addressing both security and functionality enhancements.

## How to Enable OS Security Patch Channel?

### While creating cluster in Portal

1. In the Azure portal, select Create a resource > Containers > Azure Kubernetes Service (AKS).
2. In the Basics tab, under Cluster details, select the desired channel type from the Node security channel type dropdown.
![Screenshot of the Azure portal showing cluster details for security patch configuration!](/blog/assets/images/enhance-security-with-os-security-patch/create-secpatch.jpg).
3. Select Security channel scheduler and choose the desired maintenance window using the [Planned Maintenance feature](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli). We recommend selecting the default option Every week on Sunday (recommended).
![Security Patch Schedule!](/blog/assets/images/enhance-security-with-os-security-patch/sec-channel-schedule.png).

### For Existing clusters in portal

1. In the Azure portal, navigate to your AKS cluster.
2. In the Settings section, select Cluster configuration.
3. Under Security updates, select the desired channel type from the Node security channel type dropdown.
![Select Security Patch Channel!](/blog/assets/images/enhance-security-with-os-security-patch/sec-patch-existing.jpg).
4. For Security channel scheduler, select Add schedule.
5. On the Add maintenance schedule page, configure the following maintenance window settings using the Planned Maintenance feature:
   - Repeats: Select the desired frequency for the maintenance window. We recommend selecting Weekly.
   - Frequency: Select the desired day of the week for the maintenance window. We recommend selecting Sunday.
   - Maintenance start date: Select the desired start date for the maintenance window.
   - Maintenance start time: Select the desired start time for the maintenance window.
   - UTC offset: Select the desired UTC offset for the maintenance window. If not set, the default is +00:00.
   
To learn more on configuration options via CLI visit this [page](https://learn.microsoft.com/azure/aks/auto-upgrade-node-os-image?tabs=azure-cli#set-the-node-os-autoupgrade-channel-on-a-new-cluster).

## Best Practices when using OS Security Patch Channel
   
 Here are some tips to go about doing this. 

- **Configure Maintenance Windows**: Configure [Planned Maintenance window](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli) to apply security patches during periods of low activity. This minimizes the impact on workloads and ensures that updates are applied seamlessly. 
- **Configure Cluster Auto-Upgrade Channel**: To maximize the benefits of OS security patches, it is recommended to enable the SecurityPatch channel alongside the [Kubernetes cluster auto upgrade channel](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster?tabs=azure-cli). This dual-channel approach ensures that both the control plane and node pools are kept up-to-date with the latest security patches.
- **Configure Upgrade Monitoring**: Regularly monitor the status of ongoing upgrades to ensure that patches are applied successfully. Utilize tools such as the [AKS Communication Manager](https://learn.microsoft.com/azure/aks/aks-communication-manager) to get periodic notifications on OS Patching updates. 
- **Use Release Tracker**: [AKS release tracker](https://releases.aks.azure.com/webpage/index.html) provides region by region updates on what security patch version runs in a particular region. These real-time updates are crucial for closely tracking CVEs. There is also a AKS CVE status tab.![Screenshot of the AKS release tracker showing region-specific security patch updates!](/blog/assets/images/enhance-security-with-os-security-patch/sec-patch-reltracker.jpg).


### What Is Coming Next for OS Security Patch?

The future of OS security patches promises several enhancements aimed at improving the patching process and ensuring even greater security:

- [Support for Network Isolated Cluster](https://github.com/Azure/AKS/issues/4962).
- [Snapshotting similar to Ubuntu in Azure Linux](https://github.com/Azure/AKS/issues/4963).
- [Kubelet and ContainerD patching via OS security patch](https://github.com/Azure/AKS/issues/4964).
- [Support for Airgapped cloud environments](https://github.com/Azure/AKS/issues/4965).
 
 To learn more OS Security patch intricacies as well as other interesting AKS topics refer to this Youtube [video](https://www.youtube.com/watch?v=Cw4pnfMVHxg).