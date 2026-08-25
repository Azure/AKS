#!/usr/bin/env bash
# submit.sh — generic workload submitter for Kueue + Ray on AKS examples.
#
# Usage:
#   source env.example              # set required variables
#   export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
#   ./submit.sh [--dry-run]
#
# What it does:
#   1. Creates (or updates) a ConfigMap containing the workload Python script.
#   2. Renders rayjob.yaml.tmpl via envsubst and applies it to the cluster.
#
# The RayJob starts with suspend: true so Kueue controls admission.
# Watch progress with:
#   kubectl -n ray get rayjobs
#   kubectl -n ray get workloads

set -euo pipefail

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN="--dry-run=client"
fi

# ---- Validate required variables ----
: "${SCRIPT_FILE:?SCRIPT_FILE must be set to the path of the Python script}"
: "${CONFIGMAP_NAME:?CONFIGMAP_NAME must be set}"
: "${JOB_NAME:?JOB_NAME must be set}"
: "${QUEUE_NAME:?QUEUE_NAME must be set (e.g. default, team-a, team-b)}"
: "${RAY_IMAGE:?RAY_IMAGE must be set}"
: "${RAY_VERSION:?RAY_VERSION must be set}"
: "${NUM_WORKERS:?NUM_WORKERS must be set}"
: "${GPUS_PER_WORKER:?GPUS_PER_WORKER must be set}"
: "${ENTRYPOINT:?ENTRYPOINT must be set}"
: "${PIP_PACKAGES:?PIP_PACKAGES must be set (newline-separated pip install lines, indented 6 spaces)}"
: "${AZURE_STORAGE_ACCOUNT_NAME:?AZURE_STORAGE_ACCOUNT_NAME must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPL="${SCRIPT_DIR}/manifests/rayjob.yaml.tmpl"

# ---- Step 1: create/update the ConfigMap ----
echo "→ Applying ConfigMap ${CONFIGMAP_NAME} from ${SCRIPT_FILE} ..."
kubectl create configmap "${CONFIGMAP_NAME}" \
  --from-file="$(basename "${SCRIPT_FILE}")=${SCRIPT_FILE}" \
  --namespace ray \
  --dry-run=client -o yaml \
  | kubectl apply ${DRY_RUN} -f -

# ---- Step 2: render template and apply RayJob ----
echo "→ Rendering ${TMPL} and submitting RayJob ${JOB_NAME} ..."
envsubst < "${TMPL}" | kubectl apply ${DRY_RUN} -f -

if [[ -z "${DRY_RUN}" ]]; then
  echo ""
  echo "✓ RayJob ${JOB_NAME} submitted. Monitor with:"
  echo "  kubectl -n ray get rayjob ${JOB_NAME} -w"
  echo "  kubectl -n ray get workload -w"
fi
