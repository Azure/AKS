---
title: "AKS Long Term Support: 24-Month Support Now Available for Every Kubernetes Version"
description: "Every supported AKS Kubernetes version is now eligible for 24-month LTS support when you enable the Premium tier"
date: 2025-07-20
author: Kaarthis
categories: general
---

In London at KubeCon EU 2025, AKS shared our exciting announcement regarding our expansion of what AKS Long Term Support (LTS) includes. Today, we're thrilled to share more details about this game-changing offering that addresses one of the most critical challenges enterprises face when running Kubernetes at scale.

From our conversations with customers, we consistently hear the same concerns: *"How do I balance Kubernetes innovation with the stability my business-critical applications require?"* and *"Why do I need to upgrade my clusters so frequently when my applications are running perfectly?"* AKS LTS directly solves these real-world challenges.

## Why AKS LTS Matters

Enterprise organizations running mission-critical workloads on Kubernetes have consistently told us they need more predictable, stable platform foundations. While the rapid innovation pace of Kubernetes is fantastic for driving new capabilities, it can create challenges for organizations that require:

- **Extended support lifecycles** that align with enterprise planning cycles
- **Predictable upgrade windows** that minimize operational disruption
- **Stability guarantees** for production workloads that can't tolerate frequent changes
- **Compliance requirements** that demand long-term support commitments

AKS LTS directly addresses these needs by providing a **support plan** specifically designed for enterprise stability requirements.

## What is AKS LTS?

AKS Long Term Support is a **support plan** that provides **24 months** of support for Kubernetes versions from their GA date in AKS, compared to the standard 12-15 month support lifecycle. **Here's the game-changer: Every currently supported AKS Kubernetes version is now also available for long term support (LTS).** This isn't just extended maintenance—it's a comprehensive support commitment designed for enterprises running mission-critical workloads.

**The Real Impact:** Instead of planning cluster upgrades every 12-15 months, you can now plan major Kubernetes upgrades every 24 months. This **reduces upgrade frequency by 50%** and can **save enterprises 40+ hours of operational overhead annually** per cluster while maintaining full security and support coverage.

Key characteristics of AKS LTS include:

- **Extended Support Timeline:** 24 months of full support from GA date, including security patches and critical bug fixes
- **Predictable Release Cadence:** New LTS versions released annually, allowing for planned upgrade cycles
- **Enterprise-Grade Stability:** Focus on proven, stable features rather than frequent changes
- **Backwards Compatibility:** Strong commitment to API stability and workload compatibility within LTS versions
- **Integrated Azure Services:** Full compatibility with existing Azure services and AKS ecosystem features

## Enterprise Benefits at a Glance

**Reduced Operational Overhead**
- Fewer required upgrades mean less time spent on cluster maintenance
- Predictable planning cycles aligned with enterprise budgeting and resource allocation
- Reduced testing and validation overhead for workload compatibility

**Enhanced Stability**
- Production-tested Kubernetes versions with proven track record
- Minimized risk of introducing breaking changes or regressions
- Focus on reliability over cutting-edge features

**Compliance and Governance**
- Extended support timelines that meet enterprise compliance requirements
- Clear end-of-life planning with advance notice for migration planning
- Integration with Azure Policy and governance frameworks

## Technical Implementation

**Universal LTS Coverage:** AKS LTS extends to every currently supported Kubernetes version in AKS. Each version undergoes extensive testing across diverse workload patterns and enterprise scenarios to ensure LTS-grade stability and compatibility.

**Beyond Community Support:** When the Kubernetes community support ends (typically 12-14 months after a version's GA), AKS LTS continues providing comprehensive support for 24 months from the original GA date. **Crucially, once the community stops supplying patches after the official version support end-of-life, AKS continues to provide patches and CVE fixes** for all supported components. This extended support is comprehensive and includes:

- **Core Kubernetes components:** API server, etcd, kubelet, kube-proxy, and all core Kubernetes functionality
- **AKS-managed add-ons:** (see [**AKS integrations**](https://learn.microsoft.com/en-us/azure/aks/integrations) for the complete list), **including networking, monitoring, and security components**, with the exception of Istio which is coming soon as mentioned in the Looking Ahead section. For the current list of unsupported add-ons and features, please refer to our [**LTS unsupported add-ons documentation**](https://learn.microsoft.com/en-us/azure/aks/long-term-support#unsupported-add-ons-and-features)
- **Node and OS components:** Operating system patches, security updates, and node-level components for both Linux and Windows nodes

This holistic approach ensures that every layer of your full Kubernetes stack remains supported, secure, and stable throughout the entire LTS lifecycle.

**Support Timeline Example:**
- AKS LTS 1.28 (GA: August 2024): Supported until August 2026
- AKS LTS 1.29 (GA: December 2024): Supported until December 2026
- AKS LTS 1.30 (GA: May 2025): Supported until May 2027
- Future LTS versions will follow the same 24-month support commitment from their respective GA dates

For the most up-to-date information on LTS version support timelines, please refer to the [AKS LTS calendar](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#lts-versions).


Throughout the support lifecycle, AKS LTS versions receive:
- Security patches and vulnerability fixes
- Fixes for critical bugs that impact stability or functionality
- Azure service integration updates
- Compatibility updates for ecosystem tools and applications

**Stay Informed:** You can track LTS patch rollouts and new LTS version availability in real-time using the [AKS Release Tracker](https://releases.aks.azure.com/webpage/index.html) under the Kubernetes version tab. This provides complete visibility into your LTS support lifecycle and upcoming releases.

## Getting Started with AKS LTS

Creating an AKS cluster with LTS support is straightforward and uses the same familiar tools and processes you already know. Here's a simple example using Azure CLI:

```bash
# Create an AKS cluster with LTS support
az aks create \
    --resource-group myResourceGroup \
    --name myAKSLTSCluster \
    --tier LTS \
    --kubernetes-version 1.29 \
    --node-count 3
```

You can also deploy AKS clusters with LTS support using:
- **Azure Portal:** Select "Long Term Support" option during cluster creation
- **ARM Templates/Bicep:** Specify the LTS tier in your infrastructure-as-code deployments
- **Terraform:** Updated AKS provider supports LTS cluster configuration

**Important:** AKS LTS is available as part of the **Premium tier**. For detailed pricing information, please refer to the [AKS Premium tier pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).

AKS clusters with LTS support maintain full compatibility with the existing AKS ecosystem, including Azure Monitor, Azure Policy, and all AKS-managed add-ons.

**Industry-Leading Ecosystem Support:** Unlike other cloud providers that typically limit LTS guarantees to the base Kubernetes API, AKS LTS provides comprehensive support for popular add-ons and components that enterprises depend on for production workloads. This includes coordinated breaking change management, timely CVE fixes, and compatibility assurance throughout the LTS lifecycle.

## AKS LTS Version Compatibility

**Every currently supported AKS Kubernetes version is now also available for long term support (LTS).** This means you can immediately access long-term support for your existing clusters without requiring cluster upgrades or migrations. Whether you're running the latest version or an older supported version, you can transition to LTS support coverage today.

**Immediate Benefits:**
- **No forced migrations:** Your existing clusters can adopt LTS support in-place
- **Complete coverage:** Every supported version gets the same comprehensive LTS treatment
- **Instant value:** Start benefiting from extended support timelines immediately

When planning your LTS adoption, consider:
- **Current cluster assessment:** Evaluate which of your existing clusters would benefit most from extended support
- **Workload criticality:** Prioritize mission-critical production workloads for LTS coverage
- **Compliance requirements:** Align LTS adoption with your organization's governance and compliance needs

For detailed migration guidance and best practices, refer to our [AKS LTS migration documentation](https://aka.ms/aks/lts-migration) on Microsoft Learn.

## Upgrading Between LTS Versions

When it's time to upgrade from one AKS LTS version to another, you can take advantage of all the robust upgrade functionality already available in AKS. Popular upgrade options include:

- **MaxUnavailable configuration:** Control cluster capacity during upgrades by specifying the maximum number of nodes that can be unavailable simultaneously
- **Undrainable node behavior:** Configure how AKS handles nodes that cannot be drained, ensuring predictable upgrade outcomes
- **OS Security Patch channel:** Automate operating system security updates through configurable patch channels
- **Node Image channel:** Keep node images updated with the latest security patches and OS improvements
- **Planned maintenance windows:** Schedule upgrades during off-peak hours to minimize business impact

For comprehensive guidance on all available upgrade strategies, see the [AKS cluster upgrade documentation](https://learn.microsoft.com/en-us/azure/aks/upgrade-cluster). These production-tested upgrade mechanisms ensure smooth transitions between LTS versions while maintaining workload availability.

## Looking Ahead

AKS LTS represents our commitment to supporting enterprises at every stage of their Kubernetes journey. While LTS focuses on stability, we continue to innovate rapidly in standard AKS, ensuring you have access to the latest Kubernetes capabilities when you need them.

Over the coming months, we'll be expanding AKS LTS capabilities based on your feedback, including:

- **Istio support for LTS:** Bringing comprehensive LTS support for Istio service mesh to provide enterprise-grade stability for your microservices architecture

**Enhanced AKS Upgrade Capabilities (coming soon for both standard AKS and LTS Support Plan):**
- **Agent pool Blue-Green upgrades:** Node pool-level blue-green upgrade strategy that enables workload validation batch by batch, with the ability to rollback newly created green nodes within a configurable soak period
- **Component Version API:** A dedicated API to surface breaking changes in AKS components, including AKS-managed add-ons and OS components, helping customers understand compatibility impacts before upgrading to the next AKS LTS version
- **Enhanced PDB management:** Simplified Pod Disruption Budget creation and management capabilities to streamline PDB setup and reduce upgrade complexity

## Real-World Customer Scenarios

**Financial Services:** A major bank running regulatory compliance workloads told us: *"We need Kubernetes for modern app development, but our compliance team requires extended stability guarantees. AKS LTS gives us both innovation and the predictability our auditors demand with 24 months of support."*

**Healthcare:** A healthcare provider managing patient data systems shared: *"Frequent cluster upgrades mean extensive testing and validation cycles. With AKS LTS, we can focus on improving patient outcomes instead of constant infrastructure maintenance."*

**Manufacturing:** An IoT platform managing factory operations explained: *"Our edge clusters run critical production line controls. Unexpected upgrades could halt manufacturing. AKS LTS gives us the stability to keep factories running while still benefiting from modern Kubernetes capabilities."*

## Azure Linux Support for AKS LTS

We're excited to announce that **Azure Linux now supports AKS Long Term Support**, starting with Kubernetes v1.29. This expands your options for building stable, enterprise-grade Kubernetes infrastructure on Microsoft's own Linux distribution.

Azure Linux brings several advantages for LTS deployments:
- **Optimized performance:** Purpose-built for Azure infrastructure
- **Enhanced security:** Streamlined attack surface with only essential components
- **Consistent updates:** Aligned with AKS LTS lifecycle for predictable maintenance
- **Microsoft support:** Full integration with Azure support processes

This combination of Azure Linux and AKS LTS provides enterprises with a fully Microsoft-supported stack from the operating system through the Kubernetes platform. For detailed information about Azure Linux support for AKS LTS, see our [Azure Linux LTS announcement](https://techcommunity.microsoft.com/blog/linuxandopensourceblog/azure-linux-now-supports-aks-long-term-support-lts-starting-with-kubernetes-v1-2/4424826).

## Start Your AKS LTS Journey Today

Ready to reduce operational overhead and gain enterprise-grade stability? **Create your first AKS LTS cluster in under 5 minutes** using our [comprehensive quickstart guide](https://aka.ms/aks/lts-quickstart).

**Immediate Next Steps:**
1. **Quick assessment:** Identify 1-2 production clusters that would benefit from 24-month support
2. **Pilot deployment:** Create a test AKS LTS cluster to evaluate the experience  
3. **Plan transition:** Review our [migration documentation](https://aka.ms/aks/lts-migration) for production workloads

**Questions?** Connect with the AKS team and community in our [GitHub discussions](https://github.com/Azure/AKS/discussions) or share your [feedback and suggestions](https://github.com/Azure/AKS/issues).

**The future of enterprise Kubernetes is stable, predictable, and powerful. AKS LTS is here to make that future a reality for your organization—without sacrificing the innovation that makes Kubernetes so compelling.**
