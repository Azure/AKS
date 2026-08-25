---
title: "Running GitHub Actions Runner Controller on AKS Automatic"
date: "2026-08-19"
description: "A hands-on walkthrough for creating an AKS Automatic cluster and running GitHub Actions Runner Controller runner scale sets on it."
authors: ["steve-griffith"]
tags: ["automatic", "github-actions", "arc", "devops"]
---

GitHub Actions Runner Controller, also known as GitHub ARC or ARC for short, is a popular way to run self-hosted GitHub Actions runners on Kubernetes. In this walkthrough, we’ll set up ARC on [AKS Automatic](https://learn.microsoft.com/azure/aks/intro-aks-automatic) and run a real GitHub Actions job on an ephemeral runner pod.

The combination of ARC and AKS Automatic gives you the power of ARC on a production-ready AKS cluster with managed node pools, built-in monitoring, scaling, security settings, and other defaults that follow [AKS best practices](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-kubernetes-service). For runner workloads specifically, the [pod readiness SLA](https://learn.microsoft.com/azure/aks/intro-aks-automatic#pod-readiness-sla) is also a strong fit because CI/CD jobs depend on predictable pod startup.

ARC runner scale sets work extremely well on AKS Automatic, and the secure-by-default posture of AKS Automatic helps ensure your configuration is optimized and secure. You get the core ARC benefits: GitHub-native CI jobs, Kubernetes-native ephemeral runners, and runners that can live inside your Azure network, including private virtual networks. That means build jobs can reach private endpoints, internal services, and locked-down dependencies without exposing those resources to the public internet.

AKS Automatic is secure by default and has production-minded safeguards enabled. That's a good thing, but it also means the default public ARC Helm chart values need a little tuning. In particular, we need to be explicit about resource requests and image tags.

<!-- truncate --> 

Let’s walk through the full setup.



## What we'll build

In this lab we'll deploy:

- An AKS Automatic cluster.
- The ARC runner scale set controller.
- A repository-scoped runner scale set.
- A sample GitHub Actions workflow that targets the runner scale set.

The goal is pretty simple. We'll create a workflow where `runs-on` maps to the ARC runner scale set. When the job queues, ARC creates an ephemeral runner pod on AKS Automatic, the runner connects to GitHub, the job runs, and then the runner goes away.

## Prerequisites

First, make sure you have the Azure CLI, GitHub CLI, `kubectl`, and Helm installed and authenticated:

```bash
az login
gh auth login

az extension add --name aks-preview --upgrade

kubectl version --client
helm version
gh auth status
```

You'll also need a GitHub token with permission to manage Actions runners for the target repository. For a quick repo-scoped lab, a classic PAT with `repo` scope is enough for a private repo. For anything production-ish, I'd use a GitHub App instead so the permissions and rotation story are cleaner.

Read the token interactively so it doesn't end up in your shell history:

```bash
read -rsp "GitHub token: " GITHUB_TOKEN
echo
```

## Set environment variables

Now set up a few variables. Update these for your subscription and GitHub repo:

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

The `RUNNER_SET_NAME` value is important. This is also the value we'll use in the workflow `runs-on`.

## Create the AKS Automatic cluster

First, create a resource group:

```bash
az group create \
  --name "${RG}" \
  --location "${LOCATION}"
```

Now create the Automatic cluster:

```bash
az aks create \
  --resource-group "${RG}" \
  --name "${CLUSTER}" \
  --location "${LOCATION}" \
  --sku automatic \
  --no-ssh-key
```

Once the cluster is ready, get credentials:

```bash
az aks get-credentials \
  --resource-group "${RG}" \
  --name "${CLUSTER}" \
  --overwrite-existing

# check connectivity
kubectl get nodes
```

## Install the ARC controller

First up is the ARC controller. For AKS Automatic, we'll give the controller explicit resource requests and limits. Create a values file:

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

Now install the controller:

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

Now let's create a namespace for the runner resources and store the GitHub token in a Kubernetes secret:

```bash
kubectl create namespace "${ARC_RUNNERS_NAMESPACE}" \
  --dry-run=client \
  --output yaml | kubectl apply -f -

kubectl create secret generic github-pat \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  --from-literal=github_token="${GITHUB_TOKEN}"
```

For production, wire this into your normal secret-management process. Don't hard-code this token into Helm values or source control.

## Install the runner scale set

This is the most important part of the setup. The default runner scale set values are close, but AKS Automatic expects a few things to be explicit:

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

This example pins `ghcr.io/actions/actions-runner:2.336.0`, which was the current GitHub runner release when I validated the walkthrough. Runner versions do age out, so check [the GitHub runner releases](https://github.com/actions/runner/releases) and update the tag when needed.

Now install the runner scale set:

```bash
helm upgrade --install "${RUNNER_SET_NAME}" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace "${ARC_RUNNERS_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 10m \
  -f arc-runner-set-values.yaml
```

Check the install:

```bash
kubectl get pods --namespace "${ARC_SYSTEMS_NAMESPACE}" --output wide

kubectl get autoscalingrunnersets,ephemeralrunnersets,ephemeralrunners \
  --namespace "${ARC_RUNNERS_NAMESPACE}"
```

Before any jobs run, the controller and listener pods should be running and the `AutoscalingRunnerSet` should exist. You should not see runner pods yet. ARC creates those only when jobs queue.

## Add a validation workflow

Now add a simple workflow to the target GitHub repo. Create `.github/workflows/arc-automatic-validation.yml`:

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

If you changed `RUNNER_SET_NAME`, update `runs-on` to match it. Then commit and push the workflow:

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

When everything is working, you should see:

- The GitHub Actions job move from `queued` to `in_progress` to `completed`.
- An ephemeral runner object and pod appear in `arc-runners`.
- The runner pod use your pinned `ghcr.io/actions/actions-runner` image.
- The workflow log print `ARC runner reached workflow execution`.

In my validation run, the job ran on a pod named like `arc-auto-runners-<id>-runner-<id>`, reported runner version `2.336.0`, and completed successfully.

## Troubleshooting the AKS Automatic-specific bits

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

Pinning is required, but the pinned version still needs to be current. If the runner logs show:

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

That's it. Once the Automatic-friendly values are in place, ARC can scale an ephemeral runner, pick up a queued GitHub Actions job, and run it successfully on AKS Automatic.
