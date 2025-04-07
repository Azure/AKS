---
title: "Optimizing Load Balancer Traffic Routing with `externalTrafficPolicy=Local` in AKS"
description: "Recapping some of the recent announcements and improvements in AKS observability experience."
date: 2025-03-28
authors: 
  - Mitch Shao
  - Vaibhav Arora
categories: general
tags:
  - traffic-management
  - networking
---

# Optimizing Load Balancer Traffic Routing with `externalTrafficPolicy=Local` in AKS

Managing external traffic in Kubernetes clusters can be a complex task, especially when striving to maintain service reliability, optimize performance, and ensure seamless user experiences. With the increasing adoption of Kubernetes in production environments, understanding and implementing best practices for external traffic management when using the Azure Load Balancer has become essential.

In this blog, we delve into the intricacies of Kubernetes’ `externalTrafficPolicy=Local` setting and explore strategies to gracefully handle pod shutdowns, rolling updates, and pod distribution. By following these best practices, you can enhance the resilience and reliability of your services while optimizing resource utilization across your AKS clusters.

## Comparing `externalTrafficPolicy=Local` and `externalTrafficPolicy=Cluster`

The choice between `externalTrafficPolicy=Local` and `externalTrafficPolicy=Cluster` significantly impacts how external traffic is routed within a Kubernetes cluster. Below is a detailed comparison of these two modes:

- **Local Mode (`externalTrafficPolicy=Local`)**:  
    In this mode, external traffic is directed only to nodes that host healthy pods for the specified service. The traffic is routed exclusively to the pods residing on the same node where it is received. This approach ensures that the client’s original source IP is preserved, which is critical for use cases involving security, logging, and analytics. However, it requires careful consideration of pod distribution across nodes to avoid uneven traffic loads.

- **Cluster Mode (`externalTrafficPolicy=Cluster`)**:  
    When this mode is enabled, all nodes in the cluster are included behind the Azure Load Balancer (ALB), regardless of whether they host any pods for the service. Incoming external traffic is distributed evenly across all nodes in the cluster. Each node then forwards the traffic internally to the available pods, which may reside on other nodes. While this mode simplifies traffic distribution and reduces the risk of uneven load, it does not preserve the client’s original source IP, as the traffic is routed through intermediate nodes.

By understanding the operational differences between these two modes, you can make an informed decision based on your application’s requirements for traffic routing, source IP preservation, and load balancing.

### Benefits of Local Mode

- **Localized Impact of Node Downtime**: Traffic is affected only if the downed node is running a service pod, impacting that pod’s share of the traffic.
- **Preservation of Client Source IP**: The client’s original IP is maintained, which is crucial for security, logging, and analytics.
- **Targeted Health Checking**: Local mode uses a dedicated `healthCheckNodePort`, ensuring that external load balancers send traffic only to nodes with healthy pods.

## How Local ExternalTrafficPolicy Works
** Insert IMAGE HERE **
### How Local ExternalTrafficPolicy Works with HealthCheckNodePort and IPTables Rules

When `externalTrafficPolicy=Local` is enabled, the Service ensures that external traffic is routed only to nodes hosting healthy pods for the service. This is achieved through the following mechanisms:

1. **HealthCheckNodePort**:
    - A dedicated `healthCheckNodePort` is exposed on each node, allowing external load balancers to probe the health of the node.
    - The `kube-proxy` component manages this port and ensures that it only responds as healthy if the node hosts at least one healthy pod for the service.

2. **IPTables Rules**:
    - IPTables rules are configured to forward incoming traffic from the Azure Load Balancer (ALB) directly to pods running on the same node.
    - These rules ensure that traffic is not forwarded to other nodes, preserving the original client source IP.
    - This localized traffic routing reduces latency and ensures that only healthy pods receive traffic.

By combining these mechanisms, `externalTrafficPolicy=Local` provides a robust way to manage external traffic while maintaining source IP visibility and ensuring traffic is routed to healthy pods only.

## Best Practices for Graceful Pod Shutdown

Gracefully handling pod shutdowns is critical to maintaining service reliability and avoiding disruptions, especially in scenarios involving HTTP keep-alive connections or long-lived client sessions. Below are detailed best practices and their use cases to ensure a smooth shutdown process.

### Gracefully Closing Existing Connections

When a pod is shutting down, it is essential to ensure that existing client connections are closed properly to avoid abrupt disconnections or errors.

- **For HTTP/1.1 Connections**:  
    The server should include a `Connection: close` header in its response for all active and new incoming requests. This informs clients not to reuse the connection and allows idle connections to be closed gracefully.  
    **Use Case**: Applications serving REST APIs or web traffic where clients rely on persistent connections for performance optimization.  

    > **Note**: In HTTP/1.1, there is a potential race condition where the server might close an idle connection at the same time the client sends a new request. In such cases, the client must handle this scenario by retrying the request on a new connection.

- **For HTTP/2 Connections**:  
    The server should send a `GOAWAY` frame to notify clients that the connection is being closed. This allows clients to gracefully terminate the connection and retry requests on a new connection if necessary.  
    **Use Case**: Applications using gRPC or HTTP/2 for high-performance communication between services or with external clients.

### Preventing New Requests to an Unhealthy Pod
** INSERT IMAGE HERE **
To avoid routing new requests to a pod that is in the process of shutting down, it is important to manage its health status effectively.

- **Immediate Health Check Response**:  
    As soon as a pod is marked for deletion, its `healthCheckNodePort` should start returning a 500 error. This signals to external load balancers that the pod is no longer healthy and should not receive new traffic.  
 
    ** how do customres set this up??? **

- **Load Balancer Probe Delay**:  
    External load balancers may take a few seconds to detect the unhealthy status of a pod. During this time, the pod might still receive traffic.  

    ** what can customers do about this?? ** 

- **Coordinated Termination**:  
    The application should wait for at least 10 seconds after receiving the `TERM` signal before marking itself as unhealthy. This delay ensures that the load balancer has sufficient time to detect the pod’s unhealthiness and remove it from the active pool. If annotations service.beta.kubernetes.io/azure-load-balancer-health-probe-interval and/or service.beta.kubernetes.io/azure-load-balancer-health-probe-num-of-probe are being used on the Service (see [documentation](https://cloud-provider-azure.sigs.k8s.io/topics/loadbalancer/)), different timings should be used. 
    **Use Case**: Stateful applications or services with high traffic volumes where abrupt termination could lead to data loss or client errors.

    To ensure a smooth shutdown process, applications should follow these steps:

    1. **Delay Termination**:  
     After receiving the `TERM` signal, the application should wait for at least 10 seconds before proceeding with shutdown tasks. This can be achieved using a `preStop` hook in Kubernetes.  
     **Use Case**: Applications with complex teardown processes, such as closing database connections or flushing logs.

    2. **Announce Readiness as `false`**:  
     The application should update its readiness probe to indicate it is no longer ready to serve traffic. This allows Kubernetes to stop routing new requests to the pod.  
     **Use Case**: Microservices architectures where readiness probes are used to manage traffic routing.

    3. **Gracefully Close Existing Connections**:  
     The application should close all active connections, ensuring that no in-flight requests are dropped.  
     **Use Case**: APIs or services handling long-running requests, such as file uploads or streaming data.

    4. **Exit the Process**:  
     Once all shutdown tasks are complete, the application should terminate its process cleanly.  
     **Use Case**: Any application where clean termination is required to avoid resource leaks or inconsistent states.

By implementing these best practices, you can minimize disruptions during pod shutdowns, maintain a seamless user experience, and ensure the reliability of your services in production environments.

## Best Practices for Rolling Updates and Pod Rotation

Ensuring a seamless transition during application updates or scaling operations is critical for maintaining service reliability. Follow these best practices to optimize pod rotation:

- **Set `minReadySeconds`**:  
    Configure the `minReadySeconds` parameter in your deployment to introduce a delay before Kubernetes is able to mark the pod as "available". This buffer gives the load balancer enough time to register the new pod and start routing traffic to it, while also preventing Kubernetes from deleting the old pod prematurely.

By implementing this strategy, you can achieve smoother rolling updates and maintain a consistent user experience during application changes.

## Pod Distribution Best Practices

Achieving an even distribution of pods across nodes is important for load balancing and resource utilization, especially for pods receiving external traffic via `externalTrafficPolicy=Local`.

### Example of Uneven Pod Distribution

- The Azure Load Balancer splits traffic evenly between two nodes, with each receiving 50% of the overall traffic.
- If one node hosts two pods, each pod gets 25% of the traffic, while the other node with one pod receives the full 50%.

### Approaches for Even Pod Distribution

1. **Use Pod Anti-Affinity**:
   - Ensures pods with the same label are not scheduled on the same node.
   - Requires more nodes than pods, including surge pods during evictions or deployments.

2. **Use Topology Spread Constraints**:
   - Distributes pods as evenly as possible across available nodes.
   - Note: This is a best-effort mechanism and may not guarantee exact distribution.

3. **Use MatchLabelKeys**:
   - Provides fine-grained control over pod scheduling decisions.
   - Ensures pods from different deployment versions do not overlap on the same nodes.

## Conclusion

Implementing `externalTrafficPolicy=Local` in AKS provides a robust framework for managing external traffic while preserving critical attributes like the client’s source IP. This configuration ensures that traffic is routed exclusively to healthy pods on the same node, reducing latency and enhancing reliability. By adhering to best practices such as coordinated termination, graceful pod shutdown, and controlled rolling updates, you can minimize service disruptions and maintain a seamless user experience. Furthermore, leveraging strategies like Pod Anti-Affinity and Topology Spread Constraints helps achieve an even distribution of pods across nodes, optimizing resource utilization and balancing traffic loads. These approaches collectively enable you to build a resilient, high-performing AKS environment capable of handling production-grade workloads with confidence.

## Additional Resources

- [YouTube: Kubernetes ExternalTrafficPolicy Explained](https://mmistakes.github.io/minimal-mistakes/docs/helpers/#youtube)
- ![Example of Pod Distribution](./AKS/blog/assets/images/pod-distribution-example.png)


