# Module 0: Check prerequisites

This module takes about 5 minutes and creates no Azure resources.

## Run the preflight check

```bash
./scripts/00-preflight.sh
```

The script checks:

- Azure CLI, `kubectl`, Python 3, and Bash.
- Azure sign-in and the active subscription.
- Required Azure resource providers.
- The `ManagedGPUExperiencePreview` feature registration.
- Provider re-registration that propagates the preview feature.
- Kubernetes 1.35 availability in the selected region.
- Availability and quota for the system and GPU virtual machine (VM) sizes.
- Total regional virtual CPU quota for the complete example.

The default configuration uses `westus2`. If your quota is in another region,
set the location before running the script:

```bash
export LAB_LOCATION=eastus
./scripts/00-preflight.sh
```

The scripts also support custom resource group and cluster names:

```bash
export LAB_RESOURCE_GROUP=my-managed-gpu-example
export LAB_CLUSTER=my-managed-gpu-example
```

The validated Kubernetes version is 1.35. If that version isn't available in
your selected region, set another version supported by the managed GPU preview:

```bash
export LAB_KUBERNETES_VERSION=1.34
```

The VM sizes are fixed because the model, replica count, memory requests, and
validation results depend on their exact shape.

## Register the preview feature

If preflight reports that the feature is not registered, run:

```bash
az feature register \
  --namespace Microsoft.ContainerService \
  --name ManagedGPUExperiencePreview
```

Registration can take several minutes. Rerun preflight after the state changes
to `Registered`. Preflight then re-registers `Microsoft.ContainerService` and
waits for the preview feature to propagate.

## Checkpoint

The final output should be:

```output
PASS  Preflight passed. Continue with modules/01-cluster.md.
```

## Troubleshoot

| Problem | Action |
| --- | --- |
| Azure CLI is too old | Upgrade to Azure CLI 2.85.0 or later |
| `aks-preview` is missing | Run `az extension add --name aks-preview`, then update it |
| `kubectl` is too old | Upgrade to kubectl 1.34 or later |
| Kubernetes 1.35 isn't available | Set `LAB_KUBERNETES_VERSION` to a version supported by the managed GPU preview in that region |
| A provider is not registered | Run the registration command printed by preflight |
| The GPU VM size is restricted | Select a region where the subscription can use `Standard_NC24ads_A100_v4` |
| Family or regional quota is insufficient | Request quota for the reported family and **Total Regional vCPUs** |

## Next step

[Module 1: Create the cluster](01-cluster.md)
