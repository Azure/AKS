#!/usr/bin/env bash
# Submit the aurora-finetune RayJob to Kueue.
# Usage:
#   source env.example
#   export AZURE_STORAGE_ACCOUNT_NAME=$(terraform -chdir=../../1-infrastructure/terraform output -raw storage_account_name)
#   ./submit.sh [--dry-run]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.example"

# Check that the Python payload exists
if [[ ! -f "${SCRIPT_DIR}/aurora_finetune.py" ]]; then
  echo "❌ aurora_finetune.py not found next to submit.sh."
  echo "   You can validate the template with: ./submit.sh --dry-run"
  exit 1
fi

DRY_RUN=""
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN="--dry-run=client"

: "${AZURE_STORAGE_ACCOUNT_NAME:?Set AZURE_STORAGE_ACCOUNT_NAME (terraform output -raw storage_account_name)}"
: "${JOB_NAME:?Set JOB_NAME}"

echo "→ Applying ConfigMap ${CONFIGMAP_NAME} ..."
kubectl create configmap "${CONFIGMAP_NAME}" \
  --from-file=aurora_finetune.py="${SCRIPT_DIR}/aurora_finetune.py" \
  --namespace ray \
  --dry-run=client -o yaml \
  | kubectl apply ${DRY_RUN} -f -

echo "→ Submitting RayJob ${JOB_NAME} to queue '${QUEUE_NAME}' ..."
envsubst < "${SCRIPT_DIR}/manifests/rayjob.yaml.tmpl" | kubectl apply ${DRY_RUN} -f -

[[ -z "${DRY_RUN}" ]] && echo "✓ Done. Watch: kubectl -n ray get rayjob ${JOB_NAME} -w"
