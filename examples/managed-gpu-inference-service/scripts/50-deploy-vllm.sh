#!/usr/bin/env bash
# Deploy two vLLM replicas and validate one OpenAI-compatible request.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

require_lab_context

step "Checking object ownership"
require_owned_object_or_absent namespace "$LAB_NAMESPACE"
for kind_name in \
  "serviceaccount vllm" \
  "deployment vllm" \
  "service vllm" \
  "poddisruptionbudget vllm"; do
  read -r kind name <<<"$kind_name"
  require_owned_object_or_absent "$kind" "$name" "$LAB_NAMESPACE"
done

[[ "$(kubectl get job stage-model --namespace "$LAB_NAMESPACE" \
  -o jsonpath='{.status.succeeded}' 2>/dev/null || true)" == "1" ]] ||
  fail "The model staging Job isn't complete. Run 40-stage-model.sh first."

step "Deploying vLLM"
kubectl apply -f "$ROOT/manifests/vllm-serving.yaml" >/dev/null

if ! kubectl rollout status \
  deployment/vllm \
  --namespace "$LAB_NAMESPACE" \
  --timeout=3600s; then
  kubectl get pods --namespace "$LAB_NAMESPACE" -o wide
  kubectl describe pod \
    --namespace "$LAB_NAMESPACE" \
    -l app.kubernetes.io/name=vllm
  kubectl logs \
    --namespace "$LAB_NAMESPACE" \
    -l app.kubernetes.io/name=vllm \
    --all-containers \
    --tail=100 || true
  fail "The vLLM rollout didn't complete within 60 minutes."
fi

NODES=$(kubectl get pods \
  --namespace "$LAB_NAMESPACE" \
  -l app.kubernetes.io/name=vllm \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' |
  sort -u |
  grep -c . || true)
[[ "$NODES" == "2" ]] || fail "The two replicas aren't running on separate nodes."
pass "Two vLLM replicas are ready on separate GPU nodes"

step "Sending an inference request"
PROBE_NAME="vllm-request"
require_owned_object_or_absent pod "$PROBE_NAME" "$LAB_NAMESPACE"
kubectl delete pod "$PROBE_NAME" \
  --namespace "$LAB_NAMESPACE" \
  --ignore-not-found \
  --wait=true \
  >/dev/null

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: $PROBE_NAME
  namespace: $LAB_NAMESPACE
  labels:
    app.kubernetes.io/name: vllm-request
    app.kubernetes.io/part-of: managed-gpu-inference-service
    $LAB_OWNER_LABEL: $LAB_OWNER_VALUE
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  enableServiceLinks: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: request
      image: mcr.microsoft.com/azurelinux/base/core:3.0
      command:
        - /bin/sh
        - -c
        - |
          curl --fail-with-body --silent --max-time 120 \
            http://vllm:8000/v1/chat/completions \
            -H 'Content-Type: application/json' \
            -d '{"model":"qwen","messages":[{"role":"user","content":"Reply with exactly: AKS GPU service online."}],"max_tokens":16,"temperature":0}'
      resources:
        requests:
          cpu: 25m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
EOF

if ! kubectl wait \
  --namespace "$LAB_NAMESPACE" \
  --for=jsonpath='{.status.phase}'=Succeeded \
  "pod/$PROBE_NAME" \
  --timeout=180s \
  >/dev/null 2>&1; then
  kubectl describe pod "$PROBE_NAME" --namespace "$LAB_NAMESPACE"
  kubectl logs "$PROBE_NAME" --namespace "$LAB_NAMESPACE" || true
  fail "The inference request failed."
fi

RESPONSE=$(kubectl logs "$PROBE_NAME" --namespace "$LAB_NAMESPACE")
RESPONSE_TEXT=$(python3 - "$RESPONSE" 2>&1 <<'PY'
import json
import sys

response = json.loads(sys.argv[1])
text = response["choices"][0]["message"]["content"]
if "AKS GPU service online" not in text:
    raise SystemExit(f"Unexpected response: {text!r}")
print(text)
PY
) || fail "Inference response validation failed: $RESPONSE_TEXT"
printf '%s\n' "$RESPONSE_TEXT"
kubectl delete pod "$PROBE_NAME" \
  --namespace "$LAB_NAMESPACE" \
  --wait=true \
  >/dev/null
pass "Inference request completed"
