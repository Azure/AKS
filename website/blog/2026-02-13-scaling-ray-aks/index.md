---
title: "Scaling Ray on AKS"
description: "Learn how to run production-grade Ray workloads on Azure Kubernetes Service with multi-region support, unified storage, and secure authentication."
date: 2026-02-13
authors:
  - anson-qian
  - bob-mital
  - kenneth-kilty
categories:
tags: ["ai", "ray", "anyscale"]
---

Following our [initial announcement of Ray on AKS](https://blog.aks.azure.com/2025/01/13/ray-on-aks), we've been working closely with Anyscale to enhance the production-readiness of Ray workloads on Azure Kubernetes Service. As part of Microsoft and Anyscale's [strategic collaboration to deliver AI-native computing on Azure](https://www.anyscale.com/press/anyscale-collaborates-with-microsoft-to-deliver-ai-native-computing-on-azure), we've focused on three critical areas:

- **Elastic scalability** through multi-region capacity aggregation
- **Data persistence** with unified storage across the ML lifecycle
- **Operational simplicity** through automated credential management

Whether you're [fine-tuning models with DeepSpeed or LLaMA-Factory](https://github.com/Azure-Samples/aks-anyscale/tree/main/examples/finetuning) or [deploying inference endpoints for LLMs ranging from small to large-scale reasoning models](https://github.com/Azure-Samples/aks-anyscale/tree/main/examples/inferencing), this architecture delivers a production-grade ML platform that scales with your needs.

## Multi-cluster, multi-region support

GPU availability remains one of the most significant challenges in large-scale ML operations. High-demand accelerators like NVIDIA GPUs often face capacity constraints in specific Azure regions, leading to delays in provisioning clusters or launching training jobs.

### Overcoming GPU scarcity

By deploying Ray clusters across multiple AKS clusters in different Azure regions, you can:

- **Increase GPU availability**: Distribute workloads across regions with available capacity, reducing wait times for cluster provisioning
- **Use regional pricing differences**: Take advantage of lower spot instance prices or reserved capacity in specific regions
- **Improve fault tolerance**: If one region experiences an outage or capacity shortage, workloads can be automatically rerouted to healthy clusters
- **Scale beyond single-cluster limits**: Azure imposes quota limits on GPU instances per region, but multi-region deployments let you aggregate capacity

To add a cluster in another region to your existing Anyscale cloud, define a cloud resource ([cloud_resource.yaml](./aks-anyscale/cloud_resource.yaml)):

```yaml
name: k8s-azure-$REGION
provider: AZURE
compute_stack: K8S
region: $REGION
object_storage:
  bucket_name: abfss://${STORAGE_CONTAINER}@${STORAGE_ACCOUNT}.dfs.core.windows.net
file_storage:
  persistent_volume_claim: blob-fuse2
azure_config:
  tenant_id: ${AZURE_TENANT_ID}
kubernetes_config:
  anyscale_operator_iam_identity: ${IDENTITY_PRINCIPAL_ID}
```

Then create the cloud resource using the Anyscale CLI:

```bash
anyscale cloud resource create \
  --cloud "$ANYSCALE_CLOUD_NAME" \
  -f "$CLOUD_RESOURCE_YAML"
```

With infrastructure deployed across multiple regions, you can manage and monitor Ray workloads from the Anyscale console. The unified cloud view shows all registered clusters and their available resources:

![Anyscale Resources](./anyscale-resources.png)

Anyscale Workspaces provides a managed environment for running interactive Ray workloads, with automatic scheduling across available clusters based on resource requirements:

![Anyscale Workspaces](./anyscale-workspaces.png)

## Cluster storage support


Managing training data, model checkpoints, and artifacts across the ML lifecycle—from pre-training to fine-tuning to inference—requires reliable storage. [Azure BlobFuse2](https://github.com/Azure/azure-storage-fuse) provides a solid storage backend for Ray workloads across AKS nodes.

![Cluster Storage Architecture](./cluster-storage.svg)

To use BlobFuse2 with Ray on AKS:

1. Create Azure Blob Storage containers for datasets, checkpoints, and models.

2. Enable [blob-csi-driver](https://github.com/kubernetes-sigs/blob-csi-driver) when creating your AKS cluster:

   ```bash
   az aks create \
     --resource-group "$RESOURCE_GROUP" \
     --name "$AKS_CLUSTER_NAME" \
     --location "$REGION" \
     --enable-blob-driver
     ...
   ```

3. Create a [StorageClass](https://github.com/Azure-Samples/aks-anyscale/blob/main/config/storageclass.yaml) that uses workload identity authentication and optimized caching parameters for large files:

   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: blob-fuse2

   provisioner: blob.csi.azure.com
   parameters:
     protocol: fuse2
     storageAccount: ${STORAGE_ACCOUNT}
     resourceGroup: ${RESOURCE_GROUP}
     clientID: ${IDENTITY_CLIENT_ID}
     mountWithWorkloadIdentityToken: "true"

   mountOptions:
     - -o allow_other
     - --file-cache-timeout-in-seconds=120
     - --use-attr-cache=true
     - --cancel-list-on-mount-seconds=10
     - -o attr_timeout=120
     - -o entry_timeout=120
     - -o negative_timeout=120
     - --log-level=LOG_WARNING
     - --cache-size-mb=1000

   allowVolumeExpansion: true
   reclaimPolicy: Retain
   volumeBindingMode: Immediate
   ```

4. Create a [PersistentVolumeClaim](https://github.com/Azure-Samples/aks-anyscale/blob/main/config/pvc.yaml) in the `anyscale-operator` namespace with `ReadWriteMany` access mode. This allows multiple Ray workers across different nodes and clusters to access the same storage:

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: blob-fuse2
     namespace: anyscale-operator
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: blob-fuse2
     resources:
       requests:
         storage: 100Gi
   ```

5. Configure Ray workloads to write directly to mounted blob paths (for example, `/mnt/cluster_storage`).

This setup enables Ray workers to read and write data using standard POSIX file operations while benefiting from the scalability and durability of object storage. Data scientists and ML engineers can seamlessly transition from pre-training to fine-tuning to inference without manual data migration.

## Service principal authentication

Maintaining secure and reliable authentication between Ray clusters and Azure resources can be challenging. Previous approaches often relied on CLI tokens or API keys that expire every 30 days, requiring manual rotation and creating potential service disruptions.

By using Azure service principals with managed identities, teams can eliminate this operational burden. Service principals provide long-lived, automatically managed credentials that integrate seamlessly with Azure's identity and access management (IAM) system.

Benefits of service principal-based authentication:

- Zero credential storage in Kubernetes clusters
- Automatic token refresh without manual intervention
- Fine-grained RBAC for Azure resource access
- Full audit trails through Azure Activity Logs

The following diagram illustrates how Azure Workload Identity enables the Anyscale Kubernetes Operator to authenticate without storing credentials:

![Workload Identity Authentication Flow](./auth-flow.svg)

In this authentication flow:

1. The `Anyscale Operator` pod authenticates using a user-assigned managed identity.
2. The managed identity requests an access token with scope `api://086bc.../.default`.
3. The token is issued by the `Anyscale Kubernetes Operator Auth` service principal.
4. The service principal's `appId` becomes the `AZURE_CLIENT_ID` environment variable.
5. The managed identity's `appId` appears as the `oid` claim in the resulting access token.

## Conclusion

Running Ray at scale on Azure Kubernetes Service requires careful attention to compute, storage, and security strategies. Whether you're running hundreds of small experimental jobs or massive multi-day training runs, anyscale on AKS provides the flexibility and reliability needed for modern ML operations.

Interested? Reach out for private preview access—more to come.