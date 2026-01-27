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

> Monitor the release status by regions at [AKS-Release-Tracker](https://releases.aks.azure.com/). This release is titled `vYYYYMMDD`.

### Announcements of upcoming changes and retirements

* [Announcement item with link to documentation if it exists](https://learn.microsoft.com/...) description of the announcement or retirement.

### Release notes

#### Kubernetes versions

* AKS versions X.Y.Z, X.Y'.Z are now available in community support.
* AKS versions X.Y.Z are now deprecated under community support.
* AKS LTS (Long Term Support) versions are now available:
  * Kubernetes X.Y.Z-akslts - [Changelog](link-to-changelog)
* AKS versions X.Y.Z are now deprecated under long term support.

More information on supported versions and version support policy is available in [documentation](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#kubernetes-version-support-policy)

#### Features

* [Feature Name](https://learn.microsoft.com/azure/aks/feature-doc) is now generally available. Brief 1 line description of the value proposition of the feature here.

#### Preview features

* [Preview Feature Name](https://learn.microsoft.com/azure/aks/preview-feature-doc) is now available in preview. Brief 1 line description of the value proposition of the feature here.

#### Behavioral changes

* [Feature Name](https://learn.microsoft.com/azure/aks/feature-doc) now behaves differently. Description of impact.

#### Bug fixes

* Fixed an issue where [description of bug]. See [GitHub issue](https://github.com/Azure/AKS/issues/XXXX) for details.

#### Component updates

* Component name has been updated to [`X.Y.Z`](https://github.com/org/repo/releases/tag/X.Y.Z).
* AKS Ubuntu 22.04 node image has been updated to [`AKSUbuntu-2204-YYYYMM.DD.V`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/YYYYMM.DD.V.txt).

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

Announcements cover deprecations, retirements, upcoming changes, and important notices. Do not add any past announcements that are no longer relevant.

**Template:**

```markdown
* Starting on [DATE], [what will happen]. [Action required]. For more information, see [Link Text](URL).
* [Feature/Product] (preview) will be retired on [DATE]. [Migration instructions]. For more information, see [Link](URL).
* AKS Kubernetes version X.XX [standard support will be deprecated/is going out of support] by [DATE]. [Action required]. Refer to [version support policy](URL) and [upgrading a cluster](URL) for more information.
```

**Examples:**

```markdown
* Starting on 30 November 2025, AKS will no longer support Azure Linux 2.0. Migrate to a supported version by [upgrading your node pools](https://learn.microsoft.com/azure/aks/upgrade-cluster?tabs=azure-cli). For more information, see [\[Retirement\] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).
* AKS Kubernetes version 1.31 standard support will be deprecated by November 1, 2025. Kindly upgrade your clusters to 1.32 community version or enable [Long Term Support](https://learn.microsoft.com/azure/aks/long-term-support) with 1.31 in order to continue in the same version. Refer to [version support policy](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#kubernetes-version-support-policy) and [upgrading a cluster](https://learn.microsoft.com/azure/aks/upgrade-cluster?tabs=azure-cli) for more information.
* [Teleport (preview)](https://github.com/Azure/acr/blob/main/docs/teleport/aks-getting-started.md) on AKS will be retired on 15 July 2025, please [migrate to Artifact Streaming (preview) on AKS](https://learn.microsoft.com/azure/aks/artifact-streaming) or update your node pools to set --aks-custom-headers EnableACRTeleport=false. For more information, see [aka.ms/aks/teleport-retirement](https://aka.ms/aks/teleport-retirement).
* AKS is now blocking creation of new clusters with Basic Load Balancer [retired on 30 September 2025](https://learn.microsoft.com/answers/questions/1033471/retirement-announcement-basic-load-balancer-will-b).
* Starting 19 October 2025, AKS Automatic clusters will transition to a new billing model in alignment with the service moving from preview to General Availability. For more information, see [Pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).
* Revision asm-1-24 of the Istio add-on has been deprecated. Please migrate to a supported revision following the [Istio add-on upgrade guide](https://learn.microsoft.com/azure/aks/istio-upgrade).
```

---

### Kubernetes versions

Document new Kubernetes version availability and LTS updates. Also call out Kubernetes versions that are being deprecated from community support and long term support.

**Template:**

```markdown
#### Versions introduced or graduating to GA
* Kubernetes Version [X.XX Preview](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.md) is being rolled out.
* Kubernetes Version [X.XX](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.md) is now generally available.
* Kubernetes patch versions [X.XX.X](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.X.md), [X.XX.X](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.X.md), [X.XX.X](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.X.md) are now available.
* Kubernetes LTS (Long Term Support) patch versions are now available:
  * Kubernetes X.XX.XXX-akslts - [Changelog](URL)
* Kubernetes version [X.XX](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-X.XX.md) is now designated as [Long-Term Support (LTS)](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#long-term-support-lts) version.


#### Deprecated versions
* AKS version X.Y is now deprecated under community support.
* AKS version X.Y is now deprecated under long term support.
```

**Examples:**

```markdown
#### Versions introduced or graduating to GA
* Kubernetes Version [1.34 Preview](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md) is being rolled out.
* Kubernetes Version [1.32](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.32.md) is now generally available.
* Kubernetes patch versions [1.32.5](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.32.md), [1.31.9](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.31.md) are now available.
* Kubernetes LTS (Long Term Support) patch versions are now available:
  * Kubernetes 1.28.102-akslts - [Changelog](https://github.com/aks-lts/kubernetes/blob/release-1.28-lts/CHANGELOG/CHANGELOG-1.28.md#v128102-akslts)
  * Kubernetes 1.29.100-akslts - [Changelog](https://github.com/aks-lts/kubernetes/blob/release-1.29-lts/CHANGELOG/CHANGELOG-1.29.md#v129100-akslts)
  * Kubernetes 1.30.100-akslts - [Changelog](https://github.com/aks-lts/kubernetes/blob/release-1.30-lts/CHANGELOG/CHANGELOG-1.30.md#v130100-akslts)
* Kubernetes version [1.31](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.31.md) is now designated as [Long-Term Support (LTS)](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#long-term-support-lts) version.


#### Deprecated versions
* AKS version 1.29 is now deprecated under community support.
* AKS version 1.27 is now deprecated under long term support.
```

---

### Features

Document generally available (GA) features.

**Template:**

```markdown
* [Feature Name](URL) is now generally available. Brief 1 line description of the feature and its value proposition here.
* [Feature Name](URL) is now generally available in specific regions/contexts. Brief 1 line description of the feature and its value proposition here.
```

**Examples:**

```markdown
* [Force Upgrade and override drain](https://learn.microsoft.com/azure/aks/upgrade-cluster?tabs=azure-cli#view-the-upgrade-events) is now generally available. Supports async validations for PDB-blocking evictions and can bypass PDB restrictions using Azure CLI 2.79.0+ or stable API version 2025-09-01+.
* [Skip GPU drivers](https://aka.ms/aks/skip-gpu-drivers) is now generally available. Allows the use of unsupported GPU VM sizes after skipping GPU driver installation.
* [API Server Vnet Integration](https://learn.microsoft.com/azure/aks/api-server-vnet-integration) is now generally available in East US region. Enables private API server access within your virtual network.
* [Network isolated cluster](https://learn.microsoft.com/azure/aks/concepts-network-isolated) is now generally available. Supports outbound type `none` for fully isolated cluster deployments.
* [Kubelet Serving Certificate Rotation (KSCR)](https://learn.microsoft.com/azure/aks/certificate-rotation#kubelet-serving-certificate-rotation) is now generally available in Sovereign cloud regions. Enabled by default for enhanced certificate management.
* [Azure CNI Overlay](https://learn.microsoft.com/azure/aks/azure-cni-overlay) is now generally available. Compatible with Application Gateway for Containers and Application Gateway Ingress Controller.
* [Advanced Container Networking Services: Layer 7 Policies](https://learn.microsoft.com/azure/aks/azure-cni-network-security) is now generally available. Provides advanced network security policies at the application layer.
* [FIPS on Arm64](https://aka.ms/aks/enable-fips) is now generally available. Enables Federal Information Process Standard compliance on Arm64 VM SKUs in Azure Linux 3.0 node pools with Kubernetes version 1.31+.
* [AzureLinux3 OS SKU](https://learn.microsoft.com/azure/aks/upgrade-os-version#migrate-to-azure-linux-30) is now generally available. Supported in Kubernetes versions 1.28 to 1.36.
```

---

### Preview features

Document features available in preview.

**Template:**

```markdown
* [Feature Name](URL) is now available as preview. Brief 1 line description of the feature and its value proposition here.
* [Feature Name](URL) is now available as preview in specific regions/contexts. Brief 1 line description of the feature and its value proposition here.
```

**Examples:**

```markdown
* [InPlaceOrRecreate mode for VPA](https://kubernetes.io/blog/2025/05/16/kubernetes-v1-33-in-place-pod-resize-beta/) is now available as preview. Enables in-place pod resizing with vertical pod autoscaler on AKS 1.34+.
* [Cilium Node Subnet](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium#option-3-assign-ip-addresses-from-the-node-subnet-preview) is now available as preview. Use the `EnableCiliumNodeSubnet` feature to create Cilium node subnet clusters using Azure CNI Powered by Cilium.
* [Control plane metrics](https://learn.microsoft.com/azure/aks/control-plane-metrics-monitor) is now available as preview. Monitor critical control plane components such as API server and etcd through Azure Monitor platform metrics.
* [Azure Monitor Application Insights for AKS workloads](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless) is now available as preview. Provides application-level monitoring and insights for Kubernetes workloads.
* [Ubuntu 24.04](https://learn.microsoft.com/azure/aks/node-image-upgrade) is now available as preview in Kubernetes 1.32+. ContainerD 2.0 is enabled by default; use the "Ubuntu2404" OS SKU enum after registering the "Ubuntu2404Preview" feature flag.
* [Managed Namespaces](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces) is now available as preview. Requires Azure RBAC enabled clusters for namespace-level access management.
* [AKS MCP Server](https://github.com/Azure/aks-mcp) is now available as preview. Provides Model Context Protocol server integration for AKS management.
```

---

### Behavioral changes

Document changes to existing behavior that may impact users.

**Template:**

```markdown
* [Feature/Component](https://learn.microsoft.com/azure/aks/feature-doc) will now have [new behavior]. [Impact description]. [Migration guidance if applicable].
* [Component] memory/CPU [limits/requests] [increased/decreased] from [old value] to [new value] [reason].
```

**Examples:**

```markdown
* [Cluster Autoscaler](https://learn.microsoft.com/azure/aks/cluster-autoscaler?tabs=azure-cli#cluster-autoscaler-profile-settings) will now delete nodes that encounter provisioning errors/failures immediately. Previously waited for full max-node-provision-time, now reduces scale-up delays caused by failed node provisioning attempts.
* [AKS Automatic clusters](https://learn.microsoft.com/azure/aks/intro-aks-automatic) will now only allow creation with the `stable` upgrade channel and `NodeImage` Node OS upgrade channel. Existing clusters are not affected.
* [Azure CNI Powered by Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium) will now include a new AKS-managed component named `azure-iptables-monitor`. Applies to Kubernetes version 1.33+ clusters.
* [Node Auto Provisioning](https://learn.microsoft.com/azure/aks/node-autoprovision) will now use Ubuntu 22.04 for Kubernetes versions < 1.34 and Ubuntu 24.04 for Kubernetes versions 1.34+ in default `AKSNodeClass`. Existing clusters' default `AKSNodeClass` not affected.
* [Deployment safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) will now allow an explicit allowlist of container images to mount hostpath volumes, including fluent-bit (mcr.microsoft.com/oss). Additional system namespaces like azappconfig-system, azureml, dapr-system are now excluded by default.
* [HTTP proxy configuration](https://learn.microsoft.com/azure/aks/http-proxy) will now automatically reimage all node pools in the cluster when updated using `az aks update`. Ensures proxy settings are applied consistently across all nodes.
* [Static Egress Gateway](https://learn.microsoft.com/azure/aks/configure-static-egress-gateway) memory limits increased from 500Mi to 3000Mi. Reduces risk of memory-related restarts under load.
* [Agent pool naming](https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes/create-upgrade-delete/aks-common-issues-faq#what-naming-restrictions-are-enforced-for-aks-resources-and-parameters-) will now block `aksmanagedap` as a reserved name for AKS system component. Cannot be used for creating agent pools.
* [OsSku validation](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions) will now reject invalid OsSku enums during cluster creation, node pool creation, and node pool update. Previously defaulted to `Ubuntu`.
```

---

### Bug fixes

Document resolved issues.

**Template:**

```markdown
* Fixed an issue where [description of the problem]. See [GitHub issue](https://github.com/Azure/AKS/issues/XXXX) for details.
* Fixed a bug where [description]. [Additional context if needed].
* Fix an [issue](URL) in [component] to [description of fix]. Without this fix, [impact description].
* Fixed [issue](URL) where [component] [problem description].
```

**Examples:**

```markdown
* Fixed an issue where [KAITO](https://learn.microsoft.com/azure/aks/aks-extension-kaito) workspace creation would fail on [AKS Automatic](https://learn.microsoft.com/azure/aks/intro-aks-automatic) because gpu-provisioner creates an agentPool. Non-node auto provisioning pools are now allowed to be added to AKS Automatic clusters.
* Fixed a bug where [ETag](https://learn.microsoft.com/azure/aks/use-etags) was not returned in ManagedClusters or AgentPools responses in API versions 2024-09-01 or newer. API specification indicated ETag would be returned.
* Fixed [issue](https://github.com/azure-networking/cilium-private/pull/465) where [Azure CNI Powered by Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium) DNS request/response performance degraded in large scale clusters using FQDN based policies. Without this fix, DNS request timeouts below 2 seconds may experience request drops due to duplicate request IDs.
* Fixed [issue](https://github.com/Azure/AKS/issues/4720) where AKS evicted pods that had already been manually relocated, causing upgrade failures. Added node consistency check to ensure the pod is still on the original node before retrying eviction.
* Fixed [issue](https://github.com/microsoft/retina/issues/1386) where retina-agent volume had unrestricted access. Restricted access to only `/var/run/cilium` directory.
* Fixed an issue where node pool scaling failed with customized kubelet configuration. Without this fix, node pools using CustomKubeletConfigs could not be scaled.
* Fixed an issue where [Bring your own CNI clusters](https://learn.microsoft.com/azure/aks/use-byo-cni?tabs=azure-cli) had unused route tables. Existing route tables will be deleted and no new ones will be created to optimize resource usage.
```

---

### Component updates

* Document version updates for AKS components.
* Only include components that are external user facing and don't include components that are internal to AKS service design.
* Only accept links to release notes of components that are publicly accessible and not from private repositories.
* For VHD notes, only accept links to vhd notes that have been added under vhd-notes folder in this repository. Do not accept links external to this repository for the release notes. Follow this same format for other node images like Ubuntu 24.04, Azure Linux v2, Azure Linux v3, Mariner, Windows etc.
* When CVEs are being mentioned, reference the NVD or GitHub security advisory links.
* For Istio-based service mesh add-on updates, include a link to the Istio release notes for the corresponding version. Also mention how users can restart workload pods to trigger re-injection of the updated istio-proxy version. Provide a link to Istio canary upgrade documentation.

#### Single-version format (inline)

Use when a component has one version across all AKS versions:

```markdown
* Component name has been updated to [`X.Y.Z`](https://github.com/org/repo/releases/tag/X.Y.Z).
* Component name has been updated to [`X.Y.Z`](https://github.com/org/repo/releases/tag/X.Y.Z) addressing [CVE-YYYY-XXXXX](https://nvd.nist.gov/vuln/detail/CVE-YYYY-XXXXX).
* Component name has been updated to [`X.Y.Z`](https://github.com/org/repo/releases/tag/X.Y.Z) addressing [GHSA-XXXX-YYYY-ZZZZ](https://github.com/advisories/GHSA-XXXX-YYYY-ZZZZ).
* Component name has been updated to [`X.Y.Z`](https://github.com/org/repo/releases/tag/X.Y.Z), which includes [description of changes].
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
* [Istio-based service mesh add-on](https://learn.microsoft.com/azure/aks/istio-about) has been updated with patch releases 1.25.3 and 1.26.2 for Istio-based service mesh revisions [asm-1-25](https://istio.io/latest/news/releases/1.25.x/announcing-1.25/) and [asm-1-26](https://istio.io/latest/news/releases/1.26.x/announcing-1.26/). To adopt patch updates, restart workloads to trigger sidecar re-injection of the new istio-proxy version.
```

#### Multi-version format (nested bullets)

Use when different AKS versions have different component versions:

```markdown
* Component Name has been upgraded:
  * [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z) on AKS X.XX
  * [`vX.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z) on AKS X.XX
```


**Examples:**

```markdown
* Azure Disk CSI Driver has been upgraded:
  * [`v1.33.5`](https://github.com/kubernetes-sigs/azuredisk-csi-driver/releases/tag/v1.33.5) on AKS 1.33
  * [`v1.32.11`](https://github.com/kubernetes-sigs/azuredisk-csi-driver/releases/tag/v1.32.11) on AKS 1.32
  * [`v1.31.12`](https://github.com/kubernetes-sigs/azuredisk-csi-driver/releases/tag/v1.31.12) on AKS 1.31
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
| Microsoft Learn | [Text](https://learn.microsoft.com/...) | [upgrade your node pools](https://learn.microsoft.com/azure/aks/upgrade-cluster) |
| GitHub Issues | [#XXXX](https://github.com/Azure/AKS/issues/XXXX) or [GitHub issue](URL) | [#4988](https://github.com/Azure/AKS/issues/4988) |
| GitHub Releases | [`X.Y.Z`](https://github.com/org/repo/releases/tag/vX.Y.Z) | [`1.7.4`](https://github.com/Azure/azure-container-networking/releases/tag/v1.7.4) |
| CVE References | [CVE-YYYY-XXXXX](https://nvd.nist.gov/vuln/detail/CVE-YYYY-XXXXX) | [CVE-2025-22874](https://nvd.nist.gov/vuln/detail/CVE-2025-22874) |
| VHD Notes | [`ImageName-VERSION`](vhd-notes/ImageType/VERSION.txt) | [`AKSUbuntu-2204-202510.03.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202510.03.0.txt) |

### Link rules

- **No locale in URLs**: Use `https://learn.microsoft.com/azure/...` not `https://learn.microsoft.com/en-us/azure/...`
- **Descriptive link text**: Use meaningful text, never "click here" or bare URLs
- **Component versions**: Always require link to release notes:  [`v1.33.5`](URL)
- **VHD image names**: Always require link to VHD notes: [`AKSUbuntu-2204-202510.03.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202510.03.0.txt)
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
- [ ] VHD image names are in backticks and use the full Markdown link format (e.g., ``[`AKSUbuntu-2204-202306.26.0`](vhd-notes/aks-ubuntu/AKSUbuntu-2204/202306.26.0.txt)``)
- [ ] VHD note files exist at the referenced paths
- [ ] Features and Behavioral changes include documentation links
- [ ] Content follows Microsoft Style Guide terminology and voice
- [ ] No trailing whitespace
- [ ] Bug fixes all have a corresponding GitHub link
- [ ] Component updates especially for upstream OSS projects should link to the corresponding upstream release note
- [ ] Anything that is a Feature or Kubernetes version shouldn't be in Announcements.

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

---

**Questions?** See `.github/copilot-instructions.md` for the complete Microsoft Style Guide and repository standards.
