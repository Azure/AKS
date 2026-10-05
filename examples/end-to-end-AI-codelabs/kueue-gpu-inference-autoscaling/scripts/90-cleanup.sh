#!/usr/bin/env bash
# Remove either the GPU workload resources or the entire lab resource group.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ "${1:-}" == "--all" ]]; then
  step "Deleting resource group $LAB_RESOURCE_GROUP"
  resource_group_is_owned || fail "Refusing to delete $LAB_RESOURCE_GROUP: it isn't tagged $LAB_OWNER_TAG=$LAB_OWNER_VALUE."
  az group delete --name "$LAB_RESOURCE_GROUP" --yes --no-wait
  pass "Deletion started. Azure continues deleting resources in the background."
  exit 0
fi

step "Deleting inference workload and queue"
require_lab_context
resources=(
  "namespace/$LAB_NAMESPACE"
  "resourceflavor/gpu-inference"
  "provisioningrequestconfig/gpu-inference"
  "admissioncheck/gpu-inference-provisioning"
  "clusterqueue/gpu-inference-cluster-queue"
  "localqueue/$LAB_NAMESPACE/gpu-inference"
)
namespace_exists=false
for resource in "${resources[@]}"; do
  IFS=/ read -r kind namespace name <<<"$resource"
  if [[ -z "${name:-}" ]]; then
    name=$namespace
    namespace=""
  fi
  kubectl_args=(get "$kind" "$name")
  [[ -z "$namespace" ]] || kubectl_args+=(--namespace "$namespace")
  if kubectl "${kubectl_args[@]}" >/dev/null 2>&1; then
    owner=$(kubectl "${kubectl_args[@]}" \
      -o jsonpath="{.metadata.labels.$LAB_OWNER_TAG}" 2>/dev/null || true)
    [[ "$owner" == "$LAB_OWNER_VALUE" ]] || fail "Refusing cleanup: $kind/$name isn't owned by this codelab."
    [[ "$kind" != "namespace" ]] || namespace_exists=true
  fi
done

if [[ "$namespace_exists" == "true" ]]; then
  kubectl delete -f "$ROOT/manifests/inference-job.yaml" --ignore-not-found --wait=true
  for attempt in $(seq 1 60); do
    remaining=$({ kubectl -n "$LAB_NAMESPACE" get workloads,provisioningrequests \
      --no-headers 2>/dev/null || true; } | grep -c . || true)
    [[ "$remaining" == "0" ]] && break
    [[ "$attempt" != "60" ]] || fail "Kueue generated resources weren't removed within 2 minutes; queue cleanup stopped."
    sleep 2
  done
fi
# This also removes owned cluster-scoped objects after a partial cleanup where
# the namespace has already gone.
kubectl delete -f "$ROOT/manifests/kueue-gpu-queue.yaml" --ignore-not-found

pass "Deleted the workload and owned queue resources. The GPU pool can now scale to zero."

cat <<EOF

Watch the pool:
  az aks nodepool show -g $LAB_RESOURCE_GROUP --cluster-name $LAB_CLUSTER \\
    -n $LAB_GPU_POOL --query count -o tsv

Delete every lab resource when you finish:
  $ROOT/scripts/90-cleanup.sh --all
EOF
