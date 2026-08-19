---
title: "Running GitHub Actions Runner Controller on AKS Automatic"
date: "2026-08-19"
description: "A practical walkthrough for creating an AKS Automatic cluster and running GitHub Actions Runner Controller runner scale sets on it."
authors: ["steve-griffith"]
tags: ["automatic", "github-actions", "arc", "devops"]
---

GitHub Actions Runner Controller (ARC), also known as GitHub Actions Runner Controller runner scale sets or GARC, is a popular way to run self-hosted GitHub Actions runners on Kubernetes. It lets teams keep CI jobs close to the workloads they build, test, and deploy while still using the GitHub Actions experience developers already know.

ARC runner scale sets work on AKS Automatic, and the combination is compelling: GitHub-native CI jobs, Kubernetes-native ephemeral runners, and an AKS mode that handles much of the cluster and node management for you. Running GARC on AKS also lets your runners live inside your Azure network, including private virtual networks, so CI jobs can reach private endpoints, internal services, and locked-down build dependencies without exposing them to the public internet.

There is one important difference from a traditional bring-your-own-node-pool AKS cluster: AKS Automatic ships with production-oriented safeguards turned on. Those safeguards are helpful, but they also mean the default public ARC Helm values need a few adjustments before runner scale sets work cleanly. For third-party controllers and workload pods, be explicit about resource requests and image tags.

This post walks through creating an AKS Automatic cluster, installing ARC, creating a repository-scoped runner scale set, and validating that a GitHub Actions workflow runs on an ephemeral runner pod.

<!-- truncate -->

## What we are building

The lab deploys:

- An AKS Automatic cluster.
- The ARC runner scale set controller.
- A repository-scoped runner scale set.
- A sample GitHub Actions workflow that targets the runner scale set.

The key outcome is a workflow job whose `runs-on` value maps to an ARC runner scale set. When the job queues, ARC creates an ephemeral runner pod on AKS Automatic, the runner connects to GitHub, the job runs, and the runner is cleaned up.

## Prerequisites

You need the Azure CLI, GitHub CLI, `kubectl`, and Helm:

```bash
az login
gh auth login

az extension add --name aks-preview --upgrade

kubectl version --client
helm version
gh auth status
```

You also need a GitHub token with permission to manage Actions runners for the target repository. For a simple repository-scoped lab, a classic PAT with `repo` scope is enough for a private repository. For production, prefer a GitHub App so you can narrow permissions and rotate credentials more cleanly.

Read the token interactively so it does not land in your shell history:

```bash
read -rsp "GitHub token: " GITHUB_TOKEN
echo
```

## Set environment variables

Update these values for your subscription and GitHub repository:

```bash
export LOCATION=eastus
export RG=rg-arc-auto-lab
export CLUSTER=arc-auto-lab

export GITHUB_OWNER=<github-owner>
export GITHUB_REPO=<github-repo>
export GITHUB_CONFIG_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}"

export RUNNER_SET_NAME=arc-auto-runners
export ARC_SYSTEMS_NAMESPACE=arc-systems
export ARC_RUNNERS_NAMESPACE=arc-runners
```

`RUNNER_SET_NAME` matters because it is the value your workflow uses in `runs-on`.

## Create the AKS Automatic cluster

Create a resource group:

```bash
az group create \
  --name "${RG}" \
  --location "${LOCATION}"
```

Create the cluster:

```bash
az aks create \
  --resource-group "${RG}" \
  --name "${CLUSTER}" \
  --location "${LOCATION}" \
  --sku automatic \
  --no-ssh-key
```

Get credentials:

```bash
az aks get-credentials \
  --resource-group "${RG}" \
  --name "${CLUSTER}" \
  --overwrite-existing
```

Some Automatic clusters use Azure Kubernetes RBAC with local admin credentials disabled. If `kubectl get nodes` fails with an Azure RBAC authorization error, grant your signed-in user access to the cluster:

```bash
CLUSTER_ID=$(az aks show \
  --resource-group "${RG}" \
  --name "${CLUSTER}" \
  --query id \
  --output tsv)

USER_ID=$(az ad signed-in-user show \
  --query id \
  --output tsv)

az role assignment create \
  --assignee "${USER_ID}" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "${CLUSTER_ID}"
```

RBAC propagation can take a few minutes. Wait until this succeeds:

```bash
kubectl get nodes
```

## Install the ARC controller

The first AKS Automatic-specific adjustment is resource requests for the ARC controller. Create a values file:

```bash
cat > arc-controller-values.yaml <<'EOF'
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
EOF
```

Install the controller:

```bash
helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace "${ARC_SYSTEMS_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 10m \
  -f arc-controller-values.yaml

kubectl rollout status \
  deployment/arc-gha-rs-controller \
  --namespace "${ARC_SYSTEMS_NAMESPACE}" \
  --timeout 5m
```

## Store the GitHub token in Kubernetes

Create a namespace for runner resources and store the GitHub token in a secret:

```bash
kubectl create namespace "${ARC_RUNNERS_NAMESPACE}" \
  --dry-run=client \
  --output yaml | kubectl apply -f -

kubectl create secret generic github-pat \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  --from-literal=github_token="${GITHUB_TOKEN}"
```

For production, store and rotate this credential through your standard secret-management process. Do not hard-code it into Helm values or source control.

## Install the runner scale set

This is the most important part of the walkthrough. The default runner scale set values are close, but AKS Automatic safeguards require a few changes:

1. Resource requests and limits for the listener pod.
2. Resource requests and limits for the runner pod.
3. An explicit, non-`latest` runner image tag.

Create `arc-runner-set-values.yaml`:

```bash
cat > arc-runner-set-values.yaml <<EOF
githubConfigUrl: ${GITHUB_CONFIG_URL}
githubConfigSecret: github-pat
minRunners: 0
maxRunners: 3

listenerTemplate:
  spec:
    containers:
      - name: listener
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:2.336.0
        command: ["/home/runner/run.sh"]
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: "2"
            memory: 4Gi
EOF
```

This example pins `ghcr.io/actions/actions-runner:2.336.0`, which was the current GitHub runner release at the time this walkthrough was validated. Runner versions age out, so check [the GitHub runner releases](https://github.com/actions/runner/releases) and update the tag when needed.

Install the runner scale set:

```bash
helm upgrade --install "${RUNNER_SET_NAME}" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 10m \
  -f arc-runner-set-values.yaml
```

Check the installation:

```bash
kubectl get pods --namespace "${ARC_SYSTEMS_NAMESPACE}" --output wide

kubectl get autoscalingrunnersets,ephemeralrunnersets,ephemeralrunners \
  --namespace "${ARC_RUNNERS_NAMESPACE}"
```

Before any jobs run, expect the controller and listener pods to be running and the `AutoscalingRunnerSet` to exist. You should not expect runner pods yet. Runner pods are created only when jobs queue.

## Add a validation workflow

In the target GitHub repository, add `.github/workflows/arc-automatic-validation.yml`:

```yaml
name: ARC AKS Automatic validation

on:
  workflow_dispatch:

jobs:
  validate:
    runs-on: arc-auto-runners
    steps:
      - name: Print runner context
        run: |
          echo "ARC runner reached workflow execution"
          echo "Runner name: $RUNNER_NAME"
          uname -a
          df -h

      - name: Exercise container tooling
        run: |
          docker --version || true
          echo "Validation complete"
```

If you changed `RUNNER_SET_NAME`, update `runs-on` to match it. Commit and push the workflow to the repository:

```bash
git add .github/workflows/arc-automatic-validation.yml
git commit -m "Add AKS Automatic ARC validation workflow"
git push
```

## Run the workflow

Trigger the workflow:

```bash
gh workflow run arc-automatic-validation.yml \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --ref main
```

Watch the run:

```bash
RUN_ID=$(gh run list \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --workflow arc-automatic-validation.yml \
  --json databaseId \
  --jq '.[0].databaseId')

gh run watch "${RUN_ID}" \
  --repo "${GITHUB_OWNER}/${GITHUB_REPO}" \
  --interval 10 \
  --exit-status
```

In another terminal, watch ARC scale the runner set:

```bash
kubectl get autoscalingrunnersets,ephemeralrunnersets,ephemeralrunners \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  --watch
```

When everything is working, you will see:

- The GitHub Actions job move from `queued` to `in_progress` to `completed`.
- An ephemeral runner object and pod appear in `arc-runners`.
- The runner pod use your pinned `ghcr.io/actions/actions-runner` image.
- The workflow log print `ARC runner reached workflow execution`.

In the validation run for this walkthrough, the job ran on a pod named like `arc-auto-runners-<id>-runner-<id>`, reported runner version `2.336.0`, and completed successfully.

## Troubleshooting the AKS Automatic-specific issues

Here are the issues I hit while validating this setup and what they mean.

### Missing resource requests

If the listener or controller is rejected with an error like this:

```text
container <listener> has no resource requests
```

or:

```text
container <manager> has no resource requests
```

make sure the controller chart has `resources` set and the runner scale set chart has `listenerTemplate.spec.containers[].resources` set.

### The `latest` runner image is blocked

AKS Automatic safeguards can reject the default runner image because it uses a floating `latest` tag:

```text
Avoiding the latest tag for container: runner
```

Pin the runner image to an explicit release:

```yaml
template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:2.336.0
```

### The pinned runner version is too old

Pinning is necessary, but the pinned version still needs to be current. If the runner logs show:

```text
Runner version vX.Y.Z is deprecated and cannot receive messages.
```

update the image tag to a current runner release and upgrade the Helm release:

```bash
helm upgrade --install "${RUNNER_SET_NAME}" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  --wait \
  --timeout 10m \
  -f arc-runner-set-values.yaml
```

### The job stays queued

Start by checking the controller, listener, and runner logs:

```bash
kubectl logs \
  --namespace "${ARC_SYSTEMS_NAMESPACE}" \
  deployment/arc-gha-rs-controller \
  --tail 200

kubectl logs \
  --namespace "${ARC_SYSTEMS_NAMESPACE}" \
  -l app.kubernetes.io/component=runner-scale-set-listener \
  --tail 200

kubectl logs \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  -l app.kubernetes.io/component=runner \
  --tail 200
```

Also confirm that the workflow `runs-on` value exactly matches the runner scale set name.

## Cleanup

Remove the Helm releases:

```bash
helm uninstall "${RUNNER_SET_NAME}" --namespace "${ARC_RUNNERS_NAMESPACE}"
helm uninstall arc --namespace "${ARC_SYSTEMS_NAMESPACE}"

kubectl delete namespace "${ARC_RUNNERS_NAMESPACE}" "${ARC_SYSTEMS_NAMESPACE}"
```

Delete the resource group:

```bash
az group delete \
  --name "${RG}" \
  --yes \
  --no-wait
```

If any offline repository runners remain in GitHub after failed experiments, remove them from the repository's Actions runner settings.

Once those settings are in place, ARC can scale an ephemeral runner, pick up a queued GitHub Actions job, and run it successfully on AKS Automatic.
