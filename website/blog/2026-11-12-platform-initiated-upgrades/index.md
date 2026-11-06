---
title: "Strengthening AKS security with platform-initiated upgrades"
date: 2026-11-12
description: "AKS platform-initiated upgrades begin June 1, 2027. Find unsupported clusters and pick an upgrade plan that fits your workloads with Fleet Manager and LTS."
authors: ["kaarthikeyan-subramanian"]
tags: ["security", "operations", "best-practices", "fleet-manager"]
draft: true
---

Azure Kubernetes Service (AKS) is introducing platform-initiated upgrades to help keep all your clusters running AKS-supported Kubernetes versions. Starting **June 1, 2027**, AKS upgrades clusters that remain on unsupported versions, rolling out across them in waves.

This isn't a change to what "unsupported" means. Today, a cluster that runs a Kubernetes version past its support window already stops receiving upstream patches, bug fixes, and security fixes. Platform-initiated upgrades close that gap by bringing those clusters back to a safe and supported baseline, in line with the [Microsoft Secure Future Initiative](https://www.microsoft.com/trust-center/security/secure-future-initiative) and its secure-by-default principle.

The goal is to keep clusters supported, not necessarily on the newest minor version. Upgrades you plan yourself are still the best way to fit testing and timing around your workloads. This post helps you choose the approach that fits.

<!-- truncate -->

## Know your support deadline

Upstream Kubernetes supports each minor version for about one year. AKS community support covers three generally available minor versions (N, N-1, and N-2) on the dates published in the [AKS Kubernetes release calendar](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions#aks-kubernetes-release-calendar-and-upcoming-versions). Use the AKS dates rather than assuming they match upstream.

Platform-initiated upgrades begin June 1, 2027. AKS rate-limits them by region, subscription, and version, so a cluster upgrades during or after its planned month, not on a specific day. Until then, upgrade at your own pace.

On June 1, 2027, compare your clusters against these minimum versions:

| Support plan | Minimum version | If your cluster is below it |
| --- | --- | --- |
| Community | Kubernetes 1.36 | Upgrade, or enable LTS on an eligible version |
| Long-term support (LTS) | Kubernetes 1.33 LTS | Upgrade to a supported LTS version |

These minimums move as versions reach end of life. After the initial rollout, each version gets a 60-day grace period after its end-of-life date before its clusters become eligible. For example, Kubernetes 1.36 reaches end of life in June 2027, so clusters still on it are planned for September 2027. The initial rollout doesn't add another 60 days after June 1.

The grace period gives you time to act. It doesn't extend Kubernetes version support, including security fixes. Check the **Platform-initiated upgrade** column in the release calendar for each version's planned month.

### What happens if you don't act

A platform-initiated upgrade exists to return an unsupported cluster to support. To make sure it finishes, it doesn't follow the controls that your own upgrades respect:

- It ignores your maintenance window, auto-upgrade channel, and Fleet Manager update runs.
- It skips the deprecated API check, so workloads that depend on removed APIs can break.
- It tries a normal node drain first, but can override a Pod Disruption Budget (PDB) if the drain fails or times out.
- It moves one minor version at a time to the lowest supported version in your current support plan. It never enrolls a cluster in LTS or changes your billing tier.
- It can't be rolled back.

Workload availability isn't guaranteed on this path. Everything else in this post is about upgrading on your terms first. For eligibility, target-version selection, and execution details, see [Platform-initiated upgrades in AKS](https://learn.microsoft.com/azure/aks/platform-initiated-upgrades).

## Start with your cluster inventory

In the Azure portal, search for **Kubernetes center**. Kubernetes Center (preview) gives you an overview of the AKS clusters you're authorized to view, including cluster health and upgrade recommendations.

For a precise list, run this Azure Resource Graph query. It returns each cluster's Kubernetes version, support plan (`KubernetesOfficial` for community or `AKSLongTermSupport` for LTS), and upgrade channel:

```bash
# Requires the Azure CLI resource-graph extension: az extension add --name resource-graph
az graph query -q "resources
| where type =~ 'microsoft.containerservice/managedclusters'
| project name, resourceGroup, subscriptionId,
    kubernetesVersion = tostring(properties.kubernetesVersion),
    supportPlan = tostring(properties.supportPlan),
    upgradeChannel = tostring(properties.autoUpgradeProfile.upgradeChannel)
| order by kubernetesVersion asc" --output table
```

Compare the results with the release calendar, flag every cluster below the minimums, and assign an owner to each one.

## Choose the upgrade plan that fits your workloads

Your approach depends on your operational needs. Most teams fit more than one of these scenarios and combine several options:

- [I manage multiple clusters. How do I test changes before production?](#i-manage-multiple-clusters-how-do-i-test-changes-before-production)
- [I need more time on my Kubernetes version. What are my options?](#i-need-more-time-on-my-kubernetes-version-what-are-my-options)
- [Capacity is my constraint. How do I prepare?](#capacity-is-my-constraint-how-do-i-prepare)
- [Whatever my situation, how do I reduce workload disruption?](#whatever-my-situation-how-do-i-reduce-workload-disruption)

### I manage multiple clusters. How do I test changes before production?

Treat upgrades like a release: development, then test, staging, and production.

[Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/overview) is built for this. Organize your clusters into ordered stages with reusable [update strategies](https://learn.microsoft.com/azure/kubernetes-fleet/update-create-update-strategy). Stages run in order, and the groups inside a stage update in parallel. Pair a strategy with a Fleet [auto-upgrade profile](https://learn.microsoft.com/azure/kubernetes-fleet/update-automation) on the **Stable** channel, and Fleet rolls new Kubernetes versions through your environments as AKS releases them, keeping member clusters in support.

Build your update strategy around a few habits:

- Assign an owner for application validation at each stage.
- Review breaking changes for every minor version between your current and target versions. Each Kubernetes release can remove APIs. Check the [Kubernetes deprecated API migration guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/) and [AKS release notes](https://github.com/Azure/AKS/releases), and use **Diagnose and solve problems** > **Kubernetes API deprecations** in the portal.
- Test critical dependencies, APIs, and representative user journeys.
- Add soak periods between stages before you move on.
- Use [approval gates](https://learn.microsoft.com/azure/kubernetes-fleet/update-strategies-gates-approvals) to pause between stages until your team or automation signs off.

Keep two settings in mind:

- **Maintenance windows live on each cluster, not in Fleet.** Configure [planned maintenance](https://learn.microsoft.com/azure/aks/planned-maintenance) per cluster to fit each environment. Fleet update runs honor those windows.
- **Pick one driver for Kubernetes upgrades.** Decide whether Fleet or the cluster's own auto-upgrade channel upgrades each member cluster. If both are on, a cluster can upgrade out of sequence with your Fleet strategy.

Fleet coordinates the rollout. Your team or automation validates the applications. A finished wait period alone isn't proof that a workload is healthy.

### I need more time on my Kubernetes version. What are my options?

If your validation or dependency cycle needs a longer horizon, consider [AKS long-term support (LTS)](https://learn.microsoft.com/azure/aks/long-term-support).

Before choosing LTS, review the version's support dates in the release calendar and current [AKS Premium tier pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).

LTS requires the AKS Premium tier and explicit enrollment in the LTS support plan. It offers up to 12 additional months of support after community support ends for that version. That's not 12 months from the day you enable LTS on a cluster.

Platform-initiated upgrades never enroll clusters in LTS or change billing or support tiers. Clusters already enrolled follow the LTS path: when their LTS window ends, AKS upgrades them to the next supported LTS version.

LTS buys planning time, not indefinite support. Keep taking patches, testing changes, and checking add-on lifecycles. Regular, tested upgrades within community support remain a solid path.

### Capacity is my constraint. How do I prepare?

Start by separating the capacity you need from resources you can retire. Inventory unused clusters, and confirm that dependent workloads and data are accounted for before you delete anything.

For clusters on unsupported Kubernetes versions that you still need, compare an in-place upgrade with migrating to a new, supported cluster:

- **In-place upgrade.** The cluster moves one minor version at a time, so a cluster that's far behind needs several upgrades.
- **Blue-green cluster migration.** You need capacity for both clusters during the transition, so it isn't a capacity-free workaround. Fleet [resource placement](https://learn.microsoft.com/azure/kubernetes-fleet/concepts-resource-propagation) makes this easier by pushing the same workloads to multiple clusters based on labels or properties. Remove the old cluster only after a validated cutover, data handling, and recoverability checks, not first to make room for its replacement.

For clusters you'll upgrade, check each of these [quotas and limits](https://learn.microsoft.com/azure/aks/quotas-skus-regions) separately:

- Subscription quota
- Regional and VM SKU availability
- Subnet IP space
- Temporary surge capacity during the upgrade

Engage your capacity teams early rather than discovering an allocation constraint mid-upgrade.

Choose [node pool upgrade settings](https://learn.microsoft.com/azure/aks/upgrade-aks-node-pools-rolling) based on tested headroom and workload availability needs. `maxSurge` adds temporary nodes during the upgrade. `maxUnavailable` upgrades user node pools in place without surge nodes, but reduces workload capacity while it runs, and isn't supported on system node pools.

Where it fits, evaluate [capacity reservation groups](https://learn.microsoft.com/azure/aks/use-capacity-reservation-groups) for eligible node pools. Reservations cover specific VM sizes, locations, and quantities, not unlimited capacity. Creating one can fail, and unused reservations incur charges. Associating a reservation with an existing node pool is in preview, so review prerequisites before you adopt it.

### Whatever my situation, how do I reduce workload disruption?

Workload readiness belongs in every upgrade plan.

[Pod Disruption Budgets](https://learn.microsoft.com/azure/aks/best-practices-app-cluster-reliability#pod-disruption-budgets-pdbs) limit voluntary disruption. They don't guarantee zero downtime or that an upgrade finishes. A restrictive PDB can also block a node drain when too few healthy replicas are available.

Before production upgrades:

- Verify that workloads have enough healthy replicas.
- Test PDBs and node drain behavior in a representative non-production environment.
- Validate dependencies, Kubernetes APIs, and add-ons, including self-managed add-ons and their custom resource definitions.
- Rehearse monitoring, recovery, and post-upgrade checks.

If nodes won't drain, review the [AKS upgrade options](https://learn.microsoft.com/azure/aks/upgrade-options#common-upgrade-scenarios-and-recommendations) for undrainable nodes, such as the `Cordon` behavior and the `maxBlockedNodes` limit. Quarantined nodes need an owner and a fix, because these controls don't repair a problematic PDB.

For optional non-production evaluation, [automatic PDB management (preview)](https://learn.microsoft.com/azure/aks/automatic-pod-disruption-budget-management) creates missing PDBs for Deployments, keeps the PDBs you created yourself, and needs capacity for temporary replicas. It isn't intended for production, and it isn't a prerequisite for this policy.

## Stay informed throughout the lifecycle

Set up [AKS Communication Manager](https://learn.microsoft.com/azure/aks/aks-communication-manager) to track maintenance events and outcomes, including platform-initiated upgrades. AKS generates these events automatically, but you need alert rules and Azure Monitor action groups to receive them. Route them to the platform and application owners who act on them.

When a cluster enters platform support, AKS also flags it through Azure Resource Health, Azure Advisor, and a banner on the cluster in the Azure portal. Don't wait for those warnings to start planning, and don't treat them as an extension of Kubernetes version support, including security fixes.

## Make supported versions part of your operating rhythm

Start with your inventory. Choose the approaches that fit, assign owners, validate capacity, and rehearse upgrades while you still have runway. Keep reviewing patches and support dates as routine operational work.

A supported Kubernetes version is an important security baseline, not a complete security solution. Node OS images, workload dependencies, identities, and configuration still need attention.

**Running more than one cluster? Use Fleet Manager.** Most teams do. [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/overview) gives you staged, safe multi-cluster upgrades that apply automatically as AKS releases new Kubernetes versions. Staying supported becomes the default rather than a project. To get started, see [Create a Fleet Manager resource and join member clusters](https://learn.microsoft.com/azure/kubernetes-fleet/quickstart-create-fleet-and-members).

Platform-initiated upgrades are a safety net. A tested upgrade you plan yourself is still the best way to make the change on terms your workloads are ready for.

## Learn more

- [Platform-initiated upgrades in AKS](https://learn.microsoft.com/azure/aks/platform-initiated-upgrades)
- [AKS Kubernetes release calendar](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions#aks-kubernetes-release-calendar-and-upcoming-versions)
- [Fleet Manager update orchestration](https://learn.microsoft.com/azure/kubernetes-fleet/concepts-update-orchestration)
- [AKS long-term support](https://learn.microsoft.com/azure/aks/long-term-support)
- [AKS Long Term Support: 24-month support for every Kubernetes version](../2025-07-25-aks-lts-announcement/index.md)
