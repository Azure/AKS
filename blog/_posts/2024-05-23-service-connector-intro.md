---
title: "Service Connector Introduction"
description: "Simplify Your Azure Kubernetes Service Connection Configuration with Service Connector"
date: 2024-05-23
author: Coco Wang
categories: security # general, operations, networking, security, developer topics, add-ons
---
Workloads deployed on an Azure Kubernetes Service (AKS) cluster often need to access Azure backing resources, such as Azure Key Vault, databases, or AI services like Azure OpenAI Service. Users are required to manually configure [Microsoft Entra Workload ID](https://learn.microsoft.com/entra/workload-id/workload-identities-overview) or Managed Identities so their AKS workloads can securely access these protected resources.

The [Service Connector](https://learn.microsoft.com/azure/service-connector/overview) integration greatly simplifies the connection configuration experience for AKS workloads and Azure backing services. Service Connector takes care of authentication and network configurations securely and follows Azure best practices, so you can focus on your application code without worrying about your infrastructure connectivity.
 
![image](/assets/images/service-connector-intro/service-connector-overview.png)
Service Connector Action Breakdown     

Before Service Connector, in order to [connect from AKS pods to a private Azure backing services](https://learn.microsoft.com/azure/aks/workload-identity-deploy-cluster) using workload identity, users needed to perform the following actions manually:
1.	Create a managed identity
2.	Retrieve the OIDC issuer URL
3.	Create Kubernetes service account
4.	Establish federated identity credential trust
5.	Grant permissions to access Azure Services
6.	Deploy the application

Now, Service Connector performs steps 2 to 5 automatically. Additionally, for Azure services without public access, Service Connector creates private connection components such as private link, private endpoint, DNS record, etc.   
You can create a connection in the Service Connection blade within AKS.
![image](/assets/images/service-connector-intro/service-connector-create.png)
Click create and select the target service, authentication method, and networking rule. The connection will then be automatically set up. 

In addition to Azure portal, Service Connector also supports [Azure CLI](https://learn.microsoft.com/azure/service-connector/quickstart-cli-aks-connection?tabs=Using-access-key).

Service Connector on AKS cluster is currently in preview. Here are a few helpful links to for you to learn more about Service Connector.
-	[Create a service connection in an AKS cluster from the Azure portal](https://learn.microsoft.com/azure/service-connector/quickstart-portal-aks-connection?tabs=UMI)
-	[Tutorial: Connect to Azure OpenAI Service in AKS using a connection string (preview)](https://aka.ms/service-connector-aks-openai-connection-string)
-	[Tutorial: Connect to Azure OpenAI Service in AKS using Workload Identity (preview)](https://aka.ms/service-connector-aks-openai-workload-identity)
-	[What is Service Connector?](https://learn.microsoft.com/azure/service-connector/overview)

