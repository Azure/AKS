# Identity Binding Example

This example demonstrates how to use the Identity Binding feature in an AKS cluster.

## Prerequisites

- Please ensure you have the latest preview version of Azure CLI installed. You can follow the instructions [here](https://learn.microsoft.com/cli/azure/aks/extension?view=azure-cli-latest).
- Ensure your subscription has the `Microsoft.ContainerService/IdentityBinding` feature flag enabled.
- Ensure your cluster is enabled with [AKS Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster) feature.


> [!Note]
> Identity Binding requires preview version of AKS workload identity webhook. Please confirm the following output from the command:
>
> ```bash
> kubectl -n kube-system get pods -l azure-workload-identity.io/system=true -o yaml | grep v1.6.0
> image: mcr.microsoft.com/oss/v2/azure/workload-identity/webhook:v1.6.0-alpha.1
> ```
>
> Seeing `v1.6.0-alpha.1` in the image tag confirms that the preview version of webhook is installed.

## Steps

The following steps assume you have already created an AKS cluster `<cluster-name>` and managed identity `<mi-name>` under resource group `<rg-name>` and subscription `<subscription-id>`.

We will reference the client id of the managed identity with `<mi-client-id>` in the following steps.

### 1. Create identity binding resource


```bash
az aks identity-binding create \
    --resource-group <rg-name> \
    --cluster-name <cluster-name> \
    --name my-first-ib \
    --managed-identity-resource-id /subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<mi-name>
```

> [!Note]
> Successful creation of identity binding resource will result in a federated managed identity credential being created in the managed identity with name `aks-identity-binding`. This federated managed identity credential is required by identity binding feature to work.

### 2. Configure in-cluster access via cluster role and cluster role binding

The identity binding feature uses Kubernetes RBAC to control which pods can access which managed identities via a cluster role with the verb `use-managed-identity`. In this step, we will create a cluster role and cluster role binding to grant the `default` service account in the `default` namespace permission to access the managed identity created in the previous step.

Before deploying the `cluster-role-and-cluster-role-binding.yaml`, please make sure to replace `<mi-client-id>` placeholder in the file with the actual client id of the managed identity.

```bash
kubectl apply -f cluster-role-and-cluster-role-binding.yaml
clusterrole.rbac.authorization.k8s.io/my-first-ib-cr created
clusterrolebinding.rbac.authorization.k8s.io/my-first-ib-crb created
```

### 3. Deploy sample application pod

Following the same step from the [Azure workload identity documentation](https://learn.microsoft.com/azure/aks/workload-identity-deploy-cluster#grant-permissions-to-access-azure-key-vault), we will deploy a sample pod that uses the managed identity to access a secret from an Azure Key Vault.
Please make sure to replace the `<your-keyvault-name>` and `<secret-name>` placeholders in the `pod.yaml` file with your actual Key Vault name and secret name.

```bash
kubectl apply -f pod.yaml
pod/my-first-ib-pod created
```

> [!Note]
> Comparing with the original workload identity example, the below highlights the differences when using identity binding feature:
> ```diff
> kind: Pod
> metadata:
>   labels:
>     azure.workload.identity/use: "true"
> + annotations:
> +   azure.workload.identity/use-identity-binding: "true"
> ```

### 4. Verify the sample application pod

```bash
kubectl logs my-first-ib-pod
I1107 20:03:42.865180       1 main.go:77] "successfully got secret" secret="Hello!"
```