---
title: "Build the platform, not the plumbing, on AKS"
date: 2026-11-09
description: "Why platform engineers should build internal developer platforms on AKS: let Azure run the undifferentiated work so your team can own the developer contract."
authors: [paul-yu]
tags:
  [
    platform-engineering,
    aks-automatic,
    best-practices,
    developer,
    workload-identity,
    argo-cd,
    open-source,
    kro,
    fleet-manager,
    security,
  ]
draft: false
---

Getting one app running on AKS isn't the hard part. Running a platform that works for every app is. Without one, you aren't really scaling. You're asking every team to wire up the same plumbing over and over again. A landing zone sets up Azure. A platform sets up your developers to be productive with Kubernetes supported by AKS.

Most platform conversations start with a tool list: Backstage? Argo CD? Flux? But tools shouldn't dictate your developer contract; they should fulfill it. In this post, I'll walk through how I'd build one, why I'd build it on AKS, and the trade-offs along the way.

<!-- truncate -->

## Start with the contract

Start with where app teams get stuck: repeated deployment setup, access requests, or unclear ownership. Microsoft's [platform engineering guidance](https://learn.microsoft.com/platform-engineering/what-is-platform-engineering) treats developers as customers and the platform as a product. Use their feedback to choose which problems to solve first, then capture what teams should be able to do in your developer contract.

No matter which team owns it, every app needs the same things before it can ship:

1. **A place to run** with clear boundaries
2. **An identity** to reach other services without copying keys around
3. **A way to see what it's doing**, not just whether it's running
4. **A safe way to ship**: review first, then reconcile

Kubernetes gives you building blocks for all of these. Keeping them working together through upgrades, app onboarding and releases is the real work. A platform turns those building blocks into one contract every team can depend on. That doesn't mean every app looks the same, just that the same capabilities are always there.

## Map each promise to what delivers it

Think of the contract as a set of promises to your developers. Every piece you assemble by hand to keep them is another thing to patch, debug, and staff. The tables group each promise by the need it serves and show what AKS gives you versus what you'd bring yourself.

:::tip

[AKS Automatic](https://learn.microsoft.com/azure/aks/intro-aks-automatic) preconfigures many of the capabilities in the "On AKS" column, giving you a production-ready starting point with less setup. See the [feature comparison](https://learn.microsoft.com/azure/aks/intro-aks-automatic#aks-automatic-and-standard-feature-comparison) for defaults and optional features.

:::

### A place to run

| Promise                                         | On AKS                                                                                                                                                                                                                                                                                            | Bring your own                                                                                                                           |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Your app gets its own boundary                  | [Managed namespaces](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces) with quota, network policy, and RBAC                                                                                                                                                                      | Namespaces you template yourself                                                                                                         |
| You can request an environment                  | Not built in. Building blocks: managed namespaces you can create through Azure Resource Manager                                                                                                                                                                                                   | Crossplane with OpenTofu, or [kro](https://kro.run) with [Azure Service Operator (ASO)](https://azure.github.io/azure-service-operator/) |
| Your app scales without you sizing nodes        | [Node autoprovisioning](https://learn.microsoft.com/azure/aks/node-auto-provisioning), [HPA](https://learn.microsoft.com/azure/aks/horizontal-pod-autoscaler), [VPA](https://learn.microsoft.com/azure/aks/vertical-pod-autoscaler), and [KEDA](https://learn.microsoft.com/azure/aks/keda-about) | Cluster autoscaler or Karpenter, plus VPA and KEDA                                                                                       |
| Routine cluster and node upgrades are automated | [Automatic upgrades](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster) with [maintenance windows](https://learn.microsoft.com/azure/aks/planned-maintenance)                                                                                                                            | Your own upgrade pipeline                                                                                                                |

<details>
<summary>Go deeper: upgrades that follow app health</summary>

A healthy node doesn't prove your app still works. [Health-aware upgrade gates](https://github.com/Azure/AKS-Health-Signal) use your monitoring provider to stop upgrade progress on a failed health check, while [blue-green node pool upgrades](https://learn.microsoft.com/azure/aks/blue-green-node-pool-upgrade) offer manual rollback. Check current support and requirements before making either part of your contract.

</details>

:::warning[Check the provisioning stack's maturity]
[ASO v2 is stable](https://azure.github.io/azure-service-operator/), while [kro is still pre-1.0](https://github.com/kubernetes-sigs/kro/releases). Pin both versions, check the ASO resource APIs your contract needs, and test upgrades before rolling them out. For background, see [Building community with CRDs: Kube Resource Orchestrator](/2025/01/30/kube-resource-orchestrator).
:::

### An identity

| Promise                                                 | On AKS                                                                                                    | Bring your own                                |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| Your app reaches Azure services without a stored secret | [Workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)                     | No secret operator needed                     |
| Your app gets an HTTPS URL                              | [Application routing with the Gateway API](https://learn.microsoft.com/azure/aks/app-routing-gateway-api) | Your own Gateway controller with cert-manager |

**Identity is the big one for me.** My motto has always been "ditch the passwords." When apps use workload identity, the platform stores no secrets for Azure services, and access is granted per component. Not every dependency supports Microsoft Entra authentication yet, but the more that do, the less secret rotation you have to own.

<details>
<summary>Go deeper: when you still need a secret or config</summary>

For dependencies that still require secrets, the [Key Vault provider for Secrets Store CSI Driver](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver) mounts them from Key Vault instead of putting them in your manifests. If the Kubernetes Secret needs to exist independently of your app's pods, [External Secrets Operator](https://external-secrets.io/latest/) can sync it from Key Vault. Neither path makes the dependency secretless. The platform still defines credential rotation and how apps reload changed values.

The [App Configuration Kubernetes provider](https://learn.microsoft.com/azure/azure-app-configuration/quickstart-azure-kubernetes-service) delivers app settings from App Configuration.

</details>

### A way to see what it's doing

| Promise                            | On AKS                                                                                                                                                                                                                                                                                                                           | Bring your own                                       |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| You can see what your app is doing | [Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-metrics-overview), [Container Insights](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-overview), and [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable) | Prometheus, Grafana, and the OpenTelemetry Collector |
| Your team knows what it spends     | [AKS cost analysis](https://learn.microsoft.com/azure/aks/cost-analysis) per namespace                                                                                                                                                                                                                                           | OpenCost                                             |
| You can find what's available      | Not built in                                                                                                                                                                                                                                                                                                                     | Backstage                                            |

### A safe way to ship

| Promise                                     | On AKS                                                                                                                                                                                                                                                                                       | Bring your own               |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| Your images get scanned for vulnerabilities | [Azure Container Registry (ACR)](https://learn.microsoft.com/azure/container-registry/container-registry-intro) with [Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction) scanning enabled                                   | Trivy                        |
| A rejected change tells you how to fix it   | [Deployment Safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards)                                                                                                                                                                                                         | Kyverno                      |
| You ship by merging a pull request          | [Argo CD](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-argocd) or [Flux](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2) extension                                                                                           | Self-managed Argo CD or Flux |
| A bad release doesn't reach everyone        | Not built in. Building blocks: Fleet Manager [staged resource rollout runs](https://learn.microsoft.com/azure/kubernetes-fleet/howto-staged-update-run), or the [Istio-based service mesh add-on](https://learn.microsoft.com/azure/aks/istio-about) as an alternative ingress and mesh path | Argo Rollouts or Flagger     |

**Trusted images take more than a scanner.** Scanning finds vulnerabilities, while signature verification checks the publisher and image integrity. Your platform team configures signing in the pipeline and the admission trust policy. [ACR and Defender don't sign application images for you](https://learn.microsoft.com/azure/defender-for-cloud/containers-software-supply-chain-security-introduction#validate-vulnerability-findings).

<details>
<summary>Go deeper: signing, enforcement, and node hygiene</summary>

Sign images with [Notation](https://learn.microsoft.com/azure/container-registry/container-registry-tutorial-sign-build-push), then block unsigned images at admission with [Ratify and Azure Policy](https://learn.microsoft.com/azure/container-registry/container-registry-tutorial-verify-with-ratify-aks). [Image Cleaner](https://learn.microsoft.com/azure/aks/image-cleaner) removes stale and vulnerable images from your nodes. It's already on with AKS Automatic; on AKS Standard, turn it on yourself.

</details>

:::caution[Choose one ingress path]
Keep application-routing Gateway API as the default ingress path. If you need the Istio service mesh add-on, use its ingress path instead: [the two add-ons cannot run together](https://learn.microsoft.com/azure/aks/app-routing-gateway-api#limitations).
:::

## Where your platform team fits

If you've seen the [BACK stack](https://github.com/crossplane-contrib/back-stack) (Backstage, Argo CD, Crossplane, and Kyverno), you'll notice every piece of it shows up in the "Bring your own" column. Either path keeps the promise. The difference is what delivers it and who maintains it.

Your platform team adds the most value by turning these building blocks into a developer contract. These are yours to design:

- **You can request an environment**: a self-service API in front of managed namespaces and Azure resources, so a team can open a pull request with a name, an owner, and the database it needs, and get all of it back
- **A bad release doesn't reach everyone**: your team defines SLOs, promotion criteria, and rollback policy. Fleet can provide staged resource rollouts across clusters, or you can implement those controls in your GitOps workflow.
- **You can find what's available**: a catalog of what the platform offers

## Start smaller than you think

Start with one project and a workflow other teams could reuse, not a platform for the whole business. One AKS Automatic cluster, a pull request template, one Helm chart, and a GitOps extension may be enough. Prove it saves that team work, then reuse it with a second project. Add an API when pull requests become a bottleneck, and a portal when discovery does.

Every tool in the "Bring your own" column is a system your team has to run: upgrade, patch, monitor, and debug. Backstage is a framework you build on and upgrade, not a product you install ([here's what deploying it to AKS looks like](https://paulyu.dev/deploy-backstage-to-aks/)). Writing and debugging Crossplane compositions takes practice too.

Already running workloads? You don't need to start over. Apply the contract to new namespaces, and move existing teams onto it the next time they touch their deployment.

## Decide who owns what

Developers own their app config and image. The platform team owns the contract, the templates, delivery, and the developer experience. AKS takes on the managed infrastructure work.

Then decide who answers the 3 AM page. The platform team is on call for the contract: namespaces, identity, and delivery. App teams are on call for their apps, and that only works if they can see and fix things without filing a ticket. Give them tools to observe and diagnose, and make Git the fix path.

Give each app its own Application Insights resource and AKS desktop access scoped to its namespace, so every team has telemetry that's theirs by default. Grafana works as a shared view, but filtering dashboards by namespace isn't isolation, because Managed Prometheus access is granted per workspace or per cluster, not per namespace. If a team's metrics need to stay private, give it its own Azure Monitor workspace. For fixing, Git is the way. A `kubectl edit` will get reverted by GitOps on the next sync anyway.

Finally, version the contract like you would any API. When you change a template or deprecate a setting, let teams know before it lands and give them a window to move.

## Run more than one cluster

One cluster is where your platform starts, not where it stays. Most orgs already split dev, test, staging, and prod across clusters, and some teams eventually need their own, because namespaces on a shared cluster are a soft boundary. Teams still share the node kernel, the API server, CRDs, and the upgrade schedule. Either way, the contract has to stay the same on every cluster, and changes have to reach them in a safe order.

Once your platform runs its own components, like a self-service API or a GitOps controller that serves every cluster, the pattern I'd recommend is: **run the platform where you want control, and run tenant workloads where you want guardrails by default.**

- **Control cluster on AKS Standard** runs Crossplane or kro and your GitOps controller. It's small and owned by the platform team, so lock it down: a fixed node count, the Kubernetes [`patch` upgrade channel](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster?tabs=azure-cli#for-aks-standard-clusters), and a [private API server](https://learn.microsoft.com/azure/aks/api-server-vnet-integration). It holds the credentials that create infrastructure, so scope its workload identity to the resource groups it manages and keep tenant workloads off it.
- **Workload clusters on AKS Automatic** run developer apps. Every namespace starts from a hardened baseline, and nodes show up when workloads need them.

Why not Automatic for the control cluster too? Its fixed Kubernetes [`stable` upgrade channel](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster#for-aks-automatic-clusters) includes minor-version upgrades, although you can set maintenance windows. I'd use Standard with Kubernetes [`patch` upgrade channel](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster?tabs=azure-cli#for-aks-standard-clusters) here when the platform team needs explicit approval of minor-version upgrades after testing Crossplane providers or kro. That also means owning those upgrades and keeping the cluster on a supported version.

Use [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/overview) to manage these clusters as a group, but separate infrastructure upgrades from Kubernetes resource rollouts:

- **Start without a hub for infrastructure upgrades.** A Fleet Manager without a hub cluster costs nothing. [Fleet update strategies](https://learn.microsoft.com/azure/kubernetes-fleet/update-orchestration) can stage Kubernetes and node image upgrades across supported cluster configurations, with soak times and approval gates. Check the [Fleet FAQ](https://learn.microsoft.com/azure/kubernetes-fleet/faq#what-clusters-does-multi-cluster-updates-support) for upgrade support and limitations before promising a dev-to-prod upgrade order.
- **Add a hub when you need resource placement.** With a [hub cluster](https://learn.microsoft.com/azure/kubernetes-fleet/concepts-choosing-fleet), Fleet can place the same namespaces, policies, and config on member clusters and [roll those resources out stage by stage](https://learn.microsoft.com/azure/kubernetes-fleet/howto-staged-update-run), with soak times and approval tasks between stages. Git stays the source of truth: your GitOps controller syncs to the hub, and Fleet decides which clusters get the resources and when. The hub doesn't run your workloads.

![Developers open a pull request. A control cluster on AKS Standard runs Crossplane or kro and a GitOps controller, creates Azure resources through Azure Resource Manager, and writes placements to the Fleet Manager hub. Fleet Manager rolls Kubernetes resources out to AKS Automatic workload clusters in stages, dev then staging then prod, with soak times and approval tasks between stages. Automatic infrastructure upgrades run independently.](./platform-topology.svg)

:::info
You don't need all of this on day one. Add each piece when the pain shows up.
:::

## Hand your developers the right tools

The contract only works if developers can use it without learning your plumbing. If the supported path isn't the easiest path, developers will go around you. Here's where I'd start, following the loop a developer actually works in:

- **Get ready to ship with [GitHub Copilot CLI](https://github.com/features/copilot/cli) and [Containerization Assist MCP](https://github.com/Azure/containerization-assist).** It generates and validates a Dockerfile and Kubernetes manifests from your repo. The output lands in a pull request, so AI-generated manifests get the same review and admission policy as everything else.
- **See what's running with [AKS desktop](https://learn.microsoft.com/azure/aks/aks-desktop-overview).** It gives an app-centric view of a namespace with an [AI assistant for troubleshooting](https://learn.microsoft.com/azure/aks/aks-desktop-deploy-ai-assistant), and the assistant works with the developer's own identity and RBAC, nothing more.
- **Prove the app behaves with [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable),** not just that pods are running.
- **Fix it in Git.** Whatever the diagnosis, the change goes through a pull request and GitOps rolls it out.

If your developers live in Visual Studio Code, the [AKS extension](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-aks-tools) can keep manifest creation and cluster troubleshooting in the editor. With Argo CD already installed, its [Argo CD integration](https://azure.github.io/vscode-aks-tools/features/argocd-gitops-integration.html) generates an `Application` manifest pointing at your repo and target namespace. Its [AKS-MCP integration](https://azure.github.io/vscode-aks-tools/features/aks-mcp-server-integration.html) gives Copilot Chat cluster context for troubleshooting. Keep generated manifests and fixes on the same pull request and GitOps path.

So what does this look like in practice? A developer opens a pull request that requests an environment, with the same checks and approvals your organization already requires. After merge, GitOps applies it, and the team gets a managed namespace with quota, a workload identity, Application Insights, and an HTTPS URL. Copilot CLI generates the Dockerfile and manifests, and a second pull request ships the app.

Say a week later, a config change makes it through established change control processes yet causes a performance regression, making the app slower without breaking a single pod. The developer opens AKS desktop and sees the workload is healthy, finds the slow dependency call in Application Insights traces, opens a revert pull request, and watches the fix roll out after the required approvals and merge. They never had to ask the platform team for access, and nothing was changed by hand.

## Measure whether it's working

A platform is a product, so treat adoption as a signal, not a mandate. Track these from day one:

- **Adoption**: teams on the supported path versus going around it
- **Time to first deploy**: from request to a running app
- **Delivery**: [DORA metrics](https://dora.dev/guides/dora-metrics-four-keys/) before and after onboarding
- **Requests to your team**: each one tells you which promise to automate next
- **Developer feedback**: ask often, and act on it

## Trade-offs to keep in mind

- **Fewer tuning options, less upkeep.** AKS Automatic handles node management and routine upgrades, but some settings are fixed. For workload clusters, that can be a useful trade-off when the defaults fit your developer contract. Check the [feature comparison](https://learn.microsoft.com/azure/aks/intro-aks-automatic) and use Standard where you need specific node or upgrade settings.
- **More clusters, more isolation, more coordination.** More credentials, more upgrade cadences, and more places to look when something breaks. Fleet Manager coordinates supported upgrades and, with a hub, stages and reconciles shared config, but you still own access and debugging.
- **Managed defaults move.** Pin what your contract depends on, such as your template and module versions.
- **The contract is portable, the defaults aren't.** Deployment Safeguards, managed namespaces, and Entra-based identity are Azure services. Keep the contract in your own templates or APIs, and moving becomes a swap of the "On AKS" column instead of a rewrite.

## Wrapping up

Start from the contract, not the tool list. Let AKS run the promises it already covers, spend your team's time on the ones it doesn't, and use Fleet Manager to keep the contract consistent as you grow into more clusters.

Not sure where to start? Pick your most-requested manual task, write down the promise behind it, and find it in the tables above.

This post is a starting point for something I want to explore more deeply. I'll follow up here with updates and more hands-on guidance as I go. A few areas I want to dig into:

- **The platform as a product**: proving value with early projects, building business support, and earning further investment
- **The environment contract**: a self-service API with Crossplane or kro
- **The golden path**: from laptop to AKS Automatic in one pull request
- **Diagnose and recover**: finding and fixing issues without a ticket
- **Safe resource rollouts across clusters**: dev to prod with Fleet Manager

Which promises are you still assembling by hand? Let me know in [GitHub Discussions](https://github.com/Azure/AKS/discussions); your answers will help shape what I dig into next.
