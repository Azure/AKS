#!/usr/bin/env bash
# Create shared model storage and stage the verified model checkpoint.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

require_lab_context

get_succeeded_stage_pod() {
  kubectl get pods \
    --namespace "$LAB_NAMESPACE" \
    -l job-name=stage-model \
    -o json |
    python3 -c '
import json
import sys

pods = json.load(sys.stdin).get("items", [])
succeeded = [
    pod
    for pod in pods
    if pod.get("status", {}).get("phase") == "Succeeded"
]
if succeeded:
    succeeded.sort(
        key=lambda pod: pod.get("status", {}).get("startTime", ""),
        reverse=True,
    )
    print(succeeded[0]["metadata"]["name"])
'
}

step "Checking object ownership"
require_owned_object_or_absent namespace "$LAB_NAMESPACE"
require_owned_object_or_absent storageclass "$LAB_STORAGE_CLASS"
require_owned_object_or_absent persistentvolumeclaim model-weights "$LAB_NAMESPACE"
require_owned_object_or_absent job stage-model "$LAB_NAMESPACE"

step "Creating shared model storage"
kubectl apply -f "$ROOT/manifests/namespace.yaml" >/dev/null
kubectl apply -f "$ROOT/manifests/model-storage.yaml" >/dev/null

if ! kubectl wait \
  --namespace "$LAB_NAMESPACE" \
  --for=jsonpath='{.status.phase}'=Bound \
  persistentvolumeclaim/model-weights \
  --timeout=300s \
  >/dev/null 2>&1; then
  kubectl describe persistentvolumeclaim model-weights --namespace "$LAB_NAMESPACE"
  fail "The model volume didn't bind within 5 minutes."
fi
pass "The shared model volume is bound"

step "Staging $LAB_MODEL_ID"
if kubectl get job stage-model --namespace "$LAB_NAMESPACE" >/dev/null 2>&1; then
  if [[ "$(kubectl get job stage-model --namespace "$LAB_NAMESPACE" \
    -o jsonpath='{.status.succeeded}' 2>/dev/null || true)" == "1" ]]; then
    SUCCEEDED_POD=$(get_succeeded_stage_pod)
    [[ -n "$SUCCEEDED_POD" ]] &&
      kubectl logs "$SUCCEEDED_POD" --namespace "$LAB_NAMESPACE" |
      grep -q "MODEL_READY" &&
      pass "The model is already staged and verified" &&
      exit 0
  fi
  kubectl delete job stage-model \
    --namespace "$LAB_NAMESPACE" \
    --wait=true \
    >/dev/null
fi

kubectl apply -f "$ROOT/manifests/model-stage-job.yaml" >/dev/null
if ! kubectl wait \
  --namespace "$LAB_NAMESPACE" \
  --for=condition=complete \
  job/stage-model \
  --timeout=3600s \
  >/dev/null 2>&1; then
  kubectl describe job stage-model --namespace "$LAB_NAMESPACE"
  kubectl logs job/stage-model --namespace "$LAB_NAMESPACE" || true
  fail "Model staging didn't complete within 60 minutes."
fi

SUCCEEDED_POD=$(get_succeeded_stage_pod)
[[ -n "$SUCCEEDED_POD" ]] ||
  fail "The staging Job completed without a succeeded pod."
kubectl logs "$SUCCEEDED_POD" --namespace "$LAB_NAMESPACE" |
  grep -q "MODEL_READY" ||
  fail "The staging Job completed without the model verification marker."
pass "The model is staged and verified"
