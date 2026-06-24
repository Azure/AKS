#!/usr/bin/env bash
# Submit the batch-inference RayJob to Kueue.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.example" 2>/dev/null || true

# Check that the Python payload exists
if [[ ! -f "${SCRIPT_DIR}/batch_inference.py" ]]; then
  echo "❌ batch_inference.py not found in ${SCRIPT_DIR}."
  exit 1
fi

DRY_RUN=""
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN="--dry-run=client"

: "${AZURE_STORAGE_ACCOUNT_NAME:?Set AZURE_STORAGE_ACCOUNT_NAME (terraform output -raw storage_account_name)}"
: "${JOB_NAME:?Set JOB_NAME}"

echo "→ Applying ConfigMap ${CONFIGMAP_NAME} ..."
kubectl create configmap "${CONFIGMAP_NAME}" \
  --from-file=batch_inference.py="${SCRIPT_DIR}/batch_inference.py" \
  --namespace ray \
  --dry-run=client -o yaml \
  | kubectl apply ${DRY_RUN} -f -

echo "→ Submitting RayJob ${JOB_NAME} to queue '${QUEUE_NAME}' ..."
envsubst < "${SCRIPT_DIR}/manifests/rayjob.yaml.tmpl" | kubectl apply ${DRY_RUN} -f -

[[ -z "${DRY_RUN}" ]] && echo "✓ Done. Watch: kubectl -n ray get rayjob ${JOB_NAME} -w"
