#!/usr/bin/env bash
# Deploy the Aurora RayService (online serving).
# RayService is NOT admission-controlled by Kueue — no queue label is needed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.example"

DRY_RUN=""
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN="--dry-run=client"

: "${AZURE_STORAGE_ACCOUNT_NAME:?Set AZURE_STORAGE_ACCOUNT_NAME}"
: "${AURORA_RUN_ID:?Set AURORA_RUN_ID to the JOB_NAME from your aurora-finetune run}"
: "${SERVICE_NAME:?Set SERVICE_NAME}"

echo "→ Applying ConfigMap ${CONFIGMAP_NAME} ..."
kubectl create configmap "${CONFIGMAP_NAME}" \
  --from-file=aurora_serve.py="${SCRIPT_DIR}/aurora_serve.py" \
  --namespace ray \
  --dry-run=client -o yaml \
  | kubectl apply ${DRY_RUN} -f -

echo "→ Applying RayService ${SERVICE_NAME} ..."
# MSYS_NO_PATHCONV: Git Bash on Windows converts POSIX strings like "/aurora"
# into Windows paths. No-op on Linux/macOS.
MSYS_NO_PATHCONV=1 envsubst < "${SCRIPT_DIR}/manifests/rayservice.yaml.tmpl" | kubectl apply ${DRY_RUN} -f -

if [[ -z "${DRY_RUN}" ]]; then
  echo "✓ Done. Watch: kubectl -n ray get rayservice ${SERVICE_NAME} -w"
  echo ""
  echo "Once Running, access the endpoint:"
  echo "  kubectl -n ray port-forward svc/${SERVICE_NAME}-serve-svc 8000:8000"
  echo "  curl -X POST http://localhost:8000${ROUTE_PREFIX} \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"init_file\": \"init-2021-01-01-00z.npz\", \"lead_hours\": 6}'"
fi
