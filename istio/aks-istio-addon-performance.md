# **AKS Istio Add-On Performance**

The Istio-based service mesh add-on is logically split into the control plane (Istiod), which manages and configures the Envoy proxies, and the data plane, which is the set of Envoy proxies deployed as sidecars. This document provides an analysis of the add-on’s control and data plane across the most used network plugins in Azure Kubernetes Service (AKS): Azure CNI, Cilium, Kubenet, and Azure CNI Overlay.

## Control Plane Performance
Istiod’s CPU and memory requirements correlate with the rate of deployment and configuration changes as well as the number of proxies connected[<sup>\[1\]</sup>](#1.-control-plane-performance). Therefore, to determine Istiod’s performance in `v1.17`, a single Istiod instance with the default settings: `2 vCPU` and `2 GB` memory is used with horizontal pod autoscaling disabled. The two scenarios tested were:

- Scenario One
  - Examines the impact of churning on Istiod. To reduce variables, only one service is used for all sidecars. 
- Scenario Two
  - Focuses on determining the maximum sidecars Istiod can manage (sidecar capacity) with 1,000 services and each service has `N` sidecars, totaling the overall maximum.

### **Scenario One**
The ClusterLoader2 framework[<sup>\[3\]</sup>](#3.-clusterloader2) was used to determine the maximum number of sidecars Istiod can manage when there is sidecar churning. The churn percent is defined as the percent of sidecars churned down/up during the test. For example, 50% churn for 10,000 sidecars would mean that 5,000 sidecars were churned down then 5,000 sidecars were churned up. The churn percents tested were determined from the typical churn percentage during deployment rollouts (`maxUnavailable`). The churn rate was calculated by determining the total number of sidecars churned (up and down) over the actual time taken to complete the churning process.

#### **Sidecar Capacity and Istiod CPU and Memory**

<table width="654">
<tbody><tr><td colspan="5" width="326"><strong>Azure CNI</strong></td><td colspan="5" width="328"><strong>Cilium</strong></td></tr>
<tr><td rowspan="2" width="50">Churn (%)</td><td rowspan="2" width="96">Churn Rate (sidecars/sec)</td><td rowspan="2" width="67">Sidecar Capacity</td><td colspan="2" width="113">Istiod</td><td rowspan="2" width="48">Churn (%)</td><td rowspan="2" width="96">Churn Rate (sidecars/sec)</td><td rowspan="2" width="67">Sidecar Capacity</td><td colspan="2" width="116">Istiod</td></tr>
<tr><td width="65">Memory (GB)</td><td width="48">vCPU</td><td width="61">Memory (GB)</td><td width="56">vCPU</td></tr>
<tr><td width="50">0</td><td width="96">----</td><td width="67">15,000</td><td width="65">19</td><td width="48">5</td><td width="48">0</td><td width="96">----</td><td width="67">25,000</td><td width="61">28</td><td width="56">4</td></tr>
<tr><td width="50">25</td><td width="96">41.7</td><td width="67">15,000</td><td width="65">21</td><td width="48">14</td><td width="48">25</td><td width="96">31.3</td><td width="67">15,000</td><td width="61">20</td><td width="56">9</td></tr>
<tr><td width="50">50</td><td width="96">62.5</td><td width="67">15,000</td><td width="65">24</td><td width="48">11</td><td width="48">50</td><td width="96">41.7</td><td width="67">15,000</td><td width="61">24</td><td width="56">12</td></tr>
<tr><td colspan="5" width="326"><strong>Kubenet</strong></td><td colspan="5" width="328"><strong>Azure CNI Overlay</strong></td></tr><tr><td rowspan="2" width="50">Churn (%)</td><td rowspan="2" width="96">Churn Rate (sidecars/sec)</td><td rowspan="2" width="67">Sidecar Capacity</td><td colspan="2" width="113">Istiod</td><td rowspan="2" width="48">Churn (%)</td><td rowspan="2" width="96">Churn Rate (sidecars/sec)</td><td rowspan="2" width="67">Sidecar Capacity</td><td colspan="2" width="116">Istiod</td></tr>
<tr><td width="65">Memory (GB)</td><td width="48">vCPU</td><td width="61">Memory (GB)</td><td width="56">vCPU</td></tr>
<tr><td width="50">0</td><td width="96">----</td><td width="67">30,000</td><td width="65">34</td><td width="48">5</td><td width="48">0</td><td width="96">----</td><td width="67">40,000</td><td width="61">48</td><td width="56">14</td></tr>
<tr><td width="50">25</td><td width="96">41.7</td><td width="67">25,000</td><td width="65">37</td><td width="48">13</td><td width="48">25</td><td width="96">48.6</td><td width="67">35,000</td><td width="61">47</td><td width="56">14</td></tr>
<tr><td width="50">50</td><td width="96">59.5</td><td width="67">25,000</td><td width="65">43</td><td width="48">13</td><td width="48">50</td><td width="96">71.4</td><td width="67">30,000</td><td width="61">51</td><td width="56">14</td></tr>
</tbody>
</table>

### **Scenario Two**
The ClusterLoader2 framework[<sup>\[3\]</sup>](#3.-ClusterLoader2) was used to determine the maximum number of sidecars Istiod can manage with 1,000 services. Each service had `N` sidecars contributing to the overall maximum sidecar count. The API Server resource usage is measured to determine if there is any significant stress from the add-on.

#### **Sidecar Capacity**
|Azure CNI|Cilium|Kubenet|Azure CNI Overlay|
| :-: | :-: | :-: | :-: |
|15,000|15,000|15,000|17,000|

#### **CPU and Memory**
<table><tr><th colspan="2"></th><th>Azure CNI</th><th>Cilium</th><th>Kubenet</th><th>Azure CNI Overlay</th></tr>
<tr><td rowspan="2">vCPU</td><td>API Server</td><td>6</td><td>1</td><td>4</td><td>3</td></tr>
<tr><td>Istiod</td><td>15</td><td>16</td><td>16</td><td>16</td></tr>
<tr><td rowspan="2">Memory (GB)</td><td>API Server</td><td>25</td><td>6</td><td>9</td><td>6</td></tr>
<tr><td>Istiod</td><td>56</td><td>37</td><td>47</td><td>49</td></tr>
</table>

## Data Plane Performance
Sidecar performance is impacted by a variety of factors: request size, number of proxy worker threads, number of client connections etc.[<sup>\[2\]</sup>](#2.-data-plane-performance) Additionally, when the add-on is enabled, a request now must traverse the client-side proxy, then the server-side proxy. Therefore, latency and resource consumption are measured to determine the data plane performance.

Fortio was used to create the load[<sup>\[4\]</sup>](#4.-Fortio). The test was conducted with the Istio benchmark repository[<sup>\[5\]</sup>](#5.-Istio-Benchmark) that was modified for use with the add-on. The test involved a 1 kB payload, 16 client connections, 2 proxy workers, utilized `http/1.1` protocol and mutual TLS enabled at various queries per second (QPS). 

#### **CPU and Memory**
The sidecar proxy resource consumption across the various AKS network plugins for 16 client connections and 1000 QPS is `60 MB` of memory and `0.3 vCPU`.

|Sidecar|Azure CNI|Cilium|Kubenet|Azure CNI Overlay|
| :-: | :-: | :-: | :-: | :-: |
|CPU (vCPU)|.31|.31|.32|.25|
|Memory (MB)|62|62|58|60|

#### **Latency**
The sidecar Envoy proxy collects raw telemetry data after responding to a client, which does not directly affect the request's total processing time. However, this process delays the start of handling the next request, contributing to queue wait times and influencing average and tail latencies. Depending on the traffic pattern, the actual tail latency varies. 

The following analysis compares the impact of adding sidecar proxies to the data path for the most used AKS network plugins. It includes both P90 and P99 latency metrics, showing the latency most users would experience as well as providing insights into the worst-case latency that 99% of users would encounter. <br>

<img src="latency-graphs/P90-Latency.png" width="50%"/>
<img src="latency-graphs/P99-Latency.png" width="50%"/>

## Service Entry
Istio features a custom resource definition known as a ServiceEntry that enables adding additional services into the Istio’s internal service registry, this allows services already in the mesh to route or access the services specified[<sup>\[6\]</sup>](#6.-ServiceEntry). However, the configuration of multiple ServiceEntries with the `resolution` field set to DNS can cause a heavy load on DNS servers, the following can help reduce the load[<sup>\[7\]</sup>](#7.-Understanding-DNS):

- Switch to resolution: NONE to avoid proxy DNS lookups entirely. Suitable for most use cases.
- Increase TTL (Time To Live) if you control the domains being resolved.
- Limit the ServiceEntry scope with `exportTo` or a sidecar if it is only needed by a few workloads.


## Citations
#### [1. Control Plane Performance](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/#control-plane-performance)
#### [2. Data Plane Performance](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/#data-plane-performance)
#### [3. ClusterLoader2](https://github.com/kubernetes/perf-tests/tree/master/clusterloader2#clusterloader)
#### [4. Fortio](https://fortio.org/)
#### [5. Istio Benchmark](https://github.com/istio/tools/tree/master/perf/benchmark#istio-performance-benchmarking)
#### [6. ServiceEntry](https://istio.io/latest/docs/reference/config/networking/service-entry/)
#### [7. Understanding DNS](https://preliminary.istio.io/latest/docs/ops/configuration/traffic-management/dns/#proxy-dns-resolution)
