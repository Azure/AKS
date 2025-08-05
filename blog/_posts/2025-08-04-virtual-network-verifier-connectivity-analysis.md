---
title: "Simplifying Outbound Connectivity Troubleshooting in AKS with Connectivity Analysis (Preview) tool"
description: "Learn how to use the new Connectivity Analysis feature to troubleshoot outbound connectivity issues in AKS clusters"
date: 2025-08-04 # date is important. future dates will not be published
author: Julia Yin # must match the authors.yml in the _data folder
categories: 
- general
- networking
---

<!-- markdownlint-disable MD043 -->

## Background

Troubleshooting outbound connectivity issues in Azure Kubernetes Service (AKS) can be daunting. The complexity arises from the layered nature of Azure networking, which can span NSGs, UDRs, route tables, firewalls, and private endpoints. When a pod fails to reach an external service, pinpointing the root cause often requires deep familiarity with Azure networking and manual inspection of multiple network resources. This complex process slows down resolution and increases operational overhead for cluster operations and platform teams.

## Announcing the Connectivity Analysis feature for AKS

To simplify the network troubleshooting process, we're excited to announce the **Connectivity Analysis** feature, now available in **Public Preview**. This feature leverages the same underlying engine as the [Azure Virtual Network Verifier (VNV)](https://learn.microsoft.com/azure/virtual-network-manager/concept-virtual-network-verifier) tool, and is now purpose-built for AKS scenarios and fully integrated into the AKS Portal experience. You can use the Connectivity Analysis (Preview) feature to quickly verify whether outbound traffic from your AKS nodes is being blocked by Azure network resources such as:

- Azure Load Balancer
- Azure Firewall
- A network address translation (NAT) gateway
- Network security group (NSG)
- Network policies
- User defined routes (route tables)
- Virtual network peering

## How to use the Connectivity Analysis (Preview) feature

1. Navigate to your AKS cluster in the **Azure Portal**.
2. Go to the **Node pools** tab under the **Settings** section.
3. Select a nodepool and click on **Connectivity Analysis (Preview)** in the toolbar. If you don't see the tool, click the three dots "..." to expand the toolbar menu.
4. Select a Virtual Machine Scale Set (VMSS) instance as the source. The source IP addresses are populated automatically.
5. Select a public domain name/endpoint as the destination for the analysis, one example is `mcr.microsoft.com`. The destination IP addresses are also populated automatically.
6. Run the analysis and wait up to 2 minutes for the results. The analysis result will appear at the top along with a network flow diagram. To view the detailed analysis output, click on the "More details" to open up the JSON output tab.

[insert GIF / demo video here]

## Current Limitations

We are currently rolling out support for CNI Overlay clusters, please see the list below for regions which are currently unsupported. We expect to fully roll out support within the next few weeks (by early September).

- West US
- West US 2
- South Central US

For unsupported regions, you will see an error message when you try to run a connectivity analysis from a CNI Overlay cluster.

We are also making improvements to the user interface to intuitively display the full analysis results and next steps. Please keep an eye out for UI improvements coming out in the next few weeks!

## Example Scenarios

Here are a few situations where the Connectivity Analysis (Preview) feature can help:

- **Troubleshoot EgressBlocked condition or node provisioning failures**: AKS requires access to a [few ports and addresses](https://learn.microsoft.com/azure/aks/outbound-rules-control-egress#required-outbound-network-rules-and-fqdns-for-aks-clusters) to maintain healthy cluster maintenance tasks such as scaling and upgrade operations. When AKS detects that traffic to essential endpoints is blocked, the EgressBlocked node condition will be reported and your cluster operations will fail. Use Connectivity Analysis (Preview) to verify that your node pools can reach all essential egress endpoints.
- **Pods failing to pull images from container registries**: When pods cannot pull container images, deployments fail and applications remain in a pending state. This commonly occurs when network security groups (NSGs) or Azure Firewall rules block outbound HTTPS traffic to container registries like Azure Container Registry (ACR), Docker Hub, or Microsoft Container Registry (MCR). Use Connectivity Analysis (Preview) to test connectivity from your node subnet to your container registry endpoints (e.g. `mcr.microsoft.com`) and identify which network component is blocking the traffic.
- **Webhooks or external APIs unreachable**: Kubernetes admission controllers, monitoring solutions, and custom applications often need to reach external webhooks or APIs. When these connections fail, you might see webhook timeouts, failed certificate validations, or application errors. Common destinations include GitHub webhooks or third-party monitoring services. Use Connectivity Analysis (Preview) to verify connectivity to specific FQDNs or IP addresses and determine if firewall rules, NSGs, or route tables are preventing access from your node subnet.
