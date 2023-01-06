# Azure Kubernetes Service (AKS) issue and feature tracking

## Overview

This repository is offered for tracking features and issues with the Azure Kubernetes
Service (AKS). This repository is monitored by the AKS product team in order to engage with our community and discuss questions, customer scenarios, or feature requests.

Support through issues on this repository is provided on a **best-effort basis** for issues that are reproducible outside
of a specific cluster configuration (see [Bug Guidance](#bugs) below). To receive urgent support you must file a support request through official Azure support channels as urgent support is explicitly out of scope of this repository's objectives.

> **IMPORTANT**: For official customer support with response-time SLAs please see
[Azure Support options][1] and [AKS Support Policies][2]. 

Do not file issues for AKS-Engine, Virtual-Kubelet, Azure Container Instances, or services on
this repository unless it is related to that feature/service and functionality
with AKS. For other tools, products and services see the [Upstream Azure Compute projects page](https://github.com/Azure/container-compute-upstream/blob/master/README.md#project-list).

## Important links

* AKS Roadmap: http://aka.ms/aks/roadmap
* AKS hybrid deployment options: https://aka.ms/aks-hybrid
* AKS Release Notes: https://aka.ms/aks/releasenotes
* AKS Preview Features: https://aka.ms/aks/preview-features
* AKS Public Office Hours: https://aka.ms/akspublicofficehours
* Updates about the service, including new features and new Azure regions:
  [AKS feed in Azure Updates](https://azure.microsoft.com/updates/?product=kubernetes-service)

## Code of conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Bug Reports <a name="bugs"></a>

> **IMPORTANT**: An inability to meet the below requirements for bug reports are subject to being closed by maintainers and routed to official Azure support channels to provide the proper support experience to resolve user issues.

Bug reports filed on this repository should follow the default issue template
that is shown when opening a new issue. At a bare minimum, issues reported on
this repository must:

1. Be reproducible outside of the current cluster

* This means that if you file an issue that would require direct access to
  your cluster and/or Azure resources you will be redirected to open an Azure
  support ticket. Microsoft employees may not ask for personal / subscription
  information on Github.
    * For example, if your issue is related to custom scenarios such as
    custom network devices, configuration, authentication issues related to
    your Azure subscription, etc.

2. Contain the following information:

* A good title: Clear, relevant and descriptive - so that a general idea of the
  problem can be grasped immediately
* Description: Before you go into the detail of steps to replicate the issue,
  you need a brief description.
  * Assume that whomever is reading the report is unfamiliar with the
    issue/system in question
* Clear, concise steps to replicate the issue outside of your specific cluster.
  * These should let anyone clearly see what you did to see the problem, and
    also allow them to recreate it easily themselves. This section should also
    include results - both expected and the actual - along with relevant URLs.
* Be sure to include any supporting information you might have that could aid the developers.
  * This includes YAML files/deployments, scripts to reproduce, exact commands used, screenshots, etc.

[1]: https://azure.microsoft.com/support/options/
[2]: https://docs.microsoft.com/en-us/azure/aks/support-policies

## Hiring
### Engineering
- [Principal Software Engineer - Azure Kubernetes Service](https://careers.microsoft.com/us/en/job/1332158/Principal%20Software%20Engineer%20-%20Azure%20Kubernetes%20Service)
- [Senior Software Engineer - Azure Kubernetes Service](https://careers.microsoft.com/us/en/job/1171089/Senior%20Software%20Engineer%20-%20Azure%20Kubernetes%20Service)
- [Software Engineer II - Azure Kubernetes Service](https://careers.microsoft.com/us/en/job/1241030)
- [Software Engineer - Azure Kubernetes Service](https://careers.microsoft.com/us/en/job/1241021)

### Product Management

- [Senior Product Manager](https://careers.microsoft.com/us/en/job/1225749/Senior%20Program%20Manager)
