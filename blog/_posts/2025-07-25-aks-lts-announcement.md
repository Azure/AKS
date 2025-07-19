---
title: "AKS Long Term Support: 24-Month Support Now Available for Every Kubernetes Version"
description: "Every supported AKS Kubernetes version is now eligible for 24-month LTS support when you enable the Premium tier"
date: 2025-07-25
author: Kaarthis
categories: general
---

In London at KubeCon EU 2025, AKS announced our expansion of what AKS Long Term Support (LTS) includes. Today, we're sharing more details about this offering that addresses one of the most critical challenges enterprises face when running Kubernetes at scale.
From our conversations with customers, we consistently hear the same concerns: *"How do I balance Kubernetes innovation with the stability my business-critical applications require?"* and *"Why do I need to upgrade my clusters so frequently when my applications are running perfectly?"*

On the flip side, customers also ask: *"If I don't upgrade frequently, how do I still ensure that I'm getting security fixes and ecosystem compatibility updates for my Kubernetes infrastructure?"* AKS LTS directly addresses these real-world challenges.

## Why AKS LTS Matters

Enterprise organizations running mission-critical workloads on Kubernetes have consistently told us they need more predictable, stable platform foundations. While the rapid innovation pace of Kubernetes is fantastic for driving new capabilities, it can create challenges for organizations that require:

- **Extended support lifecycles** that align with enterprise planning cycles
- **Predictable upgrade windows** that minimize operational disruption
- **Stability guarantees** for production workloads that can't tolerate frequent changes
- **Compliance requirements** that demand long-term support commitments

AKS LTS directly addresses these needs by providing a **support plan** specifically designed for enterprise stability requirements.

## What is AKS LTS?

**Understanding Kubernetes Community Support:** The upstream Kubernetes project follows a [regular release cadence](https://kubernetes.io/releases/release/) of approximately 4 months between versions, supporting the current version plus the two previous versions (n to n-2). 
AKS typically makes new Kubernetes versions available about a month after the upstream release, following our rigorous testing and validation process. This means each version receives roughly 12-14 months of community support.

While this rapid innovation cycle drives excellent new capabilities, we've heard from many enterprise customers that the standard 12-14 month support lifecycle can present challenges for production environments with stability requirements, compliance needs, or complex upgrade validation processes.

AKS Long Term Support is a **support plan** that provides **24 months** of support for Kubernetes versions from their GA date in AKS, compared to the standard 12-14 month support lifecycle. **Here's the key change: Every currently supported AKS Kubernetes version is now also available for long term support (LTS).**

This isn't just extended maintenance—it's a **support commitment for all managed components of AKS** designed for enterprises running mission-critical workloads.

**The Real Impact:** Instead of planning cluster upgrades every 12-14 months, you can now plan major Kubernetes upgrades every 24 months. This **reduces upgrade frequency by 50%** and **reduces operational overhead** while maintaining full security and support coverage.

AKS LTS provides all the same capabilities and features as community-supported AKS versions, with these key enhancements:

- **Extended Support Timeline:** 24 months of full support from GA date (compared to standard 12-14 months), including security patches and critical bug fixes
- **Premium Tier Requirement:** Available as part of the Premium tier, which includes additional enterprise features and comes with associated costs
- **Same Kubernetes Experience:** Identical functionality to standard AKS with proven, stable Kubernetes versions
- **Backwards Compatibility:** Strong commitment to API stability and workload compatibility within LTS versions
- **Integrated Azure Services:** Compatibility with most existing Azure services and AKS ecosystem features (see [LTS limitations](https://learn.microsoft.com/azure/aks/long-term-support#unsupported-add-ons-and-features) for current exceptions as we work towards 100% coverage)

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

**Universal LTS Coverage - A Major Expansion:** Previously, AKS LTS was available only for select Kubernetes versions, typically spaced several versions apart. **This announcement represents a fundamental shift: AKS LTS now extends to every currently supported Kubernetes version in AKS.** 
This means instead of waiting for specific "LTS-designated" versions, enterprises can choose long-term support for any supported Kubernetes version that meets their application requirements.

**Beyond Community Support:** When the Kubernetes community support ends (typically 12-14 months after a version's GA), AKS LTS continues providing comprehensive support for 24 months from the original GA date. **Crucially, once the community stops supplying patches after the official version support end-of-life, AKS continues to provide patches and CVE fixes** for all supported components.

This extended support is comprehensive and includes:

- **Core Kubernetes components:** API server, etcd, kubelet, kube-proxy, and all core Kubernetes functionality
- **AKS-managed add-ons, extensions, and AKS features:** (see [**AKS integrations**](https://learn.microsoft.com/azure/aks/integrations) for the complete list), **including networking, monitoring, and security components**, with the exception of Istio which is coming soon as mentioned in the Looking Ahead section.
For the current list of unsupported add-ons and features, please refer to our [**LTS unsupported add-ons documentation**](https://learn.microsoft.com/azure/aks/long-term-support#unsupported-add-ons-and-features)
- **Node and OS components:** Operating system patches, security updates, and node-level components for both Linux and Windows nodes

This holistic approach ensures that every layer of your full Kubernetes stack remains supported, secure, and stable throughout the entire LTS lifecycle.

**Support Timeline Example:**
- AKS LTS 1.28 (GA: Nov 2023): Supported until Feb 2026
- AKS LTS 1.29 (GA: Mar 2024): Supported until Apr 2026
- AKS LTS 1.30 (GA: Jul 2024): Supported until Jul 2026
- Future LTS versions will follow the same 24-month support commitment from their respective GA dates of the AKS community versions.

For the most up-to-date information on LTS version support timelines, please refer to the [AKS LTS calendar](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#lts-versions).

**Add-on Versioning Policy:** AKS add-ons, components and extensions are pinned to specific versions that align with each Kubernetes release. This versioning policy remains consistent between community-supported AKS and AKS LTS—add-ons receive the same version pinning approach to ensure stability and compatibility throughout the support lifecycle.

Throughout the support lifecycle, AKS LTS versions receive:
- Security patches and vulnerability fixes
- Fixes for critical bugs that impact stability or functionality
- Compatibility maintenance for Azure service integrations (not new feature additions)
- Ecosystem compatibility updates to maintain existing functionality (not new capabilities)

**Stay Informed:** You can track LTS patch rollouts and new LTS version availability in real-time using the [AKS Release Tracker](https://releases.aks.azure.com/webpage/index.html) under the Kubernetes version tab. Additionally, you can use the [`az aks get-upgrades`](https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-get-upgrades) CLI command or the [GET upgradeProfiles API](https://learn.microsoft.com/en-us/rest/api/aks/managed-clusters/get-upgrade-profile?view=rest-aks-2025-05-01&tabs=HTTP) (which maps to Microsoft.ContainerService/managedClusters/upgradeProfiles/read permission) to view available LTS versions for your clusters. 
These tools provide complete visibility into your LTS support lifecycle and upcoming releases.

## Creating AKS LTS Clusters

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

AKS clusters with LTS support maintain full compatibility with the existing AKS ecosystem, including [AKS Features, Add-ons and Extensions](https://learn.microsoft.com/azure/aks/integrations).

**Industry-Leading Ecosystem Support:** Unlike other cloud providers that typically limit LTS guarantees to the base Kubernetes API, AKS LTS provides comprehensive support for popular add-ons and components that enterprises depend on for production workloads. 
This includes [coordinated breaking change management](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-components-breaking-changes-by-version), timely CVE fixes (tracked via [AKS security bulletins](https://github.com/Azure/AKS/releases)), and compatibility assurance throughout the LTS lifecycle.

## Choosing Between Community and LTS Support

While AKS LTS provides extended stability, it's important to understand when each support option makes the most sense for your organization. Both community and LTS support have distinct advantages depending on your requirements.

**When to Choose Community Support:**
- **Cost optimization:** Community support comes at no additional cost beyond standard AKS pricing
- **Latest features:** Immediate access to the newest Kubernetes capabilities and AKS innovations
- **Development environments:** Non-critical workloads and test environments where ability to test newer functionality is a requirement
- **Frequent upgrade tolerance:** Teams comfortable with 12-14 month upgrade cycles and regular maintenance windows. Workloads that can handle seamless restarts.

**When to Choose LTS Support:**
- **Less maintenance to workloads and clusters:** Production systems where reducing upgrade frequency and operational overhead is prioritized
- **Compliance requirements:** Environments demanding extended support commitments for regulatory purposes
- **Complex upgrade validation:** Organizations requiring extensive testing cycles before adopting new versions
- **Resource-constrained teams:** Limited operational capacity for frequent cluster maintenance

**Decision Framework:**
Consider these factors when choosing your support model:

1. **Workload criticality:** How much downtime can your applications tolerate?
2. **Operational resources:** What's your team's capacity for regular maintenance?
3. **Innovation requirements:** How quickly do you need access to new Kubernetes features?
4. **Budget considerations:** Can you justify Premium tier costs for extended support?
5. **Compliance mandates:** Do regulations require specific support timelines?

## AKS LTS Version Compatibility

**Every currently supported AKS Kubernetes version is now also available for long term support (LTS).** This means you can immediately access long-term support for your existing clusters without requiring cluster upgrades or migrations.

Whether you're running the latest version or an older supported version, you can transition to LTS support coverage today by upgrading your cluster to the Premium tier.

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

For comprehensive guidance on all available upgrade strategies, see the [AKS cluster upgrade documentation](https://learn.microsoft.com/azure/aks/upgrade-cluster). These production-tested upgrade mechanisms ensure smooth transitions between LTS versions while maintaining workload availability.

## Transitioning Between Support Models

**Community to LTS Transition:**
Moving from community to LTS support is straightforward—simply upgrade your cluster to the Premium tier. Your current Kubernetes version immediately receives extended 24-month support coverage without requiring a cluster upgrade or migration.

**LTS to Community Transition:**
Transitioning from LTS to community support requires more planning, especially if you're near the end of your 24-month LTS window. Key considerations include:

- **Version gap assessment:** After 24 months on LTS, you may need to upgrade across multiple Kubernetes versions to reach a currently supported community version
- **Multi-hop upgrades:** While Kubernetes upstream focuses on n-1 to n upgrades, AKS provides support for multi-version upgrades with [upgrade path guidance](https://learn.microsoft.com/azure/aks/upgrade-cluster#upgrade-an-aks-cluster) and testing recommendations for larger version jumps
- **Shared responsibility:** You're responsible for workload compatibility testing across version gaps, while AKS ensures the upgrade path is technically viable and provides breaking change documentation
- **Planning window:** Begin transition planning 6-12 months before your LTS support expires to allow adequate time for testing and validation

**Best Practice:** Consider your long-term strategy when initially choosing LTS to avoid complex transitions later.

## Looking Ahead

AKS LTS represents our commitment to supporting enterprises at every stage of their Kubernetes journey. While LTS focuses on stability, we continue to innovate rapidly in standard AKS, ensuring you have access to the latest Kubernetes capabilities when you need them.

Over the coming months, we'll be expanding AKS LTS capabilities based on your feedback, including:

- **Istio support for LTS:** Unlike other add-ons whose minor versions are pinned to minor version of the AKS version, Istio add-on having its sidecar inside user's pod allows for minor version and upgrades to be explicitly controlled by the user today, thus complicating the permutations to be considered for LTS. LTS scope for Istio version(s) when deployed on top of AKS LTS versions is currently being finalized and will be announced in a future update
- **KMS V2 support for LTS:** Enhanced Key Management Service V2 support for AKS LTS tentatively CY2026H1, providing improved encryption key management capabilities for enterprise security requirements

**Enhanced AKS Upgrade Capabilities (coming soon for both standard AKS and LTS Support Plan):**
- **Agent pool Blue-Green upgrades:** Node pool-level blue-green upgrade strategy that enables workload validation batch by batch, with the ability to rollback newly created green nodes within a configurable soak period
- **Component Version API:** A dedicated API to surface breaking changes in AKS components, including AKS features, add-ons, extensions, and OS components, helping customers understand compatibility impacts before upgrading to the next AKS LTS version
- **Enhanced Pod Disruption Budget management:** Simplified Pod Disruption Budget(PDB) creation and management capabilities to streamline PDB setup and reduce upgrade complexity

## Real-World Customer Scenarios

**Financial Services:** A major bank running regulatory compliance workloads told us: *"We need Kubernetes for modern app development, but our compliance team requires extended stability guarantees. AKS LTS gives us both innovation and the predictability our auditors demand with 24 months of support."*

**Healthcare:** A healthcare provider managing patient data systems shared: *"Frequent cluster upgrades mean extensive testing and validation cycles. With AKS LTS, we can focus on improving patient outcomes instead of constant infrastructure maintenance."*

**Manufacturing:** An IoT platform managing factory operations explained: *"Our edge clusters run critical production line controls. Unexpected upgrades could halt manufacturing. AKS LTS gives us the stability to keep factories running while still benefiting from modern Kubernetes capabilities."*

## Azure Linux Support for AKS LTS

**Azure Linux Container Host for AKS now supports AKS Long Term Support**, starting with Kubernetes v1.29. This completes our OS support matrix for LTS—while Ubuntu and Windows Server node pools have been available with LTS since launch, Azure Linux Container Host is now the final piece, providing comprehensive OS choice for enterprise LTS deployments.

[Azure Linux Container Host for AKS](https://learn.microsoft.com/azure/azure-linux/intro-azure-linux) brings several key advantages for LTS deployments:
- **Secure supply chain:** Built and maintained by Microsoft with full supply chain security
- **Secure by default:** Streamlined attack surface with only essential components and security-hardened configuration
- **Optimized performance:** Purpose-built for Azure infrastructure with container workload optimizations
- **Consistent updates:** Aligned with AKS LTS lifecycle for predictable maintenance windows
- **Microsoft support:** Full integration with Azure support processes and enterprise SLAs

This combination of Azure Linux Container Host and AKS LTS provides enterprises with a fully Microsoft-supported stack from the operating system through the Kubernetes platform, completing our commitment to comprehensive OS support for long-term enterprise deployments.

For detailed information about Azure Linux Container Host support for AKS LTS, see our [Azure Linux LTS announcement](https://techcommunity.microsoft.com/blog/linuxandopensourceblog/azure-linux-now-supports-aks-long-term-support-lts-starting-with-kubernetes-v1-2/4424826).

## Getting Started with AKS LTS

To reduce operational overhead and gain enterprise-grade stability, **create your first AKS LTS cluster** using our [comprehensive quickstart guide](https://aka.ms/aks/lts-quickstart).

**Immediate Next Steps:**
1. **Quick assessment:** Identify 1-2 production clusters that would benefit from 24-month support
2. **Pilot deployment:** Create a test AKS LTS cluster to evaluate the experience
3. **Plan transition:** Review our [migration documentation](https://aka.ms/aks/lts-migration) for production workloads

**Questions?** Connect with the AKS team and community in our [GitHub discussions](https://github.com/Azure/AKS/discussions) or share your [feedback and suggestions](https://github.com/Azure/AKS/issues).

AKS LTS provides enterprise Kubernetes with stability, predictability, and comprehensive support. This offering makes that reality accessible for your organization while maintaining access to Kubernetes innovation.
