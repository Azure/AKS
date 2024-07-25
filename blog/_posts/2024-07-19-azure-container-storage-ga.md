---
title: "Azure Container Storage - Generally Available"
description: "Simplify your Stateful workloads deployments with Azure Container Storage"
date: 2024-07-30
author: Saurabh Sharma
categories: general #operations, developer topics
---
Last May, we announced [the preview of Azure Container Storage](https://azure.microsoft.com/en-us/blog/transforming-containerized-applications-with-azure-container-storage-now-in-preview/) with backing storage options including Ephemeral Disk, Azure Disk, and Elastic SAN. Earlier today we announced [the general availability of Azure Container Storage](https://aka.ms/Azure-container-storage-ga-blog), the industry’s first platform-managed container native storage service in the public cloud providing highly scalable storage that can keep up with the demands of a containerized environment. With this announcement, Azure Disks and Ephemeral Disks are now generally available, while Elastic SAN remains in preview and is expected to reach general availability soon. In this post, we'll explore the benefits of Azure Container Storage, the inspirations behind its development, and the new features in the GA release.

With the rise in adoption of stateful workloads on Kubernetes, there is an increase in product workloads that require container-native persistent storage for databases (like MySQL), big data (such as ElasticSearch), messaging applications (like Kafka), and CI/CD systems (such as Jenkins). However, customers today face a choice between using VM-centric cloud storage options retrofitted to containers or deploying and self-managing open-source container storage solutions in the cloud. This leads to substantial operational overhead, scaling bottlenecks, and high costs. To remove this bottleneck and provide customers with operational simplicity, we developed Azure Container Storage. Azure Container Storage introduces the concept of a storage pool, an abstraction layer between persistent volumes and multiple backing storage options, enabling you to leverage the storage options that best align with your workload needs. Key benefits of Azure Container Storage include enhanced resiliency with zonal alignment support and replication on ephemeral disks,  rapid scale up with application pods to a large number of persistent volumes (PVs) , reduced total cost of ownership by dynamic sharing of IOPS and MB/s across PVs, and more.   

## Latest Updates with GA

As part of General Availability release, we’re thrilled to introduce three new capabilities captured below. For details on all supported capabilities and how to get started, refer to our [documentation](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-aks-quickstart).   

•	[Improved resiliency with ephemeral storage pools](https://learn.microsoft.com/en-us/azure/storage/container-storage/use-container-storage-with-local-nvme-replication): Applications leveraging Local NVMe disks with Azure Container Storage can now configure replication during storage pool definition, which will synchronously replicate data volumes across the NVMe disks in the storage pool based on the number of replicas specified.

•	[Customize performance of local NVMe storage with new performance tiers  option](https://learn.microsoft.com/azure/storage/container-storage/use-container-storage-with-local-disk#optimize-performance-when-using-local-nvme): We are introducing performance tier selection options with the new cli flag “--ephemeral-disk-nvme-perf-tier” which provides three profiles: basic, standard and advanced to enable you to select the performance on your ephemeral disks based on your workload requirements.

•	Enhanced volume recovery: We have further improved the automatic volume recovery process for scenarios like Azure Kubernetes Service (AKS) cluster restart. We continue to enhance the resiliency of Azure Container Storage to protect against cluster failures. 

In addition, we are sharing [a repository of GitHub workload samples](https://aka.ms/AzureContainerStorageSamples) that pair common stateful workloads on Kubernetes with backing storage options on Azure Container Storage, making it easier for you to get started. 

## Stateful workload samples

Here is a quick walkthrough of the stateful workloads outlined in the sample repository for each backing storage option.

### Azure Disks
Azure Disks storage pools can be leveraged for tier 1 and general-purpose databases such as MySQL, MongoDB, PostgreSQL and workloads like JupyterHub and ElasticSearch which require creation of thousands of persistent volumes as well as rapid scale up of these volumes as the data size increases. Additionally, Azure Disks storage pools support capabilities like storage pool size expansion, support for storage-level replication for added resiliency across zones using Premium SSD ZRS or Standard SSD ZRS disks. 

Let’s look at Jupterhub as a sample workload that could leverage Azure Disks. JupyterHub enables scalable deployment and management of Jupyter Notebooks. It provides shared access to a Jupyter Notebook server for multiple users, useful in classrooms, research groups, or companies. Azure Container Storage backed by Azure Disks provides highly scalable architecture where thousands of users can be connected to a single notebook server instance and each user gets a dedicated instance (pod in Kubernetes) of the Notebook backed by a PV, see diagram below. Follow this [Azure Sample](https://github.com/Azure-Samples/azure-container-storage-samples/tree/main/jupyter) to run JupyterHub on Azure Container Storage today.

![image](https://github.com/user-attachments/assets/e6ce89d0-8d4c-4eb9-a6bf-f733966e5afb)


ElasticSearch is another workload sample that could be hosted on Azure Disks. Elasticsearch, the core of the Elastic Stack, offers near real-time search and analytics for various data types. Its distributed architecture ensures seamless scalability as your data and query volume increase, making it well-suited for containerized deployment. Azure Container Storage facilitates rapid scaling of Elasticsearch pods by efficiently packing new persistent volumes onto attached disks, reducing PV creation time and accelerating data ingestion. Moreover, by packing multiple PVs onto a single attached disk, it bypasses node attach limits, enhancing price performance ratio. See step by step instructions to deploy ElasticSearch [here](https://github.com/Azure-Samples/azure-container-storage-samples/tree/main/ElasticSearch). 

  ![image](https://github.com/user-attachments/assets/a110e37c-6de4-4d0a-a574-66db7b26c1ab)


 
### Ephemeral Storage
Ephemeral disks, suitable for latency-sensitive and IOPS-intensive workloads, are available on storage-optimized VM SKUs like [L-series](https://learn.microsoft.com/en-us/azure/virtual-machines/lsv3-series) and [Ev3-series and Esv3-series](https://learn.microsoft.com/en-us/azure/virtual-machines/ev3-esv3-series). These VMs come with NVMe disks or temporary storage, both offering low latency (with NVMe providing sub-millisecond latency). Azure Container Storage orchestrates volume management on top of the local storage and allows you to partition it into multiple application volumes. 

Let’s explore deploying a Cassandra workload on Ephemeral storage. Cassandra, an open-source NoSQL distributed database, provides scalability and high availability without sacrificing performance. Cassandra’s replication model allows you to specify the number of data copies to maintain. Azure Container Storage is ideal for running workloads like Cassandra, which require application-level replication, low latency, and high performance. Additionally, it provides volume replication for storage pools on NVMe, enhancing resiliency. See step by step instructions to set up Cassandra workload with Azure Container Storage [here](https://github.com/Azure-Samples/azure-container-storage-samples/tree/main/cassandra). 


![image](https://github.com/user-attachments/assets/4ad6a8fe-132b-499b-91ae-3aa61575e296)

 

### Elastic SAN (Preview) 
For on-demand, fully managed storage, you can use Elastic SAN as the backing storage for Azure Container Storage. Elastic SAN is Azure’s newest block storage offering. It has a unique resource hierarchy that allows dynamic performance sharing across volumes and leverages iSCSI protocol to enable fast attach and detach of volumes. Because of its design with Azure Container Storage, Elastic SAN is a great backing storage option for use cases that need to provision volumes quickly without worrying about performance. We recommend Elastic SAN for customers who do not need granular control over storage for their containerized applications, typically running general purpose database workloads, streaming and messaging services, or CI/CD environments. 

A great workload to use Elastic SAN storage pools for is Kafka. Kafka is an open-source distributed event streaming platform. Typically used for high-performance data pipelines, streaming analytics, and mission-critical applications, high throughput and scalability are in high demand when using Kafka. Since Elastic SAN offers cost efficient high performance at scale, Kafka applications can use Azure Container Storage with Elastic SAN to reliably scale out to a large number of volumes without sacrificing on throughput. See the [Azure Sample](https://github.com/Azure-Samples/azure-container-storage-samples/tree/main/kafka) on how to easily get started with Kafka on Azure Container Storage.  

## Get Started with Azure Container Storage

Let’s get started with installing Azure Container Storage to your AKS cluster! For a comprehensive guide, [watch our step-by-step walkthrough video](https://aka.ms/AzureContainerStorageSkilling). 

As shared in the samples above, we are also debuting a community [GitHub samples](https://aka.ms/AzureContainerStorageSamples) repository to help you easily start running common stateful workloads on Azure Container Storage. We invite all to contribute, adding samples as you explore different workloads and benefiting the open-source community. 

Refer to the [Azure Container Storage documentation](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-aks-quickstart) to learn more about the service.
