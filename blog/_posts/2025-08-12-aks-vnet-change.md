---
title: "AKS-managed VNets default to Private Subnets Starting September 2025"
description: "AKS-managed VNets default to Private Subnets Starting September 2025"
date: 2025-08-12 # date is important. future dates will not be published
author: Dan Bosscher # must match the authors.yml in the _data folder
categories: networking
---

Beginning **September 2025**, new AKS clusters that use the **AKS-managed virtual network** option will create their **cluster subnets as private by default** (`defaultOutboundAccess = false`).

This setting does not impact AKS-managed cluster traffic, which already uses **explicitly configured outbound paths** based on your [`outboundType`](https://learn.microsoft.com/azure/aks/egress-outboundtype).
**Existing deployments as well as BYO-VNet deployments are unaffected.**

This change may affect unsupported scenarios, such as deploying other resources (e.g., VMs) into AKS-managed subnets. This blog offers recommendations for customers in that situation.

---
## Why we’re making this change
This change aligns with the Azure-wide transition to [secure-by-default networking](https://azure.microsoft.com/updates/default-outbound-access-for-vms-in-azure-will-be-retired-updates-and-more-information/), where explicit outbound connectivity is required for all new virtual networks. Using explicit outbound provides:

- **Greater control** over how and when resources connect to the internet.
- **Predictable public IP addresses** that you own and manage, preventing unexpected changes.
- **Traceable and auditable** egress traffic through a single, measurable point.
---

## Guidance for customers in unsupported patterns
If you have placed **non-AKS resources** (e.g., jump boxes) in **AKS-managed subnets**, follow these steps:

1. **Move those resources** to a **separate, customer-owned subnet** that you manage.
2. Attach an **explicit outbound connectivity method** to that subnet. For most scenarios, **Azure NAT Gateway** is the recommended default due to its high SNAT port scale and stable egress IPs. Alternatives include **Standard Load Balancer outbound rules** or **routing via a firewall** using a **User-Defined Route (UDR)**.
3. Use **VNet peering**, **Private Link**, or **Azure Bastion** for secure access to your AKS cluster and other resources.

> **Reminder**: Do not modify or attach extra resources to the **AKS node resource group** or **AKS-managed subnets**. These are managed by AKS, and customizations can be overwritten during cluster operations. Keep non-AKS infrastructure in your own resource groups and subnets.

---

## Frequently Asked Questions

**Does this break AKS egress?**
No. AKS already uses explicit outbound paths according to your `outboundType`. Supported configurations will continue to work as-is.

**Do I need to change anything if I use a Bring-Your-Own (BYO) VNet?**
No change is required. However, we recommend ensuring your explicit egress design (NAT Gateway, firewall, etc.) aligns with your security and operational policies.

**What explicit egress method do you recommend?**
For most clusters, **Azure NAT Gateway** provides the best combination of scale and stable public IPs. If you require traffic inspection or specialized routing, use a **UDR** to steer traffic through a network virtual appliance (NVA) or firewall. **Standard Load Balancer outbound rules** are suitable for smaller or less complex scenarios.

**Can I attach a VM to the AKS-managed subnet and add a public IP?**
This is unsupported. Keep non-AKS resources in your own subnets and VNets to avoid configuration drift and ensure reliability.

---

## What’s next
- **Audit** your AKS-managed subnets to confirm no non-AKS resources are deployed there.
- **Segment** your infrastructure: keep VMs and other resources in a **separate subnet/VNet** that you own.
- **Adopt explicit egress** (NAT Gateway is recommended) for any resource that needs internet access.
- **Review** your cluster’s `outboundType` and confirm it aligns with your egress and security policies.

---

### Summary
- **Starting September 2025**: New AKS-managed VNet subnets will default to **private**.
- **Supported AKS scenarios**: **No action is required**.
- **Unsupported scenarios** (e.g., jump boxes in AKS subnets): **Move** resources to your own subnet/VNet and **enable explicit egress**.
- **Best practice**: Use **explicit outbound** methods like NAT Gateway, a Standard Load Balancer, or a firewall with UDR for predictability, scale, and governance.