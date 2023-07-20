On July 12th 2023, the Envoy project's security team announced a [HIGH CVE](https://github.com/envoyproxy/envoy/security/advisories/GHSA-jfxv-29pc-x22r) (7.5 CVSS scale) for the Envoy proxy that is deployed as a sidecar as part of the Open Service Mesh and Istio AKS addons. If exploited, this vulnerability could lead to a denial-of-service (DoS) attack via memory exhaustion when the Envoy sidecar communicates with an untrusted, malicious upstream server. 

Who is at risk?
All AKS clusters with the OSM or Istio addosn enabled and sidecars injected in their applications

Mitigation Steps?
The AKS team is rolling out patched Envoy versions to all supported AKS clusters (i.e. versions 1.24 and higher) using the OSM or Istio addons. These updates are expected to be rolled out to all regions in 10 days (July 30th). If you're using the OSM addon, you can use the `get-osm-envoy-version.sh` script in this directory to check your injected Envoy version (requires `jq`). If the image tag is v1.26.3 or v1.25.8, you have the patch and you are not at risk. If you are using the Istio addon, you can use the `get-istio-versio.sh` script in this directory to check your Istio version (also requires `jq`). If the image tag is v1.17.4, then you have the patch and are not at risk.

Am I required to take any action?
Once your cluster has the patch, you must restart all sidecar injected applications in order to replace the vulnerable Envoy sidecars with patched ones. This applies for both the OSM and Istio addons. If your AKS version is [out of support](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions), you will NOT receive a new version of either addon containing the security patch. We strongly recommend you upgrade in order to receive support and security patches.
