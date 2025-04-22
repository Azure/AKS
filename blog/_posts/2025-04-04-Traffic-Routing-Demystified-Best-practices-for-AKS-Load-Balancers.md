---
title: "Traffic Routing Demystified - Best practices for AKS Load Balancers"
description: "Optimize your Traffic Routing in AKS with best practices, including externalTrafficPolicy. Learn how to preserve client source IPs, implement graceful pod termination, and ensure even traffic distribution across nodes for reliable production workloads."
date: 2025-04-08
authors:
  - Mitch Shao
  - Vaibhav Arora
categories: general
tags:
  - traffic-management
  - networking
  - best practices
  - load balancers
---

# Traffic Routing Demystified - Best practices for AKS Load Balancers

Managing external traffic in Kubernetes clusters can be a complex task, especially when striving to maintain service reliability, optimize performance, and ensure seamless user experiences. With the increasing adoption of Kubernetes in production environments, understanding and implementing best practices for external traffic management when using the Azure Load Balancer has become essential.

In this blog, we delve into the intricacies of Kubernetes’ `externalTrafficPolicy=Local` setting and explore strategies to gracefully handle pod shutdowns, rolling updates, and pod distribution. By following these best practices, you can enhance the resilience and reliability of your services while optimizing resource utilization across your AKS clusters.

## `externalTrafficPolicy`: Cluster vs. Local

**What does `externalTrafficPolicy` do?** In short, it influences how a cloud load balancer directs incoming traffic to Kubernetes nodes and how that traffic may hop between nodes to reach pods:

- **Cluster Mode (default) (`externalTrafficPolicy=Cluster`)**:
    This is default mode for Kubernetes Services and provides a simplified approach to traffic distribution across all nodes in the cluster. While it does not preserve the client source IP, it offers several benefits for certain workloads:

    - **Simplified Traffic Distribution**: Ensures even distribution of incoming traffic across all nodes in the cluster, regardless of pod placement.
    - **Reduced Risk of Node Overload**: Balances traffic across all nodes, minimizing the chance of overloading specific nodes.
    - **Ease of Configuration**: Requires no additional configuration for health checks or pod distribution.
    - **Resilience During Pod Failures**: Traffic is forwarded to healthy pods on other nodes, ensuring service availability even if some pods are unavailable.

    However, because this mode distributes traffic to all nodes regardless of them hosting the service pod, it can add latency and more failure modes due to extra hops between nodes (forwarded by `kube-proxy`). This is especially detrimental during events like node upgrades since if a node is taken down, 1/N (N stands for node count) traffic could experience disruptions. So, if you update your nodes weekly, this would disrupt your connections on a weekly basis.

- **Local Mode (`externalTrafficPolicy=Local`)**:
    In this mode, external traffic is directed only to nodes that host healthy pods for the specified service. The traffic is routed exclusively to the pods residing on the same node where it is received (avoiding cross-node hops). This approach ensures:
    - **Localized Impact of Node Downtime**: During operations like upgrades, reboots and unexpected failures on a node, a portion of external traffic is only affected if the downed node is running a service pod. The traffic to the pods on different nodes remains unaffected.
    - **Preservation of Client Source IP**: The client’s original IP is maintained, which is crucial for security, logging, and analytics.
    - **Targeted Health Checking**: Local mode uses a dedicated `healthCheckNodePort`, ensuring that external load balancers send traffic only to nodes with healthy pods.

    However, apart from these benefits, this approach requires careful consideration of pod distribution across nodes to avoid uneven traffic loads. If one node hosts multiple pods while another node hosts only one, the node with one pod will receive roughly the same share of incoming connections as the node with multiple pods.

By understanding the operational differences between these two modes, you can make an informed decision based on your application’s requirements for traffic routing, source IP preservation, and load balancing.

## How `externalTrafficPolicy=Local` Works

As detailed above, `externalTrafficPolicy=Local` routes traffic directly to nodes hosting service pods and which meet the health check requirements. Below is an illustration of how this policy works in practice:
![How `externalTrafficPolicy=Local` Works](./AKS/blog/assets/images/howexternaltrafficpolicyworks.png)

Let's look into how each of the following components work with the Local Mode:
When you set a Service's external traffic policy to Local in AKS, you'll see an additional field in the Service description: **HealthCheck NodePort**​. This is a dedicated NodePort (e.g. port number in the 30000+ range) that Azure's Standard Load Balancer uses to verify which nodes have healthy pods for this Service.

- **Health Probe on Each Node:** Azure automatically configures a health probe on the load balancer that targets the `HealthCheckNodePort` across all nodes in the LB's backend pool. Kubernetes ensures that this port only returns a successful response on nodes that are running at least one *ready* pod for the Service. Nodes with no pods for that Service will fail the health check.

- **Load Balancer Back-end Pool:** With `externalTrafficPolicy=Local`, all cluster nodes are listed in the LB's back-end pool. But due to the health probes, nodes without a Service pod are marked **unhealthy** and won't receive traffic​. Only nodes with healthy pods respond to the probe and remain in rotation. By contrast, in `Cluster` mode, every node responds (since even if it has no pod, kube-proxy will forward the traffic), so the LB sees all nodes as healthy​. The `kube-proxy` component manages this port and ensures that it only responds as healthy if the node hosts at least one healthy pod for the service.

 **IPTables Rules**: IPTables rules are configured to only forward incoming traffic from the Azure Load Balancer (ALB) directly to pods running on the same node. These rules ensure that traffic is never forwarded to other nodes. This localized traffic routing reduces latency and ensures that external connections continue to be served even during node update operations.

By combining these mechanisms, `externalTrafficPolicy=Local` provides a robust way to manage external traffic while maintaining source IP visibility and ensuring traffic is routed to healthy pods only.

## Best Practices to gracefully close existing connections and shut service pods

Gracefully handling pod shutdowns is critical to maintaining service reliability and avoiding disruptions, especially in scenarios involving HTTP keep-alive connections or long-lived client sessions. Without a graceful shutdown process, external customers could see errors like - `connection refused` and `connection reset by peer` during node related events.  
Below are detailed best practices for how pods can handle Kubernetes initiated termination requests (eg: pod evictions or a scale down) to ensure a smooth shutdown process.

### Gracefully Closing Existing Connections

When a pod is shutting down (receiving the `TERM` signal), it is essential to ensure that existing client connections are closed properly to avoid abrupt disconnections or errors.

- **For HTTP/1.1 Connections**:
    The server should include a `Connection: close` header in its response for all active and new incoming requests. This informs clients not to reuse the connection and allows idle connections to be closed gracefully.
    **Use Case**: Applications serving REST APIs or web traffic where clients rely on persistent connections for performance optimization.

> **Note**: In HTTP/1.1, there is a potential race condition where the server might close an idle connection at the same time the client sends a new request. In such cases, the client must handle this scenario by retrying the request on a new connection.

- **For HTTP/2 Connections**:
    The server should send a `GOAWAY` frame to notify clients that the connection is being closed. This allows clients to gracefully terminate the connection and retry requests on a new connection if necessary.
    **Use Case**: Applications using gRPC or HTTP/2 for high-performance communication between services or with external clients.

### Preventing New Connections to an Unhealthy Pod when using externalTrafficPolicy=Local
To avoid routing new requests to a pod that is in the process of shutting down, it is important to manage its health status effectively. The below image shows the timeline for a pod receiving a `TERM` signal and gracefully shutting down without impact on external traffic:

![Preventing New Requests to Unhealthy Pods](./AKS/blog/assets/images/preventingnewrequeststoanunhealthypod.png)

- **Immediate Health Check Response**:
    As soon as a pod is marked for deletion, its `healthCheckNodePort` should start returning a 500 error. This signals to external load balancers that the pod is no longer healthy and should not receive new traffic.

- **Load Balancer Probe Delay**:
    External load balancers will take a few seconds (upto 10 sec) to detect the unhealthy status of a pod. During this time, the pod might still receive new connections.

To ensure your pods follow a similar timeline to gracefully shutdown, make sure to assess the following:

1. **Delay Termination**:
     After receiving the `TERM` signal, we recommend your application wait for at least 10 seconds before proceeding with shutdown tasks (to address the Load balancer probe delay). This can be achieved using a `preStop` hook in Kubernetes.

    > **Note**: When using annotations `service.beta.kubernetes.io/azure-load-balancer-health-probe-interval` and/or `service.beta.kubernetes.io/azure-load-balancer-health-probe-num-of-probe`, consider changing the wait time to cover the annotation's needs (see [documentation](https://cloud-provider-azure.sigs.k8s.io/topics/loadbalancer/))

2. **Announce Readiness as `false`**:
     The application should update its readiness probe to indicate it is no longer ready to serve traffic after the above delay has completed. This allows Kubernetes to stop routing new connections to the pod after the load balancer removes it from the list of active pods.

3. **Gracefully Close Existing Connections**:
     The application should close all active connections, ensuring that no in-flight requests are dropped.

4. **Exit the Process**:
     Once all shutdown tasks are complete, the application should terminate its process cleanly.

By implementing these best practices, you can minimize disruptions during pod shutdowns, maintain a seamless user experience, and ensure the reliability of your services in production environments.

## Best Practices for Rolling Updates and Pod Rotation
![Pod Rotation Timeline](./AKS/blog/assets/images/podrotationbestpractices.png)

While the above works when a pod is being taken down in isolation, it does not cover cases like upgrades and rolling restarts which require coordination between the time the pod goes down and a new one comes up, ready to serve traffic. To optimize pod rotation, add the following best practice to your deployment:

- **Set `minReadySeconds`**:
    Configure the `minReadySeconds` parameter in your deployment (we recommend around 10 sec) to introduce a delay before Kubernetes is able to mark the pod as "available" (i.e the pod has been ready long enough that the rolling upgrade can move to the next pod - making it different from the "ready" state which implies the application is ready to recieve new connections). This buffer gives the load balancer enough time to register the new pod and start routing traffic to it, while also preventing Kubernetes from deleting the old pod prematurely.

By implementing this strategy, you can achieve smoother rolling updates and maintain a consistent user experience during application changes.

## Pod Distribution Best Practices

Achieving an even distribution of pods across nodes is important for load balancing and resource utilization, especially for pods receiving external traffic via `externalTrafficPolicy=Local`. The diagram below demonstrates an example of uneven pod distribution which leads to imbalanced traffic across pods:

![Pod Distribution](./AKS/blog/assets/images/poddistribution.png)

In this situation, even though the load balancer divides the traffic evenly between nodes, the pods on the node with 2 replicas serve 25% of the traffic each, while the pod in the single replica node serves the full 50% of the total traffic.

Below are some best practices you can follow to evenly distribute pods across your nodes based on your workload needs:
1. **Use Pod Anti-Affinity**:
   - Ensures pods with the same label are not scheduled on the same node.
   - Requires more nodes than pods, including surge pods during evictions or deployments.

2. **Use Topology Spread Constraints**:
   - Distributes pods as evenly as possible (best effort) across available nodes and zones (specified with the topologyKey).
   > **Note**: If your application requires strict spreading of pods (i.e., your ideal behavior is to leave a pod in pending if spread is not possible), you can set the `whenUnsatisfiable` to `DoNotSchedule`

3. **Use MatchLabelKeys**:
   - Provides fine-grained control over pod scheduling decisions.
   - Ensures pods from different deployment versions do not overlap on the same nodes.

Further Implementation details for these best practices can be found in AKS documentation
- [Deployment and Cluster Reliability Best Practices for AKS](https://learn.microsoft.com/en-us/azure/aks/best-practices-app-cluster-reliability)

## Conclusion
To conclude, while `externalTrafficPolicy=Local` is a powerful option for optimizing traffic routing in AKS, it also requires careful planning of your pod lifecycle. With a professional, proactive approach to how your services handle start-up and shutdown, you can reap the benefits of Local traffic policy -- getting client IP transparency and efficient routing -- without sacrificing reliability during deployments or scaling events. Kubernetes gives us the knobs; it's up to us as SREs and engineers to turn them correctly for our particular workloads. Happy load balancing!


## Additional Resources
- [Deployment and Cluster Reliability Best Practices for AKS](https://learn.microsoft.com/en-us/azure/aks/best-practices-app-cluster-reliability)
- [YouTube: Kubernetes ExternalTrafficPolicy Explained](https://mmistakes.github.io/minimal-mistakes/docs/helpers/#youtube)