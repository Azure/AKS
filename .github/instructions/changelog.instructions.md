<!-- markdownlint-disable -->
---
applyTo: CHANGELOG.md
---

# AKS Changelog Validation Guidelines

> **Scope**: File-specific patterns for CHANGELOG.md release notes.  
> **Repo Standards**: See `.github/copilot-instructions.md` for general conventions and Microsoft Style Guide.

---

## Release Structure Template

Every release section MUST follow this structure:

```markdown
## Release Notes YYYY-MM-DD

> Monitor the release status by regions at [AKS-Release-Tracker](https://releases.aks.azure.com/).

### Announcements

* [Announcement item with link to documentation](https://learn.microsoft.com/...) description of the announcement.

### Release notes

#### Kubernetes versions

* AKS patch versions X.XX.X, X.XX.X are now available.

#### Features

* [Feature Name](https://learn.microsoft.com/azure/aks/feature-doc) description of the feature.

#### Preview features

* [Preview Feature Name](https://learn.microsoft.com/azure/aks/preview-feature-doc) is now available in preview.

#### Behavioral changes

* [Feature Name](https://learn.microsoft.com/azure/aks/feature-doc) now behaves differently. Description of impact.

#### Bug fixes

* Fixed an issue where [description of bug]. See [GitHub issue](https://github.com/Azure/AKS/issues/XXXX) for details.

#### Component updates

* Component Name has been updated to [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z).
* AKS Ubuntu 22.04 node image has been updated to [`YYYYMM.DD.V`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/YYYYMM.DD.V.txt).

---
```

### Structure Rules

- **Release heading**: Use `## Release Notes YYYY-MM-DD` format
- **Release tracker link**: Always include as first line after heading
- **Section hierarchy**: `### Announcements`, `### Release notes` with `####` subsections
- **Include only sections with content**: Omit empty sections entirely
- **Horizontal rule**: Use `---` between releases
- **Bullet points**: Use `*` consistently (not `-`)

---

## Section Formatting Guidelines

### Announcements

Announcements cover deprecations, retirements, upcoming changes, and important notices.

**Template:**

```markdown
* Starting on [DATE], [what will happen]. [Action required]. For more information, see [Link Text](URL).
* [Product/Feature] is now [status]. [Brief description]. Refer to [documentation](URL) for more information.
* [Feature/Product] (preview) will be retired on [DATE]. [Migration instructions]. For more information, see [Link](URL).
* AKS Kubernetes version X.XX [standard support will be deprecated/is going out of support] by [DATE]. [Action required]. Refer to [version support policy](URL) and [upgrading a cluster](URL) for more information.
```

**Examples:**

```markdown
* Starting on 30 November 2025, AKS will no longer support Azure Linux 2.0. Migrate to a supported version by [upgrading your node pools](https://learn.microsoft.com/azure/aks/upgrade-cluster?tabs=azure-cli). For more information, see [\[Retirement\] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).
* AKS Kubernetes version `1.34` is now available in preview. Refer to [1.34 Release Notes](https://kubernetes.io/blog/2025/08/27/kubernetes-v1-34-release/) and [upgrading a cluster](https://learn.microsoft.com/azure/aks/upgrade-cluster) for more information.
* AKS Kubernetes version 1.31 standard support will be deprecated by November 1, 2025. Kindly upgrade your clusters to 1.32 community version or enable [Long Term Support](https://learn.microsoft.com/azure/aks/long-term-support) with 1.31 in order to continue in the same version. Refer to [version support policy](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#kubernetes-version-support-policy) and [upgrading a cluster](https://learn.microsoft.com/azure/aks/upgrade-cluster?tabs=azure-cli) for more information.
* [Teleport (preview)](https://github.com/Azure/acr/blob/main/docs/teleport/aks-getting-started.md) on AKS will be retired on 15 July 2025, please [migrate to Artifact Streaming (preview) on AKS](https://learn.microsoft.com/azure/aks/artifact-streaming) or update your node pools to set --aks-custom-headers EnableACRTeleport=false. For more information, see [aka.ms/aks/teleport-retirement](https://aka.ms/aks/teleport-retirement).
* AKS is now blocking creation of new clusters with Basic Load Balancer [retired on 30 September 2025](https://learn.microsoft.com/answers/questions/1033471/retirement-announcement-basic-load-balancer-will-b).
* Starting 19 October 2025, AKS Automatic clusters will transition to a new billing model in alignment with the service moving from preview to General Availability. For more information, see [Pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).
* Revision asm-1-24 of the Istio add-on has been deprecated. Please migrate to a supported revision following the [Istio add-on upgrade guide](https://learn.microsoft.com/azure/aks/istio-upgrade).
```

---

### Kubernetes versions

Document new Kubernetes version availability and LTS updates.

**Template:**

```markdown
* AKS Version [X.XX Preview](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.md#vXXX0) is being rolled out.
* Kubernetes [X.XX](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.md) is now Generally Available.
* AKS patch versions X.XX.X, X.XX.X, X.XX.X are now available.
* AKS [Kubernetes patch versions](https://kubernetes.io/releases/patch-releases/) X.XX.X, X.XX.X are now available.
* AKS LTS (Long Term Support) patch versions are now available:
  * Kubernetes X.XX.XXX-akslts - [Changelog](URL)
* Kubernetes X.XX and X.XX are now designated as [Long-Term Support (LTS)](URL) versions.
```

**Examples:**

```markdown
* AKS Version [1.34 Preview](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md#v1340) is being rolled out to multiple regions and is expected to complete by early November.
* Kubernetes [1.32](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.32.md) is now Generally Available.
* AKS [Kubernetes patch versions](https://kubernetes.io/releases/patch-releases/) 1.31.7, 1.30.11, 1.29.15 to resolve [CVE-2025-0426](https://nvd.nist.gov/vuln/detail/CVE-2025-0426).
* AKS patch versions 1.32.5, 1.31.9 are now available. Refer to [version support policy](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#kubernetes-version-support-policy) and [upgrading a cluster](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli) for more information.
* AKS LTS (Long Term Support) patch versions are now available:
  * Kubernetes 1.28.102-akslts - [Changelog](https://github.com/aks-lts/kubernetes/blob/release-1.28-lts/CHANGELOG/CHANGELOG-1.28.md#v128102-akslts)
  * Kubernetes 1.29.100-akslts - [Changelog](https://github.com/aks-lts/kubernetes/blob/release-1.29-lts/CHANGELOG/CHANGELOG-1.29.md#v129100-akslts)
  * Kubernetes 1.30.100-akslts - [Changelog](https://github.com/aks-lts/kubernetes/blob/release-1.30-lts/CHANGELOG/CHANGELOG-1.30.md#v130100-akslts)
* Kubernetes 1.31 and 1.32 are now designated as [Long-Term Support (LTS)](https://learn.microsoft.com/azure/aks/long-term-support) versions.
```

---

### Features

Document generally available (GA) features.

**Template:**

```markdown
* [Feature Name](https://learn.microsoft.com/azure/aks/feature-doc) brief description of capability. Additional context if needed.
* Feature Name is now generally available. [Description]. For more information, see [Documentation](URL).
* [Feature Name](URL) is now available in [specific regions/contexts]. [Description].
* You can now [action description]. For more information, see [Documentation](URL).
```

**Examples:**

```markdown
* [Force Upgrade and override drain](https://learn.microsoft.com/azure/aks/upgrade-cluster?tabs=azure-cli#view-the-upgrade-events) now support async validations for PDB-blocking evictions and can be used to bypass PDB restrictions. Requires Azure CLI 2.79.0+ or stable API version 2025-09-01+.
* AKS now allows the use of unsupported GPU vm sizes after skipping gpu driver installation. For more information, see [Skip GPU drivers](https://aka.ms/aks/skip-gpu-drivers).
* [API Server Vnet Integration](https://learn.microsoft.com/azure/aks/api-server-vnet-integration) is now available in East US region.
* [Network isolated cluster](https://learn.microsoft.com/azure/aks/concepts-network-isolated) with outbound type `none` is now Generally Available.
* [Kubelet Serving Certificate Rotation (KSCR)](https://learn.microsoft.com/azure/aks/certificate-rotation#kubelet-serving-certificate-rotation) is now enabled by default in Sovereign cloud regions.
* Azure CNI Overlay is now GA and compatible with [Application Gateway for Containers](https://learn.microsoft.com/azure/application-gateway/for-containers) and [Application Gateway Ingress Controller](https://learn.microsoft.com/azure/application-gateway/ingress-controller-overview). See [AGC networking](https://learn.microsoft.com/azure/application-gateway/for-containers/container-networking) for details on Overlay compatibility.
* [Advanced Container Networking Services: Layer 7 Policies](https://learn.microsoft.com/azure/aks/azure-cni-network-security) reached General Availability.
* You can now enable [Federal Information Process Standard (FIPS)](https://aka.ms/aks/enable-fips) when using [Arm64 VM SKUs](https://aka.ms/aks/arm64) in Azure Linux 3.0 node pools in Kubernetes version 1.31+.
* AKS now supports a new OS Sku enum, [`AzureLinux3`](https://learn.microsoft.com/azure/aks/upgrade-os-version#migrate-to-azure-linux-30). This enum is now GA and supported in Kubernetes versions 1.28 to 1.36.
```

---

### Preview features

Document features available in preview.

**Template:**

```markdown
* [Feature Name](https://learn.microsoft.com/azure/aks/feature-doc) is now available in preview. [Description].
* `FeatureName` mode is available with [component] on AKS X.XX+. More details under [upstream announcement](URL) and [release note](URL).
* You can use the `FeatureFlagName` feature in preview to [description]. [Additional details].
* [Feature Name](URL) is now available in Preview. [Description].
```

**Examples:**

```markdown
* `InPlaceOrRecreate` mode is available with vertical pod autoscaler on AKS 1.34+. More details can be found under [upstream announcement](https://kubernetes.io/blog/2025/05/16/kubernetes-v1-33-in-place-pod-resize-beta/) and [upstream release note](https://github.com/kubernetes/autoscaler/releases/tag/vertical-pod-autoscaler-1.4.2).
* You can use the `EnableCiliumNodeSubnet` feature in preview to [create Cilium node subnet clusters](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium#option-3-assign-ip-addresses-from-the-node-subnet-preview) using Azure CNI Powered by Cilium.
* [Control plane metrics](https://learn.microsoft.com/azure/aks/control-plane-metrics-monitor) are now available through Azure Monitor platform metrics in preview to monitor critical control plane components such as API server and etcd.
* [Azure Monitor Application Insights for Azure Kubernetes Service (AKS) workloads](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless) is now available in preview.
* Ubuntu 24.04 is now available in public preview in k8s 1.32+. ContainerD 2.0 is enabled by default. Use the "Ubuntu2404" os sku enum after registering the preview flag "Ubuntu2404Preview".
* [Managed Namespaces](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces) is now available as preview with Azure RBAC enabled clusters. To get started, [review the documentation](https://learn.microsoft.com/azure/aks/managed-namespaces?pivots=azure-cli).
* [AKS MCP Server](https://github.com/Azure/aks-mcp) is now in public preview.
```

---

### Behavioral changes

Document changes to existing behavior that may impact users.

**Template:**

```markdown
* [Feature/Component](https://learn.microsoft.com/azure/aks/feature-doc) will now [new behavior]. [Impact description]. [Migration guidance if applicable].
* Starting with Kubernetes version X.XX, [what changes]. [Details].
* AKS now [action/behavior]. [Description]. [Documentation link if applicable].
* [Component] memory/CPU [limits/requests] [increased/decreased] from [old value] to [new value] [reason].
```

**Examples:**

```markdown
* Cluster Autoscaler will delete nodes that encounter provisioning errors/failures immediately, instead of waiting for the full max-node-provision-time defined in the [cluster autoscaler profile](https://learn.microsoft.com/azure/aks/cluster-autoscaler?tabs=azure-cli#cluster-autoscaler-profile-settings). This change significantly reduces scale-up delays caused by failed node provisioning attempts.
* [AKS Automatic clusters](https://learn.microsoft.com/azure/aks/intro-aks-automatic) can now only be created with the `stable` upgrade channel and the `NodeImage` Node OS upgrade channel. Existing clusters are not affected.
* Starting with Kubernetes version 1.33, clusters using Azure CNI Powered by Cilium will include a new AKS-managed component named `azure-iptables-monitor`.
* [Node Auto Provisioning](https://learn.microsoft.com/azure/aks/node-autoprovision) default `AKSNodeClass` will now use Ubuntu 22.04 for Kubernetes versions < 1.34 and Ubuntu 24.04 for Kubernetes versions 1.34+. This ensures consistency across AKS node image defaults. This does not affect existing clusters' default `AKSNodeClass`.
* [Deployment safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) now allow an explicit allowlist of container images to mount hostpath volumes, including fluent-bit (mcr.microsoft.com/oss). Additional system namespaces like azappconfig-system, azureml, dapr-system are now excluded by default.
* AKS now automatically reimages all node pools in the cluster when you update the [HTTP proxy configuration](https://learn.microsoft.com/azure/aks/http-proxy) on your cluster using the `az aks update` command.
* [Static Egress Gateway](https://learn.microsoft.com/azure/aks/configure-static-egress-gateway) memory limits increased from 500Mi to 3000Mi reducing the risk of memory-related restarts under load.
* `aksmanagedap` is blocked as a reserved name for AKS system component, you can no longer use it for creating agent pool. See [naming convention](https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes/create-upgrade-delete/aks-common-issues-faq#what-naming-restrictions-are-enforced-for-aks-resources-and-parameters-) for more information.
* AKS will now reject invalid OsSku enums during cluster creation, node pool creation, and node pool update. Previously AKS would default to `Ubuntu`.
```

---

### Bug fixes

Document resolved issues.

**Template:**

```markdown
* Fixed an issue where [description of the problem]. See [GitHub issue](https://github.com/Azure/AKS/issues/XXXX) for details.
* Fixed a bug where [description]. [Additional context if needed].
* Resolved an issue [description]. See [#XXXX](https://github.com/Azure/AKS/issues/XXXX) for more details.
* Fix an [issue](URL) in [component] to [description of fix]. Without this fix, [impact description].
* Fixed [issue](URL) where [component] [problem description].
```

**Examples:**

```markdown
* Fixed an issue where [KAITO](https://learn.microsoft.com/azure/aks/aks-extension-kaito) workspace creation would fail on [AKS Automatic](https://learn.microsoft.com/azure/aks/intro-aks-automatic) because gpu-provisioner creates an agentPool. Non-node auto provisioning pools, such as agentPool, are now allowed to be added to AKS Automatic clusters.
* Fixed a bug where [ETag](https://learn.microsoft.com/azure/aks/use-etags) was not returned in ManagedClusters or AgentPools responses in API versions 2024-09-01 or newer, even though the API specification said it would be.
* Fix an [issue](https://github.com/azure-networking/cilium-private/pull/465) in [Azure CNI Powered by Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium) to improves DNS request/response performance, especially in large scale clusters using FQDN based policies. Without this fix, if the user sets a DNS request timeout below 2 seconds, in high-scale scenarios they may experience request drops due to duplicate request IDs.
* Fixed [issue](https://github.com/Azure/AKS/issues/4720) where AKS evicted pods that had already been manually relocated, causing upgrade failures. This fix adds a node consistency check to ensure the pod is still on the original node before retrying eviction.
* Fixed an [issue](https://github.com/microsoft/retina/issues/1386) with the retina-agent volume to restrict access to only `/var/run/cilium` directory.
* Resolved an issue where node pool scaling failed with customized kubelet configuration. Without this fix, node pools using CustomKubeletConfigs could not be scaled.
* [Bring your own CNI clusters](https://learn.microsoft.com/azure/aks/use-byo-cni?tabs=azure-cli) don't utilize route tables. To optimize resource usage in such clusters, existing route tables will be deleted and no new ones will be created.
```

---

### Component updates

Document version updates for AKS components.

#### Single-version format (inline)

Use when a component has one version across all AKS versions:

```markdown
* Component Name has been updated to [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z).
* Component Name has been upgraded to [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z) addressing [CVE-YYYY-XXXXX](https://nvd.nist.gov/vuln/detail/CVE-YYYY-XXXXX).
* Component Name updated to [vX.Y.Z](URL) to fix [CVE-YYYY-XXXXX](URL).
* [Component Name](URL) has been upgraded to [`vX.Y.Z`](URL), which includes [description of changes].
* Update Component Name to [`vX.Y.Z`](URL) to address [CVE list].
```

**Examples:**

```markdown
* Azure CNI and CNS have been updated to version [`1.7.4`](https://github.com/Azure/azure-container-networking/releases/tag/v1.7.4).
* Container Insights has been upgraded to version [`3.1.30`](https://github.com/microsoft/Docker-Provider/releases/tag/3.1.30).
* Azure Policy Add-on has been upgraded to [`v1.14.2`](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes#1142).
* App Routing updated to version 0.2.10 with ingress-nginx bumped to [`v1.13.1`](https://github.com/Azure/aks-app-routing-operator/pull/497) addressing [CVE-2025-22874](https://nvd.nist.gov/vuln/detail/CVE-2025-22874), [CVE-2025-47906](https://nvd.nist.gov/vuln/detail/CVE-2025-47906), and [CVE-2025-47907](https://nvd.nist.gov/vuln/detail/CVE-2025-47907).
* VPA (Vertical Pod Autoscaler) has been updated to [`1.4.2`](https://github.com/kubernetes/autoscaler/releases/tag/vertical-pod-autoscaler-1.4.2) on AKS 1.34.
* Retina Basic Image has been updated to [`v1.0.0-rc3`](https://github.com/microsoft/retina/releases/tag/v1.0.0-rc3) on both Linux and Windows to resolve [GHSA-2464-8j7c-4cjm](https://github.com/advisories/GHSA-2464-8j7c-4cjm). See [#1824](https://github.com/microsoft/retina/pull/1824) and [#1881](https://github.com/microsoft/retina/pull/1881) for details.
* [Azure Monitor managed service for Prometheus](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-metrics-overview#azure-monitor-managed-service-for-prometheus) addon is updated to the latest release [06-19-2025](https://github.com/Azure/prometheus-collector/blob/main/RELEASENOTES.md#release-06-19-2025).
* Istio revision asm-1-27 is now available for the Istio-based service mesh add-on. Customers can follow canary upgrade guidance to adopt the new revision. For full details, see the [Istio 1.27 release notes](https://istio.io/latest/news/releases/1.27.x/).
* Secrets Store CSI Driver resource requests have been optimized:
  * `aks-secrets-store-provider-azure.provider-azure-installer`: CPU 50m→16m, Memory 100Mi→50Mi
  * `aks-secrets-store-csi-driver.node-driver-registrar`: CPU 10m→5m, Memory 20Mi→10Mi
```

#### Multi-version format (nested bullets)

Use when different AKS versions have different component versions:

```markdown
* Component Name has been upgraded:
  * [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z) on AKS X.XX
  * [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z) on AKS X.XX
```

Alternative inline format for fewer versions:

```markdown
* `Component Name` has been upgraded to [`vX.Y.Z`](URL) on AKS X.XX, and [`vX.Y.Z`](URL) on AKS X.XX.
* Component Name updated to [vX.Y.Z](URL) on AKS X.XX & [vX.Y.Z](URL) on AKS X.XX.
```

**Examples:**

```markdown
* Azure Disk CSI Driver has been upgraded:
  * [`v1.33.5`](https://github.com/kubernetes-sigs/azuredisk-csi-driver/releases/tag/v1.33.5) on AKS 1.33
  * [`v1.32.11`](https://github.com/kubernetes-sigs/azuredisk-csi-driver/releases/tag/v1.32.11) on AKS 1.32
  * [`v1.31.12`](https://github.com/kubernetes-sigs/azuredisk-csi-driver/releases/tag/v1.31.12) on AKS 1.31
* `Azure File CSI driver` has been upgraded to [`v1.32.7`](https://github.com/kubernetes-sigs/azurefile-csi-driver/releases/tag/v1.32.7) on AKS 1.32, and [`v1.33.5`](https://github.com/kubernetes-sigs/azurefile-csi-driver/releases/tag/v1.33.5) on AKS 1.33.
* `Cilium` has been upgraded to `v1.14.20-2` on AKS 1.29 and 1.30, [`v1.16.13`](https://github.com/cilium/cilium/releases/tag/v1.16.13) on AKS 1.31, and [`v1.17.7`](https://github.com/cilium/cilium/releases/tag/v1.17.7) on AKS 1.32 addressing multiple CVEs.
* `Cluster Autoscaler` has been upgraded to [`v1.31.5`](https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.31.5) for AKS 1.31, [`v1.32.2`](https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.32.2) for AKS 1.32, and [`v1.33.0-aks`](https://github.com/kubernetes/autoscaler/releases/tag/cluster-autoscaler-1.33.0) for AKS 1.33.
* Cloud Controller Manager image versions updated to [`v1.33.2`](https://cloud-provider-azure.sigs.k8s.io/blog/2025/07/19/v1.33.2/), [`v1.32.7`](https://cloud-provider-azure.sigs.k8s.io/blog/2025/07/19/v1.32.7/), [`v1.31.8`](https://cloud-provider-azure.sigs.k8s.io/blog/2025/07/19/v1.31.8/), and [`v1.30.14`](https://cloud-provider-azure.sigs.k8s.io/blog/2025/07/19/v1.30.14/).
* Calico bumped to version [`3.30.3`](https://github.com/projectcalico/calico/releases/tag/v3.30.3), [`3.29.5`](https://github.com/projectcalico/calico/releases/tag/v3.29.5).
```

#### VHD/Node image updates

Use relative paths to VHD note files. **Validate that referenced files exist in the repository.** VHD image names should be wrapped in backticks, consistent with component version formatting.

```markdown
* AKS [Image Type] image has been updated to [`ImageName-VERSION`](vhd-notes/path/to/VERSION.txt).
```

**Examples:**

```markdown
* AKS Azure Linux v2 image has been updated to [`AzureLinux-202510.03.0`](vhd-notes/AzureLinux/202510.03.0.txt).
* AKS Azure Linux v3 image has been updated to [`AzureLinux-202510.03.0`](vhd-notes/AzureLinuxv3/202510.03.0.txt).
* AKS Ubuntu 22.04 node image has been updated to [`AKSUbuntu-2204-202510.03.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202510.03.0.txt).
* AKS Ubuntu 24.04 node image has been updated to [`AKSUbuntu-2404-202510.03.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2404/202510.03.0.txt).
* AKS Mariner image has been updated to [`AKSMariner-202305.15.0`](vhd-notes/AKSMariner/202305.15.0.txt).
```

#### Windows node images (grouped format)

```markdown
* Windows node images
  * Server 2019 Gen1 – [`AKSWindows-2019-VERSION`](vhd-notes/AKSWindows/2019/VERSION.txt)
  * Server 2022 Gen1/Gen2 – [`AKSWindows-2022-VERSION`](vhd-notes/AKSWindows/2022/VERSION.txt)
  * Server 23H2 Gen1/Gen2 – [`AKSWindows-23H2-VERSION`](vhd-notes/AKSWindows/23H2/VERSION.txt)
  * Server 2025 Gen1/Gen2 – [`AKSWindows-2025-VERSION`](vhd-notes/AKSWindows/2025/VERSION.txt)
```

**Examples:**

```markdown
* Windows node images
  * Server 2019 Gen1 – [`AKSWindows-2019-17763.7792.250910`](vhd-notes/AKSWindows/2019/17763.7792.250910.txt)
  * Server 2022 Gen1/Gen2 – [`AKSWindows-2022-20348.4171.250910`](vhd-notes/AKSWindows/2022/20348.4171.250910.txt)
  * Server 23H2 Gen1/Gen2 – [`AKSWindows-23H2-25398.1849.250910`](vhd-notes/AKSWindows/23H2/25398.1849.250910.txt)
  * Server 2025 Gen1/Gen2 – [`AKSWindows-2025-26100.6584.250910`](vhd-notes/AKSWindows/2025/26100.6584.250910.txt)
```

Alternative inline format:

```markdown
* Windows node images
  * Server 2019 Gen1 – [`AKSWindows-2019-17763.7558.250714`](vhd-notes/AKSWindows/2019/17763.7558.250714.txt).
  * Server 2022 Gen1/Gen2 – [`AKSWindows-2022-20348.3932.250714`](vhd-notes/AKSWindows/2022/20348.3932.250714.txt).
  * Server 23H2 Gen1/Gen2 – [`AKSWindows-23H2-25398.1732.250714`](vhd-notes/AKSWindows/23H2/25398.1732.250714.txt).
```

---

## Link Requirements

### Documentation links

Features and Behavioral changes should include links to relevant documentation.

| Link Type | Format | Example |
|:----------|:-------|:--------|
| Microsoft Learn | `[Text](https://learn.microsoft.com/...)` | `[upgrade your node pools](https://learn.microsoft.com/azure/aks/upgrade-cluster)` |
| GitHub Issues | `[#XXXX](https://github.com/Azure/AKS/issues/XXXX)` or `[GitHub issue](URL)` | `[#4988](https://github.com/Azure/AKS/issues/4988)` |
| GitHub Releases | `[vX.Y.Z](https://github.com/org/repo/releases/tag/vX.Y.Z)` | `[v1.7.4](https://github.com/Azure/azure-container-networking/releases/tag/v1.7.4)` |
| CVE References | `[CVE-YYYY-XXXXX](https://nvd.nist.gov/vuln/detail/CVE-YYYY-XXXXX)` | `[CVE-2025-22874](https://nvd.nist.gov/vuln/detail/CVE-2025-22874)` |
| VHD Notes | `` [`ImageName-VERSION`](vhd-notes/ImageType/VERSION.txt) `` | `` [`AKSUbuntu-2204-202510.03.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202510.03.0.txt) `` |

### Link rules

- **No locale in URLs**: Use `https://learn.microsoft.com/azure/...` not `https://learn.microsoft.com/en-us/azure/...`
- **Descriptive link text**: Use meaningful text, never "click here" or bare URLs
- **Component versions**: Always use backticks and link to release notes: `` [`v1.33.5`](URL) ``
- **VHD image names**: Always use backticks and link to VHD notes: `` [`AKSUbuntu-2204-202510.03.0`](vhd-notes/...) ``
- **VHD notes**: Use relative paths starting with `vhd-notes/` and **validate files exist**

---

## Microsoft Style Guide Compliance

All content MUST follow the Microsoft Style Guide as defined in `.github/copilot-instructions.md`. Key requirements:

### Terminology

| Correct | Incorrect |
|:--------|:----------|
| node pool | nodepool, node-pool |
| cluster autoscaler | Cluster Autoscaler (when not a resource name) |
| Azure Kubernetes Service (AKS) | Azure Container Service |
| on-premises | on-premise |
| cloud-native (adjective) | cloud native (as adjective) |
| Deployment (resource) | deployment (when referring to the K8s resource) |
| kubectl | Kubectl |

### Voice and tone

- Use active voice
- Be direct and concise
- Use contractions (*it's*, *you're*, *don't*)
- Front-load important information
- Write for scanning first, reading second

### Formatting

- Use sentence-style capitalization for headings
- Use backticks for code, component names, and versions
- Use bold sparingly for emphasis
- Keep paragraphs short (3-4 sentences max)

---

## Validation Checklist

Before committing changes to CHANGELOG.md:

- [ ] Release date uses `YYYY-MM-DD` format
- [ ] Release tracker link is first line after release heading
- [ ] Horizontal rule (`---`) separates releases
- [ ] Only sections with content are included
- [ ] Section hierarchy follows template (`###` for main, `####` under Release notes)
- [ ] Bullet points use `*` consistently
- [ ] All links use descriptive text (no bare URLs or "click here")
- [ ] Microsoft Learn links don't include `/en-us/`
- [ ] Component versions are in backticks with release note links
- [ ] VHD image names are in backticks (e.g., `` [`AKSUbuntu-2204-202306.26.0`](...) ``)
- [ ] VHD note files exist at the referenced paths
- [ ] Features and Behavioral changes include documentation links
- [ ] Content follows Microsoft Style Guide terminology and voice
- [ ] No trailing whitespace

---

## Common Mistakes to Avoid

❌ **Bare URLs**
```markdown
See https://learn.microsoft.com/azure/aks/upgrade-cluster for details.
```
✅ **Descriptive link text**
```markdown
See [upgrading a cluster](https://learn.microsoft.com/azure/aks/upgrade-cluster) for details.
```

---

❌ **Locale-based URLs**
```markdown
[documentation](https://learn.microsoft.com/en-us/azure/aks/upgrade-cluster)
```
✅ **Generic URLs**
```markdown
[documentation](https://learn.microsoft.com/azure/aks/upgrade-cluster)
```

---

❌ **Missing documentation links on features**
```markdown
* AKS now supports feature X. This enables capability Y.
```
✅ **Include documentation links**
```markdown
* [Feature X](https://learn.microsoft.com/azure/aks/feature-x) is now available. This enables capability Y.
```

---

❌ **Unlinked component versions**
```markdown
* Azure CNI has been updated to v1.7.4.
```
✅ **Linked versions in backticks**
```markdown
* Azure CNI has been updated to [`v1.7.4`](https://github.com/Azure/azure-container-networking/releases/tag/v1.7.4).
```

---

❌ **Wrong heading hierarchy**
```markdown
### Release notes
### Features      <!-- Should be #### -->
```
✅ **Correct hierarchy**
```markdown
### Release notes
#### Features
```

---

❌ **Non-existent VHD references**
```markdown
* AKS Ubuntu image updated to [202510.99.0](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202510.99.0.txt).
```
✅ **Verify file exists before referencing**

---

❌ **VHD image names without backticks**
```markdown
* AKS Ubuntu 22.04 image has been updated to [AKSUbuntu-2204-202306.26.0](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202306.26.0.txt).
```
✅ **VHD image names in backticks**
```markdown
* AKS Ubuntu 22.04 image has been updated to [`AKSUbuntu-2204-202306.26.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202306.26.0.txt).
```

---

❌ **Inconsistent bullet characters**
```markdown
* First item
- Second item
* Third item
```
✅ **Consistent bullets**
```markdown
* First item
* Second item
* Third item
```

---

❌ **Missing release separator**
```markdown
## Release Notes 2025-10-12
...content...
## Release Notes 2025-09-21
```
✅ **Horizontal rule between releases**
```markdown
## Release Notes 2025-10-12
...content...

---

## Release Notes 2025-09-21
```

---

❌ **Version numbers without backticks**
```markdown
* Component updated to v1.33.5 on AKS 1.33.
```
✅ **Versions in backticks**
```markdown
* Component updated to [`v1.33.5`](URL) on AKS 1.33.
```

---

❌ **Non-descriptive link text**
```markdown
For more information, click [here](https://learn.microsoft.com/azure/aks/feature).
```
✅ **Meaningful link text**
```markdown
For more information, see [Feature documentation](https://learn.microsoft.com/azure/aks/feature).
```

---

❌ **Terminology not following Microsoft Style Guide**
```markdown
* The nodepool autoscaler on the Cloud will...
```
✅ **Correct terminology**
```markdown
* The node pool cluster autoscaler in cloud services will...
```

---

## Markdown Linting

CHANGELOG.md must pass markdown linting with the following exceptions:

### Required inline disable comment

Add this comment at the **top of CHANGELOG.md** (before the title):

```markdown
<!-- markdownlint-disable MD024 -->
```

### Disabled rules for CHANGELOG.md

| Rule | Reason |
|:-----|:-------|
| MD024 (no-duplicate-heading) | Changelog sections repeat headings like `### Announcements`, `#### Features` across releases |

### Running markdownlint

To validate the CHANGELOG.md file, run markdownlint from the repository root:

```bash
# Install markdownlint-cli if not already installed
npm install -g markdownlint-cli

# Run markdownlint on CHANGELOG.md
markdownlint CHANGELOG.md

# Or use npx without global installation
npx markdownlint-cli CHANGELOG.md
```

**Fix all errors before committing.** Common issues include:

- **MD009**: Trailing spaces - remove whitespace at end of lines
- **MD012**: Multiple consecutive blank lines - use single blank lines
- **MD047**: Files should end with a single newline character
- **MD052**: Reference links and images should use a label that is defined - ensure all `[link text][label]` references have corresponding `[label]: URL` definitions. In some cases, this may be a syntax error that should be corrected to [link text](URL).
- **MD059**: Link text should be meaningful - avoid "click here", "link", "this link", "here", etc. or bare URLs; use descriptive text instead. Also aligned with the Microsoft Style Guide.

```

---

**Questions?** See `.github/copilot-instructions.md` for the complete Microsoft Style Guide and repository standards.
