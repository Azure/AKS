# Azure Kubernetes Service Changelog

## Release 2019-04-22

*This release is rolling out to all regions*

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
  * AKS now properly associates the existing route tables when passing in
    custom VNET for Kubenet/Basic Networking.

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
