# Azure Kubernetes Service Changelog

## Release 2019-09-09

**This release is rolling out to all regions**

**Service Updates**
* AKS Kubernetes 1.10 support will end-of-lifed on Oct 25, 2019
  * https://azure.microsoft.com/en-us/updates/kubernetes-1-10-x-end-of-life-upgrade-by-oct-25-2019/
* AKS Kubernetes 1.11 & 1.12 support will be end-of-lifed on Dec 9th, 2019
  * Kubernetes 1.15 support on AKS will go GA in Oct 2019
  * Post with additional information will be linked.


* New Features
  * VMSS backed AKS clusters are now GA
    * VMSS is the underlying compute resource type which enables features such
      as cluster autoscaler, but is a separate feature.
    * See https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview
      and https://docs.microsoft.com/azure/aks/cluster-autoscaler
      for more information.
    * **NOTE**: Official support in the Azure CLI for AKS+VMSS will be released
      on 2019-09-24 (version 2.0.74 https://github.com/Azure/azure-cli/milestone/73)
  * Standard Load Balancer support (SLB) is now GA
    * See https://docs.microsoft.com/azure/aks/load-balancer-standard
      for documentation.
    * **NOTE**: Official support in the Azure CLI for AKS+SLB will be released
      on 2019-09-24 (version 2.0.74 https://github.com/Azure/azure-cli/milestone/73)
  * Support for the following VM SKUs is now released: Standard_D48_v3,
    Standard_D48s_v3, Standard_E48_v3, Standard_E48s_v3, Standard_F48s_v2,
    Standard_L48s_v2, Standard_M208ms_v2, Standard_M208s_v2
* Bug Fixes
  * Fixed an issue where cluster upgrade could be blocked when the "managedBy"
    property is missing from the node resource group.
  * Fixed an issue where ingress controller network policy would block all
    egress traffic when assigned to pods (using label selectors).
* Behavioral Changes
  * Review the planned changes for new cluster creation defaults referenced in
    [Release 2019-08-26](https://github.com/Azure/AKS/releases/tag/2019-08-26)
* Preview Features
  * Fixed an issue where multiple nodepool clusters would use the incorrect
    version(s) and block upgrades.
  * Fixed an issue where AKS would incorrectly allow customers to specify
    different versions for multiple nodepools.
  * Fixed an issue where the incorrect node count would be returned or fail to
    update when using multiple node pools


## Release 2019-09-02

* Preview Features
  * Kubernetes 1.15 is now in Preview (1.15.3)

* Bug Fixes
  * A bug where kube-svc-redirect would crash due to an invalid bash line has been fixed.
  * A recent Kubernetes dashboard change to enable self-signed certs has been reverted due to browser issues.
  * A bug where the OMSAgent pod would fail scheduling on a user tainted node has been fixed with proper toleration on the OMSAgent pod.
  * A preview bug allowing more than 8 node pools to be created has been fixed to enforce a max of 8 node pools per cluster.
  * A preview bug that would change the primary node pool when adding a new node pool has been fixed.

* Behavioral Changes
  * Review the planned changes for new cluster creation defaults referenced in [Release 2019-08-26](https://github.com/Azure/AKS/releases/tag/2019-08-26)

* Component Updates
  * aks-engine has been updated to v0.40.0
    * https://github.com/Azure/aks-engine/releases/tag/v0.40.0

## Release 2019-08-26

**This release is rolling out to all regions**

* Features
  * Added prometheus annotation to coredns to facilitate metric port discovery
    * For more info please check: <https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-agent-config#overview-of-configurable-prometheus-scraping-settings>
* Bug Fixes
  * Fixed bug with older 1.8 clusters that was preventing clusters from upgrading.
    * **Important: this was a best effort fix since these cluster versions are out of support. Please upgrade to a currently supported version**
    * For information on how AKS handles Kubernetes version support see:
      [Supported Kubernetes versions in Azure](https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions)
  * Removed the default restricted Pod Security Policy to solve race condition with containers not seeing the user in their config. This policy can be applied by customers.
  * Fixed a bug with kube-proxy, ip-masq-agent and kube-svc-redirect where in certain scenarios they could try to access iptables at the same time.
* Preview Features
  * CLI extension updated for new Standard Load Balancer (SLB) and VM Scale Set (VMSS) Parameters:
    * `--vm-set-type` Agent pool vm set type. VirtualMachineScaleSets or AvailabilitySet.
    * `--load-balancer-sku` - Azure Load Balancer SKU selection for your cluster. Basic or Standard.
    * `--load-balancer-outbound-ip-prefixes` - Comma-separated public IP prefix resource IDs for load balancer outbound connection. Valid for Standard SKU load balancer cluster only.
    * `--load-balancer-outbound-ips` - Comma-separated public IP resource IDs for load balancer outbound connection. Valid for Standard SKU load balancer cluster only.
    * `--load-balancer-managed-outbound-ip-count` - Desired number of automatically created and managed outbound IPs for load balancer outbound connection. Valid for Standard SKU load balancer cluster only.
* Behavioral Changes
  * Starting from 2019-09-10, the **preview CLI extension** will default new cluster creates to VM Scale-Sets and Standard Load Balancers (VMSS/SLB) instead of VM Availability Sets and Basic Load Balancers (VMAS/BLB).
  * Starting from 2019-10-22 the official CLI and Azure Portal will default new cluster creates to VMSS/SLB instead of VMAS/BLB.
  * These client defaults changes are important to be aware of due to:
    * SLB will automatically assign a public IP to enable egress. This is a requirement placed by Azure Standard Load Balancers, to learn more about Standard vs. Basic, read [here](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-standard-overview).
    * SLB enables bringing your own IP address to be used, you will be able to define these with new parameters.
    * The capability to use an SLB without any public IP assigned is on the roadmap plan.
    * You may still provision a basic load balancer by specifying "basic" for the "loadbalancersku" property at cluster create time.
    * Read more at <https://aka.ms/aks/slb>
* Component Updates
  * aks-engine has been updated to v0.39.2
    * <https://github.com/Azure/aks-engine/releases/tag/v0.39.2>
  * Azure Monitor for Containers Agent updated to 2019-08-22 release: <https://github.com/microsoft/Docker-Provider/releases>

## Release 2019-08-19 (Hotfix)

**This release is rolling out to all regions**

**Please Note**: This release includes new Kubernetes versions 1.13.10 &
1.14.6 these include the fixes for CVEs CVE-2019-9512 and
CVE-2019-9514. Please see our [customer guidance](https://github.com/Azure/AKS/issues/1159)

* Bug Fixes
  * New kubernetes versions released to fix CVE-2019-9512 and CVE-2019-9514
    * Kubernetes 1.14.6
    * Kubernetes 1.13.10
  * Fixed Azure Network Policy bug with multiple labels under a matchLabels selector.
  * Fix for CNI lock timeout issue caused due to race condition in starting telemetry process.
  * Fixed issue creating AKS clusters using supported Promo SKUs
* Component Updates
  * aks-engine has been updated to v0.38.8
    * https://github.com/Azure/aks-engine/releases/tag/v0.38.8
  * Azure CNI has been updated to v1.0.25


## Release 2019-08-12

**This release is rolling out to all regions**

* Bug Fixes
  * Several bug fixes for AKS NodePool creation and other CRUD operations.
  * Fixed audit log bug on older < 1.9.0 clusters.
    * **Important: this was a best effort fix since these cluster versions are out of support. Please upgrade to a currently supported version**
    * For information on how AKS handles Kubernetes version support see:
      [Supported Kubernetes versions in Azure](https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions)
  * Improved error messaging for VM size errors, including actions to take.
  * Fixed for PUT request bug that caused an unexpected API restart.

* Behavioral Changes
  * AKS has released an API update, documentation available here: [https://docs.microsoft.com/en-us/rest/api/aks/managedclusters](https://docs.microsoft.com/en-us/rest/api/aks/managedclusters)
    * **Important:** With this API update there are changes to the API whitelisting API. This is now under [ManagedClusterAPIServerAccessProfile](https://docs.microsoft.com/en-us/rest/api/aks/managedclusters/createorupdate#managedclusterapiserveraccessprofile), where previously it was a top level property.

## Release 2019-08-05

**This release is rolling out to all regions**

**Please Note**: This release includes new Kubernetes versions 1.13.9 &
1.14.5 (GA today) these include the fixes for CVEs CVE-2019-11247 and
CVE-2019-11249. Please see our [customer guidance](https://github.com/Azure/AKS/issues/1145)

* New Features
  * Kubernetes 1.14 is now GA (1.14.5)
    * As of Monday August 12th (2019-08-12) customers running Kubernetes 1.10.x
      have 60 days (2019-10-14) to upgrade to a supported release. Please see
      [AKS supported versions document][1] for more information.
  * [Kubernetes Audit log](https://docs.microsoft.com/en-us/azure/aks/view-master-logs)
    support is now GA.
* Bug Fixes
  * Fixed an issue where creating a cluster with a custom subnet would return an
    HTTP error 500 vs 400 when the subnet could not be found.
* Behavioral Changes
* Preview Features
  * Fixed an issue where customers could not create a new node pool with AZs
    even if they were already using SLBs.
  * Fixed an issue where VMSS cluster commands could return the incorrect node
    count.
* Component Updates
  * aks-engine has been updated to v0.38.7
    * https://github.com/Azure/aks-engine/releases/tag/v0.38.7


## Release 2019-07-29

* New Features
  * Customers may now create multiple AKS clusters using ARM templates
    regardless of what region the clusters are located in.
* Bug Fixes
  * AKS has resolved the issue(s) with missing metrics in the default
    metrics blade.
  * An issue where the `--pod-max-pids` was set to 100 (maximum) for clusters
    and re-applied during upgrade causing `pthread_create() failed (11: Resource
    temporarily unavailable)` pod start failures was fixed.
    * See https://github.com/Azure/aks-engine/pull/1623 for more information

* Preview Features
  * AKS is now in **Public Preview** in the Azure Government (Fairfax, VA)
    region. Please note the following:
    * Azure Portal support for AKS is in progress, for now customers must use the
      Azure CLI for all cluster operations currently.
    * AKS preview features are not supported in Azure Government currently and will
      be supported when those features are GA.
  * Fixed an issue where a delete request for a locked VMSS node would get an
    incorrect and unclear `InternalError` failure - the error message and error
    code have both been fixed.
  * Fixed an issue with egress filtering where managed AKS pods
    would incorrectly use the IP address to connect instead of the FQDN.
  * Fixed an issue with the SLB preview where AKS allowed the customer to
    provide an IP address already in use by another SLB.
  * An issue that prevented customers from using normal cluster operations
    on multiple node pool clusters with a single VMSS pool has been fixed.

* Component Updates
  * AKS-Engine has been updated to v0.38.4
    * https://github.com/Azure/aks-engine/releases/tag/v0.38.4

## Release 2019-07-22

* Preview Features
  * An issue where New Windows node pools in existing cluster would not get
    updated Windows versions has been fixed.
  * TCP reset has been set for all new clusters using the SLB preview.
  * An issue where AKS would trigger a scale operation requested on a previously
    deleted VMSS cluster has been fixed.
* Component Updates
  * AKS-Engine has been updated to v0.38.3

## Release 2019-07-15

**Important behavioral change**: All AKS clusters are being updated to pull all
needed container images for cluster operations from Azure Container Registry,
this means if you have custom allow/deny lists, port filtering, etc you will
need to update your network configuration to allow ACR.

[Please see the documentation](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#required-ports-and-addresses-for-aks-clusters) for more
information including all required AKS cluster ports and URLs


* New Features
  * Support for the M, NC_promo and DS_v3 Azure Compute VM SKUs has been added.
* Bug Fixes
  * Fixed an issue with clusters created in Canada and Australia regions between
    2019-07-09 and 2019-07-10 as well as US region clusters created on 2019-07-10
    where customers would receive `error: Changing property
    'platformFaultDomainCount' is not allowed` errors.

* Behavioral Changes
  * The error message returned to users when attempting to create clusters with
    an unsupported Kubernetes version in that region has been fixed.
  * Noted above, AKS has moved all container images required by AKS clusters for
    cluster CRUD operations have been moved to Azure Container Registry. This
    means that customers must update allow/deny rules and ports. See:
    [Required ports and addresses for AKS clusters](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#required-ports-and-addresses-for-aks-clusters)
* Preview Features
  * Fixed a VMSS cluster upgrade failure that would return: `Changing property
    'type' is not allowed.`
  * An issue where `az aks nodepool list` would return the incorrect node count
    has been resolved.
* Component Updates
  * The Azure Monitor for Container agent has been updated to the 2019-07-09 release
    * Please see the [release notes](https://github.com/Microsoft/docker-provider/tree/ci_feature_prod#07092019--).

## Release 2019-07-08

* New Features
  * Kubernetes versions 1.11.10 and 1.13.7 have been added. Customers
    are encouraged to upgrade.
    * For information on how AKS handles Kubernetes version support see:
      [Supported Kubernetes versions in Azure](https://docs.microsoft.com/en-us/azure/aks/supported-kubernetes-versions))
  * The `az aks update-credentials` command now supports Azure tenant migration of your
AKS cluster. Follow the instructions in [Choose to update or create a service principal][8] and then execute the `Update AKS cluster with new credentials` command passing in the `--tenant-id` argument.
* Behavioral Changes
  * All new clusters now have --protect-kernel-defaults enabled.
    * See: https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
* Preview Features
  * Kubernetes 1.14.3 is now available for preview users.
  * Azure availability zone support is now in public preview.
    * This feature enables customers to distribute their AKS clusters across
      availability zones providing a higher level of availability.
    * Please see [AKS previews][previews] for additional information.
  * For all previews, please see the [previews][previews] document for opt-in
    instructions and documentation links.
* Component Updates
  * aks-engine has been updated to version 0.37.5
    * https://github.com/Azure/aks-engine/releases/tag/v0.37.5
  * Azure CNI has been updated to version 1.0.22
  * Moby has been updated to 3.0.5 from 3.0.4
    * Note that this version number is Azure specific, the Moby project does not
      have official releases / release numbers.

## Release 2019-07-01

* Bug Fixes
  * Fixed an issue with `az aks update-credentials` where the command would
    not take special characters and nodes would get incorrect values.
    Note that double quote `"` , backslash `\`, ampersand `&`, and angle quotations `<>`
    are still NOT allowed to be used as password characters.
  * Fixed an issue with update-credentials where the command would not work for VMSS clusters
    with more than 10 instances.
  * AKS now has validation to check for Resource Locks when performing Scale and Upgrade operations.
  * Fixed an issue where GPU nodes could fail to install the GPU driver due to ongoing
    background apt operations.
  * Adjusted the timeout value for Service Principal update based on the number of nodes in the
    cluster, to accommodate larger clusters.
* New Features
  * AKS now supports OS disk sizes of up to 2048GiB.
  * Persistent Tags
    * Custom tags can now be passed to AKS and will persisted onto the MC infrastructure Resource Group.
      Note: They will NOT be applied to all child resources in that RG, aka VMs, VNets, disks, etc.
* Preview Features
  * Windows Node Pools
    * AKS updated Windows default image to latest windows patch release.
  * API server authorized IP ranges
    * The max number of API server authorized IP ranges has now increased to 100.
* Component Updates
  * [AKS-Engine has been updated to v0.35.6](https://github.com/Azure/aks-engine/releases/tag/v0.35.6)
    * This change includes a new AKS VHD with the Linux Kernel CVE fixes. See more:
      https://github.com/Azure/AKS/issues/
    * This new VHD also fixes broken IPv6 support for the host.


## Release 2019-06-24

* Bug Fixes
  * Fixed an issue that could result in a failed service principal update and
    AKS cluster creation.
  * Fixed an issue where deploying AKS clusters using ARM templates without a
    defined Service Principal would incorrectly pass validation.
* Preview Features
  * Azure Standard load balancer support is now in public preview.
    * This has been a long awaited feature which enables selection of the SKU
      type offered by Azure Load Balancer to be used with your AKS cluster. Please see
      [AKS previews][previews] for additional information.
  * For all previews, please see the [previews][previews] document for opt-in
    instructions and documentation links.
* Component Updates
  * The Azure Monitor for Container agent has been updated to the 2019-06-14 release
    * Please see the [release notes](https://github.com/Microsoft/docker-provider/tree/ci_feature_prod#06142019--).

## Release 2019-06-18

* Behavioral Changes
  * **Important: Change in UDR and subnet behavior**
    * When using Kubenet with a custom subnet, AKS now checks if there is an
      existing associated route table.
    * If that is the case AKS will NOT attach the kubenet RT/Routes automatically
      and they should be added manually to the existing RT.
    * If no Route Table exists AKS will automatically attach the kubenet RT/Routes.

* Preview Features
  * A bug where users could not scale VMSS based clusters after disabling the
   cluster autoscaler has been fixed.
  * A missing CRD for calico-enabled clusters (#1042) has been fixed.


## Release 2019-06-10

* Bug Fixes
  * Kubernetes taints and tolerations are now supported in all AKS regions.
    * Taints & Tolerations are preserved for current cluster nodes and
      through upgrades, however they are _not_ preserved through scale (up,
      down) operations.

* Preview Features
  * A bug that prevented cluster agent pool deletions due to VMSS creation
    failures has been fixed.
  * A bug preventing the cluster autoscaler from working with nodepool enabled
    clusters (one or more nodepools) has been fixed.
  * A bug where the NSG would not be reset as needed during a nodepool create
    request has been fixed.

* Behavioral Changes
  * AKS removed all weak CBC suite ciphers for API server. More info: https://blog.qualys.com/technology/2019/04/22/zombie-poodle-and-goldendoodle-vulnerabilities

* Component Updates
  * AKS-Engine has been updated to v0.35.4

## Release 2019-05-28

* New Features
  * AKS is now available in both China East 2 / China North 2 Azure Regions.
  * AKS is now available in South Africa North
  * The L and M series Virtual Machines are now supported

* Component Updates
  * AKS-Engine has been updated to version 0.35.3
  * CoreDNS has been upgraded from 1.2.2 to version 1.2.6

* Preview Features
  * A bug where users could not deleted an agent pool containing VMSS nodes if
    the VMSS node creation fails has been fixed.

## Release 2019-05-20

* Behavioral Changes
  * The 192.0.2.0/24 IP block is now reserved for AKS use. Clusters created in
    a VNet that overlaps with this block will fail pre-flight validation.
* Bug Fixes
  * An issue where users running old AKS clusters attempting to upgrade would
    get a failed upgrade with an Internal Server Error has been fixed.
  * An issue where Kubernetes 1.14.0 would not show in the Azure Portal or AKS
    Preview CLI with the 'Preview' or 'isPreview' tag has been resolved.
  * An issue where customers would get excessive log entries due to missing
    Heapster rbac permissions has been fixed.
    * https://github.com/Azure/AKS/issues/520
  * An issue where AKS clusters could end up with missing DNS entries resulting
    in DNS resolution errors or crashes within CoreDNS has been resolved.

* Preview Features
  * A bug where the AKS node count could be out of sync with the VMSS node count
    has been resolved.
  * There is a known issue with the cluster autoscaler preview and multiple
    agent pools. The current autoscaler in preview is not compatible with
    multiple agent pools, and could not be disabled. We have fixed the issue
    that blocked disabling the autoscaler. A fix for mutliple agent pools and
    the cluster autoscaler is in development.


## Release 2019-05-17 (Announcement)

* Window node support for AKS is now in Public Preview
  * Blog post: https://aka.ms/aks/windows
  * Support and documentation:
    * Documentation: https://aka.ms/aks/windowsdocs
    * Issues may be filed on this Github repository (https://github.com/Azure/AKS)
      or raised as a Sev C support request. Support requests and issues for
      preview features do not have an SLA / SLO and are best-effort only.
  * **Do not enable preview featured on production subscriptions or clusters.**
  * For all previews, please see the [previews][previews] document for opt-in
    instructions and documentation links.

* Bug fixes
  * An issue impacting Java workloads where pods running Java workloads would
    consume all available node resources instead of the defined pod resource
    limits defined by the user has been resolved.
    * https://bugs.openjdk.java.net/browse/JDK-8217766
    * AKS-Engine PR for fix: https://github.com/Azure/aks-engine/pull/1095

* Component Updates
  * AKS-Engine has been updates to v0.35.1

## Release 2019-05-13

* New Features
  * Shared Subnets are now supported with Azure CNI.
    * Users may bring / provide their own subnets to AKS clusters
    * Subnets are no longer restricted to a single subnet per AKS cluster, users
      may now have multiple AKS clusters on a subnet.
    * If the subnet provided to AKS has NSGs, those NSGs will be preserved and
      used.
      * **Warning**: NSGs must respect: https://aka.ms/aksegress or the
      cluster might not come up or work properly.
    * Note: Shared subnet support is not supported with VMSS (in preview)
* Bug Fixes
  * A bug that blocked Azure CNI users from setting maxPods above 110 (maximum
    of 250) and that blocked existing clusters from scaling up when the value
    was over 110 for CNI has been fixed.
  * A validation bug blocking long DNS names used by customers has been fixed.
    For restrictions on DNS/Cluster names, please see
    https://aka.ms/aks-naming-rules

## Release 2019-05-06

* New Features
  * Kubernetes Network Policies are GA
    * See https://docs.microsoft.com/en-us/azure/aks/use-network-policies
      for documentation.

* Bug Fixes
  * An issues customers reported with CoreDNS entering CrashLoopBackoff has
    been fixed. This was related to the upstream move to `klog`
    * https://github.com/coredns/coredns/pull/2529
  * An issue where AKS managed pods (within kube-system) did not have the correct
    tolerations preventing them from being scheduled when customers use
    taints/tolerations has been fixed.
  * An issue with kube-dns crashing on specific config map override scenarios
    as seen in https://github.com/Azure/acs-engine/issues/3534 has been
    resolved by updating to the latest upstream kube-dns release.
  * An issue where customers could experience longer than normal create times
    for clusters tied to a blocking wait on heapster pods has been resolved.
* Preview Features
  * New features in public preview:
    * Secure access to the API server using authorized IP address ranges
    * Locked down egress traffic
      * This feature allows users to limit / whitelist the hosts used by AKS
        clusters.
    * Multiple Node Pools
    * For all previews, please see the [previews][previews] document for opt-in
      instructions and documentation links.

## Release 2019-04-22

* Kubernetes 1.14 is now in Preview
  * Do not use this for production clusters. This version is for early adopters
    and advanced users to test and validate.
  * Accessing the Kubernetes 1.14 release requires the `aks-preview` CLI
    extension to be installed.

* New Features
  * Users are no longer forced to create / pre-provision subnets when using
    Advanced networking. Instead, if you choose advanced networking and do not
    supply a subnet, AKS will create one on your behalf.

* Bug fixes
  * An issue where AKS / the Azure CLI would ignore the `--network-plugin=azure`
    option silently and create clusters with Kubenet has been resolved.
    * Specifically, there was a bug in the cluster creation workflow where users
      would specific `--network-plugin=azure` with Azure CNI / Advanced Networking
      but miss passing in the additional options (eg '--pod-cidr, --service-cidr,
      etc). If this occured, the service would fall-back and create the cluster
      with Kubenet instead.

* Preview Features
  * Kubernetes 1.14 is now in Preview
  * An issue with Network Policy and Calico where cluster creation could
    fail/time out and pods would enter a crashloop has been fixed.
    * https://github.com/Azure/AKS/issues/905
    * Note, in order to get the fix properly applied, you should create a new
      cluster based on this release, or upgrade your existing cluster and then
      run the following clean up command after the upgrade is complete:

```
kubectl delete -f https://github.com/Azure/aks-engine/raw/master/docs/topics/calico-3.3.1-cleanup-after-upgrade.yaml
```

* Component Updates
  * Azure Monitoring for Containers has been updated to the 2019-04-23 release
    * For more information, please see: https://github.com/Microsoft/docker-provider/tree/ci_feature_prod#04232019--

## Release 2019-04-15

* Kubernetes 1.13 is GA
* **The Kubernetes 1.9.x releases are now deprecated.** All clusters
  on version 1.9 must be upgraded to a later release (1.10, 1.11, 1.12, 1.13)
  within **30 days**. Clusters still on 1.9.x after 30 days (2019-05-25)
  will no longer be supported.
  * During the deprecation period, 1.9.x will continue to appear in the available
    versions list. Once deprecation is completed 1.9 will be removed.

* (Region) North Central US is now available
* (Region) Japan West is now available

* New Features
  * Customers may now provide custom Resource Group names.
    * This means that users are no longer locked into the MC_* resource name
      group. On cluster creation you may pass in a custom RG and AKS will
      inherit that RG, permissions and attach AKS resources to the customer
      provided resource group.
    * Currently, you must pass in a new RG (resource group) must be new, and
      can not be a pre-existing RG. We are working on support for pre-existing
      RGs.
    * This change requires newly provisioned clusters, existing clusters can
      not be migrated to support this new capability. Cluster migration across
      subscriptions and RGs is not currently supported.
  *  AKS now properly associates existing route tables created by AKS when
      passing in custom VNET for Kubenet/Basic Networking. *This does not
      support User Defined / Custom routes (UDRs)*.

* Bug fixes
  * An issue where two delete operations could be issued against a cluster
    simultaneously resulting in an unknown and unrecoverable state has been
    resolved.
  * An issue where users could create a new AKS cluster and set the `maxPods`
    value too low has been resolved.
    * Users have reported cluster crashes, unavailability and other issues
      when changing this setting. As AKS is a managed service, we provide
      sidecars and pods we deploy and manage as part of the cluster. However
      users could define a maxPods value lower than the value required for the
      managed pods to run (eg 30), AKS now calculates the minimum number of
      pods via: `maxPods or maxPods * vm_count > managed add-on pods`

* Behavioral Changes
  * AKS cluster creation now properly pre-checks the assigned service CIDR
    range to block against possible conflicts with the dns-service CIDR.
    * As an example, a user could use 10.2.0.1/24 instead of 10.2.0.0/24 which
      would lead to IP conflicts. This is now validated/checked and if there is
      a conflict, a clear error is returned.
  * AKS now correctly blocks/validates users who accidentally attempt an
    upgrade to a previous release (eg downgrade).
  * AKS now validate all CRUD operations to confirm the requested action will
    not fail due to IP Address/subnet exhaustion. If a call is made that would
    exceed available addresses, the service correctly returns an error.
  * The amount of memory allocated to the Kubernetes Dashboard has been
    increased to 500Mi for customers with large numbers of nodes/jobs/objects.
  * Small VM SKUs (such as Standard F1, and A2) that do not have enough RAM to
    support the Kubernetes control plane components have been removed from the
    list of available VMs users can use when creating AKS clusters.

* Preview Features
  * A bug where Calico pods would not start after a 1.11 to 1.12 upgrade has
    been resolved.
  * When using network policies and Calico, AKS now properly uses Azure CNI for
    all routing vs defaulting to using Calico the routing plugin.
  * Calico has been updated to v3.5.0

* Component Updates
  * AKS-Engine has been updates to v0.33.4

## Release 2019-04-01

* Bug Fixes
  * Resolved an issue preventing some users from leveraging the Live Container
    Logs feature (due to a 401 unauthorized).
  * Resolved an issue where users could get "Failed to get list of supported
    orchestrators" during upgrade calls.
  * Resolved an issue where users using custom subnets/routes/networking with
    AKS where IP ranges match the cluster/service or node IPs could result in
    an inability to `exec`, get cluster logs (`kubectl get logs`) or otherwise
    pass required health checks.
  * An issue where a user running `az aks get-credentials` while a cluster is
    in creation resulting in an unclear error ('Could not find role name') has
    been resolved.


## Release 2019-04-08 (Hotfix)

This release fixes one AKS product regression and an issue identified with the
Azure Jenkins plugin.

* A regression when using ARM templates to issue AKS cluster update(s) (such as
  configuration changes) that also impacted the Azure Portal has been fixed.
  * Users do not need to perform any actions / upgrades for this fix.
* An issue when using the Azure Container Jenkins plugin with AKS has been
  mitigated.
  * This issue caused errors and failures when using the Jenkins plugin - the
    bug triggered by a new AKS API version but was related to a latent issue in
    the plugin's API detection behavior.
  * An updated Jenkins plugin has been published:
    https://github.com/jenkinsci/azure-acs-plugin/issues/16
  * https://github.com/jenkinsci/azure-acs-plugin/releases/tag/azure-acs-0.2.4

## Release 2019-04-04 - Hotfix (CVE mitigation)

* Bug fixes
  * New kubernetes versions released with multiple CVE mitigations
    * Kubernetes 1.12.7
      * https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.12.md#changelog-since-v1126
    * Kubernetes 1.11.9
      * https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.11.md#changelog-since-v1118
    * Customers should upgrade to the latest 1.11 and 1.12 releases.
      * Kubernetes versions prior to 1.11 must upgrade to 1.11/1.12 for the fix.

* Component updates
  * Updated included AKS-Engine version to 0.33.2
    * See: https://github.com/Azure/aks-engine/releases/tag/v0.33.4 for details

## Release 2019-03-29 (Hotfix)

* The following regions are now GA: South Central US, Korea Central and Korea
  South

* Bug fixes
  * Fixed an issue which prevented Kubernetes addons from being disabled.

* Behavioral Changes
  * AKS will now block subsequent PUT requests (with a status code 409 -
    Conflict) while an ongoing operation is being performed.

## Release 2019-03-21

* The Central India region is now GA

* Bug fixes
  * AKS will now begin preserving node labels & annotations users apply to
    clusters during upgrades.
    * Note: labels & annotations will not be applied to new nodes added during
      a scale up operation.
  * AKS now properly validates the Service Principal / Azure Active Directory
    (AAD) credentials
    * This prevents invalid, expired or otherwise broken credentials being
      inserted and causing cluster issues.
  * Clusters that enter a failed state due to upgrade issues will now allow
    users to re-attempt to upgrade or will throw an error message with
    instructions to the user.
  * Fixed an issue with cloud-init and the walinuxagent resulting in
    `failed state` VMs/worker nodes
  * The `tenant-id` is now correctly defaulted if not passed in for AAD enabled
    clusters.

* Behavioral Changes
  * AKS is now pre-validating MC_* resource group locks before any CRUD
    operation, avoiding the cluster enter Failed state.
  * Scale up/down calls now return a correct error ('Bad Request') when users
    delete underlying virtual machines during the scale operation.
  * Performance Improvement: caching is now set to read only for data disks
  * The Nvidia driver has been updated to 410.79 for N series cluster
    configurations
  * The default worker node disk size has been increased to 100GB
    * This resolves customer reported issues with large numbers (and large
      sizes) of Docker images triggering out of disk issues and possible
      workload eviction.
  * The Kubernetes controller manager `terminated-pod-gc-threshold` has been
    lowered to 6000 (previously 12500)
    * This will help system performance for customers running large number of
      Jobs (finished pods)
  * The Azure Monitor for Container agent has been updated to the 2019-03
    release
  * The "View Kubernetes Dashboard" has been removed from the Azure Portal
    * Note that this button did not expose/add functionality, it only linked to
      the existing instructions for using the Kubernetes dashboard found here:
      https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard

## Release 2019-03-07

* The Azure Monitor for containers Agent has been updated to 3.0.0-4 for newly
  built or upgraded clusters
* The Azure CLI now properly defaults to N-1 for Kubernetes versions, for
  example N is the current latest (1.12) release - the CLI will correctly pick
  1.11.x. When 1.13 is released, the default will move to 1.12.

* Bug Fixes:
  * If a user exceeds quota during a scale operation, the Azure CLI will now
    correctly display a "Quota exceeded" vs "deployment not found"
  * All AKS CRUD (put) operations now validate and confirm user subscriptions
    have the needed quota to perform the operation. If a user does not, an
    error is correctly shown and the operation will not take effect.
  * All AKS issued Kubernetes SSL certificates have had weak cipher support
    removed, all certificates should now pass security audits for BEAST and
    other vulnerabilities.
    * If you are using older clients that do not support TLS 1.2 you will need
      to upgrade those clients and associated SSL libraries to securely connect.
      * Note that only Kubernetes 1.10 and above support the new certificates,
        additionally existing certificates will not be updated as this would
        revoke all user access. To get the updated certificates you will need
        to create a new AKS cluster.
  * Clusters that are in the process of upgrading or in failed upgrade state
    will attempt to re-execute the upgrade or throw an obvious error message.
* The preview feature for Calico/Network Security Policies has been updated to
  repair a bug where ip-forwarding was not enabled by default.
* The `cachingmode: ReadOnly` flag was not always being correctly applied to
  the managed premium storage class, this has been resolved.


## Release 2019-03-01

* New kubernetes versions released for CVE-2019-1002100 mitigation
  * Kubernetes 1.12.6
  * Kubernetes 1.11.8
  * Customers should upgrade to the latest 1.11 and 1.12 releases.
  * Kubernetes versions prior to 1.11 must upgrade to 1.11/1.12 for the fix.
    * Announcement here: https://groups.google.com/forum/#!msg/kubernetes-announce/vmUUNkYfG9g/B9rHFrqLCAAJ
* A security bug with the Kubernetes dashboard and overly permissive service
  account access has been fixed
* The France Central region is now GA for all customers
* Bug fixes and performance improvements

## Release 2019-02-19

* Fixed a bug in cluster location/region validation has been resolved.
  * Previously, if you passed in a location/region with a trailing unicode
    non-breaking space (U+00A0) would cause failures on CRUD operations or
    cause other non-parseable characters to be displayed.
* Fixed a bug where if the dnsService IP conflicts with the apiServer IP
  address(es) creates or updates would fail after the fact.
  * Addresses are now checked to ensure no overlap or conflict at CRUD operation
    time.
* The Australia Southeast region is now GA
* Fixed a bug when using the new Service Principal rotation/update command on
  cluster nodes using the Azure CLI would fail
  * Specifically, there was a missing dependency (e.g. `jq is missing`) on the
    nodes, all new nodes should now contain the `jq` utility.

## Release 2019-02-12 - Hotfix Release (UPDATE)

At this time, all regions now have the CVE hotfix release. The simplest way to
consume it is to perform a Kubernetes version upgrade, which will cordon, drain,
and replace all nodes with a new base image that includes the patched version of
Moby. In conjunction with this release, we have enabled new patch versions for
Kubernetes 1.11 and 1.12. However, as there are no new patch versions available
for Kubernetes versions 1.9 and 1.10, customers are recommended to move forward
to a later minor release.

If that is not possible and you must remain on 1.9.x/1.10.x, you can perform
the following steps to get the patched runtime:

1. Scale *up* your existing 1.9/1.10 cluster - add an equal number of nodes to
  your existing worker count.
1. After scale-up completes, pick a single node and using the kubectl command,
  cordon the old node, drain all traffic from it, and then delete it.
1. Repeat step 2 for each worker in your cluster, until only the new nodes
  remain.

Once this is complete, all nodes should reflect the new Moby runtime version.

We apologize for the confusion, and we recognize that this process is not ideal
and we have future plans to enable an upgrade strategy that decouples system
components like the container runtime from the Kubernetes version.

Note: All newly created 1.9, 1.10, 1.11 and 1.12 clusters will have the new
Moby runtime and will not need to be upgraded to get the patch.

### Release 2019-02-12 - Hotfix Release

**Hotfix releases follow an accelerated rollout schedule - this release should
be in all regions by 12am PST 2019-02-13**

* Kubernetes 1.12.5, 1.11.7
* This release mitigates CVE-2019-5736 for Azure Kubernetes Service (see below).
  * Please note that GPU-based nodes do not support the new container runtime
    yet. We will provide another service update once a fix is available for
    those nodes.

**CVE-2019-5736 notes and mitigation**
Microsoft has built a new version of the Moby container runtime that includes
the OCI update to address this vulnerability. In order to consume the updated
container runtime release, you will need to **upgrade your Kubernetes cluster**.

Any upgrade will suffice as it will ensure that all existing nodes are removed
and replaced with new nodes that include the patched runtime. You can see the
upgrade paths/versions available to you by running the following command with
the Azure CLI:

```
az aks get-upgrades -n myClusterName -g myResourceGroup
```

To upgrade to a given version, run the following command:

```
az aks upgrade -n myClusterName -g myResourceGroup -k <new Kubernetes version>
```

You can also upgrade from the Azure portal.

When the upgrade is complete, you can verify that you are patched by running
the following command:

```
kubectl get nodes -o wide
```

If all of the nodes list **docker://3.0.4** in the Container Runtime column,
you have successfully upgraded to the new release.

## Release 2019-02-07 - Hotfix Release

This hotfix release fixes the root-cause of several bugs / regressions
introduced in the 2019-01-31 release. This release does not add new features,
functionality or other improvements.

**Hotfix releases follow an accelerated rollout schedule - this release should
be in all regions within 24-48 hours barring unforeseen issues**

* Fix for the API regression introduced by removing the Get Access Profile API
  call.
  * Note: This call is planned to be deprecated, however we will issue advance
    communications and provide the required logging/warnings on the API call to
    reflect it's deprecating status.
  * Resolves [Issue 809](https://github.com/Azure/AKS/issues/809)
* Fix for CoreDNS / kube-dns autoscaler conflict(s) leading to both running in
  the same cluster post-upgrade
  * Resolves [Issue 812](https://github.com/Azure/AKS/issues/812)
* Fix to enable the CoreDNS customization / compatibility with kube-dns config
  maps
  * Resolves [Issue 811](https://github.com/Azure/AKS/issues/811)
  * Note: customization of Kube-dns via the config map method was technically
    unsupported, however the AKS team understands the need and has created a
    compatible work around (formatting of the customizations has changed
    however). Please see the example/notes below for usage.

### Using the new CoreDNS configuration for DNS configuration.

With kube-dns, there was an undocumented feature where it supported two config
maps allowing users to perform DNS overrides/stub domains, and other
customizations. With the conversion to CoreDNS, this functionality was lost -
CoreDNS only supports a single config map. With the hotfix above, AKS now has a
work around to meet the same level of customization.

You can see the pre-CoreDNS conversion customization instructions [here][7]

Here is the equivalent ConfigMap for CoreDNS:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  azurestack.server: |
    azurestack.local:53 {
        errors
        cache 30
        proxy . 172.16.0.4
    }
```

After create the config map, you will need to delete the CoreDNS deployment to
force-load the new config.

```
kubectl -n kube-system delete po -l k8s-app=kube-dns
```


## Release 2019-01-31

* [Kubernetes 1.12.4 GA Release][1]
  * With the release of 1.12.4 *Kubernetes 1.8 support has been removed*, you
    will need to upgrade to at least 1.9.x
* CoreDNS support GA release
  * Conversion from kube-dns to CoreDNS completed, CoreDNS is the default for
    all new 1.12.4+ AKS clusters.
  * If you are using configmaps or other tools for kube-dns modifications, you
    will need to be adjust them to be CoreDNS compatible.
    * The CoreDNS add-on is set to `reconcile` which means modifications to the
      deployments will be discarded.
    * We have identified two issues with this release that will be resolved in
      a hot fix beginning rollout this week:
      * https://github.com/Azure/AKS/issues/811 (kube-dns config map not
        compatible with CoreDNS)
      * https://github.com/Azure/AKS/issues/812 (kube-dns/coreDNS autoscaler
        conflicts)
* Kube-dns (pre 1.12) / CoreDNS (1.12+) autoscaler(s) are enabled by default,
  this should resolve the DNS timeout and other issues related to DNS queries
  overloading kube-dns.
  * In order to get the dns-autoscaler, you must perform an **AKS cluster
    upgrade** to a later supported release (clusters prior to 1.12 will
    continue to get kube-dns, with kube-dns autoscale)
* Users may now self update/rotate Security Principal credentials using the
  [Azure CLI][6]
* Additional non-user facing stability and reliability service enhancements
* **New Features in Preview**
  * **Note**: Features in preview are considered beta/non-production ready and
    unsupported. Please do not enable these features on production AKS clusters.
  * [Cluster Autoscaler / Virtual machine Scale Sets][2]
  * [Kubernetes Audit Log][3]
  * Network Policies/Network Security Policies
    * This means you can now use `calico` as a valid entry in addition to
      `azure` when creating clusters using Advanced Networking
    * There is a known issue when using Network Policies/calico that prevents
      `exec` into the cluster containers which will be fixed in the next release
  * For all product / feature previews including related projects, see
    [this document][5].

[1]: https://docs.microsoft.com/azure/aks/supported-kubernetes-versions
[2]: https://docs.microsoft.com/azure/aks/cluster-autoscaler#create-an-aks-cluster-and-enable-the-cluster-autoscaler
[3]: https://github.com/Azure/AKS/blob/master/previews.md#kubernetes-audit-log
[5]: https://github.com/Azure/AKS/blob/master/previews.md
[6]: https://docs.microsoft.com/azure/aks/update-credentials
[7]: https://www.danielstechblog.io/using-custom-dns-server-for-domain-specific-name-resolution-with-azure-kubernetes-service/
[8]: https://docs.microsoft.com/en-us/azure/aks/update-credentials

[previews]: https://github.com/Azure/AKS/blob/master/previews.md
