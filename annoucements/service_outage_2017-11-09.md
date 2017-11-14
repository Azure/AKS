### Service Outage 9th Nov 2017


We have a general service outage in West US 2 that we are investigating. 

During the time we investigate, cluster creations in West US 2 will not be possible and existing customers might not work.

We will update this thread when we fix the issue.

We apologize for the inconvenience.


### Update 13th Nov 2017

AKS clusters can now be deployed to East US region. 

In case you get a "the subscription is not registered for the resource type managedClusters in the location eastus.." while deploying through the Azure CLI please run the following command to register it.

`az provider register --namespace Microsoft.ContainerService`

Customers are recommended to delete existing clusters in West US 2 and deploy to East US region as a workaround for the issue. We are working on enabling additional regions as soon as possible. This thread will be updated with more updates. 

Thanks for your patience.


### Update 14th Nov 2017

AKS clusters can now also be deployed in the West Europe region in addition to East US.



