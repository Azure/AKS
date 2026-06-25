#!/usr/bin/env bash
# submit-service.sh — submitter for RayService (online-serving) workloads.
#
# RayService is NOT Kueue-admitted — it is a persistent deployment.
# Do NOT label RayService with kueue.x-k8s.io/queue-name.
#
# Usage:
#   source env.example
#   export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
#   ./submit-service.sh [--dry-run]
#
# Watch progress with:
#   kubectl -n ray get rayservice
#   kubectl -n ray get pods -l ray.io/is-ray-node=yes

set -euo pipefail

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN="--dry-run=client"
fi

# ---- Validate required variables ----
: "${SCRIPT_FILE:?SCRIPT_FILE must be set to the path of the Python script}"
: "${CONFIGMAP_NAME:?CONFIGMAP_NAME must be set}"
: "${SERVICE_NAME:?SERVICE_NAME must be set}"
: "${APP_NAME:?APP_NAME must be set}"
: "${ROUTE_PREFIX:?ROUTE_PREFIX must be set}"
: "${IMPORT_PATH:?IMPORT_PATH must be set}"
: "${RAY_IMAGE:?RAY_IMAGE must be set}"
: "${RAY_VERSION:?RAY_VERSION must be set}"
: "${PIP_PACKAGES:?PIP_PACKAGES must be set (newline-separated pip install lines, indented 6 spaces)}"
: "${AZURE_STORAGE_ACCOUNT_NAME:?AZURE_STORAGE_ACCOUNT_NAME must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPL="${SCRIPT_DIR}/manifests/rayservice.yaml.tmpl"

# ---- Step 1: create/update the ConfigMap ----
echo "→ Applying ConfigMap ${CONFIGMAP_NAME} from ${SCRIPT_FILE} ..."
kubectl create configmap "${CONFIGMAP_NAME}" \
  --from-file="$(basename "${SCRIPT_FILE}")=${SCRIPT_FILE}" \
  --namespace ray \
  --dry-run=client -o yaml \
  | kubectl apply ${DRY_RUN} -f -

# ---- Step 2: render template and apply RayService ----
echo "→ Rendering ${TMPL} and applying RayService ${SERVICE_NAME} ..."
envsubst < "${TMPL}" | kubectl apply ${DRY_RUN} -f -

if [[ -z "${DRY_RUN}" ]]; then
  echo ""
  echo "✓ RayService ${SERVICE_NAME} applied. Monitor with:"
  echo "  kubectl -n ray get rayservice ${SERVICE_NAME} -w"
  echo ""
  echo "Once Ready, access the endpoint:"
  echo "  kubectl -n ray port-forward svc/${SERVICE_NAME}-serve-svc 8000:8000"
  echo "  curl -X POST http://localhost:8000${ROUTE_PREFIX} -H 'Content-Type: application/json' \\"
  echo "    -d '{\"init_file\": \"init-2021-01-01-00z.npz\", \"lead_hours\": 6}'"
fi
