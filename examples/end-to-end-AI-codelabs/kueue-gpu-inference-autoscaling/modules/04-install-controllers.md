# Module 4: Install the controllers

**Goal:** Install Kueue and make GPU resources visible when the node arrives.

**Time:** About 5 minutes.

## Install the components

```bash
./scripts/30-install-controllers.sh
```

The script installs:

- Kueue from the AKS AI Runtime chart in Microsoft Container Registry;
- the NVIDIA device plugin from its upstream Helm chart.

The device plugin DaemonSet has no pod yet because the GPU pool is at zero. When
the cluster autoscaler creates a GPU node, the DaemonSet starts there and
advertises `nvidia.com/gpu`.

Kueue runs on the existing CPU system pool. It watches suspended Jobs and admits
them only after quota and admission checks pass.

## Checkpoint

```bash
kubectl -n kueue-system get deployment kueue-controller-manager
kubectl -n kube-system get daemonset nvidia-device-plugin
```

Expect the Kueue Deployment to be Available. The device plugin can show zero
desired pods until the GPU node is created.

## Troubleshoot

| Problem | Action |
|---|---|
| Helm can't pull the Kueue chart | Confirm access to `mcr.microsoft.com` and rerun the script |
| Kueue Deployment isn't Available | Run `kubectl -n kueue-system describe deployment kueue-controller-manager` |
| Device plugin shows zero desired pods | This is expected while the GPU pool is at zero |

## Next step

Continue to [Module 5: Configure provisioning](05-configure-provisioning.md).
