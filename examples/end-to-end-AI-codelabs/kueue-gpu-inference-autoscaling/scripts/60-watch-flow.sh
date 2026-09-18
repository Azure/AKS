#!/usr/bin/env bash
# Print the Kueue, ProvisioningRequest, node pool, pod, and Job state as one timeline.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
require_lab_context

stop_workload() {
  kubectl -n "$LAB_NAMESPACE" delete job "$LAB_JOB" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

interrupted() {
  warn "Watcher interrupted; deleting the Job so it can't keep GPU nodes allocated."
  stop_workload
  exit 130
}
trap interrupted INT TERM

print_diagnostics() {
  echo
  echo "--- ProvisioningRequest ---"
  kubectl -n "$LAB_NAMESPACE" describe provisioningrequest 2>/dev/null || true
  echo
  echo "--- Pending pod ---"
  kubectl -n "$LAB_NAMESPACE" describe pod -l job-name="$LAB_JOB" 2>/dev/null || true
  echo
  echo "--- Cluster autoscaler status ---"
  kubectl -n kube-system get configmap cluster-autoscaler-status \
    -o jsonpath='{.data.status}' 2>/dev/null || true
}

start=$(date +%s)
last=""
printf '%-8s %-5s %-5s %-18s %-14s %-10s %-12s\n' \
  "ELAPSED" "POOL" "READY" "WORKLOAD" "PROVISIONING" "SUSPENDED" "POD"

while true; do
  now=$(date +%s)
  elapsed=$((now - start))
  elapsed_label="${elapsed}s"
  pool_count=$(az aks nodepool show -g "$LAB_RESOURCE_GROUP" --cluster-name "$LAB_CLUSTER" \
    -n "$LAB_GPU_POOL" --query count -o tsv 2>/dev/null || echo "?")
  ready_nodes=$({ kubectl get nodes -l "agentpool=$LAB_GPU_POOL" --no-headers 2>/dev/null || true; } \
    | awk '$2 == "Ready" {count++} END {print count+0}')
  workload=$(kubectl -n "$LAB_NAMESPACE" get workload \
    -o jsonpath='{.items[0].status.conditions[?(@.type=="Admitted")].status}' \
    2>/dev/null || true)
  [[ -n "$workload" ]] || workload="Pending"
  provisioning=$(kubectl -n "$LAB_NAMESPACE" get provisioningrequest \
    -o jsonpath='{.items[0].status.conditions[?(@.type=="Provisioned")].status}' \
    2>/dev/null || true)
  [[ -n "$provisioning" ]] || provisioning="Pending"
  suspended=$(kubectl -n "$LAB_NAMESPACE" get job "$LAB_JOB" \
    -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "?")
  pod=$(kubectl -n "$LAB_NAMESPACE" get pod -l job-name="$LAB_JOB" \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  [[ -n "$pod" ]] || pod="NotCreated"

  line="$pool_count|$ready_nodes|$workload|$provisioning|$suspended|$pod"
  if [[ "$line" != "$last" ]]; then
    printf '%-8s %-5s %-5s %-18s %-14s %-10s %-12s\n' \
      "$elapsed_label" "$pool_count" "$ready_nodes" "$workload" "$provisioning" "$suspended" "$pod"
    last="$line"
  fi

  complete=$(kubectl -n "$LAB_NAMESPACE" get job "$LAB_JOB" \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)
  failed=$(kubectl -n "$LAB_NAMESPACE" get job "$LAB_JOB" \
    -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)
  if [[ "$complete" == "True" ]]; then
    echo
    expected=$(kubectl -n "$LAB_NAMESPACE" get job "$LAB_JOB" -o jsonpath='{.spec.completions}')
    validated=0
    while IFS= read -r pod_name; do
      echo "--- $pod_name ---"
      logs=$(kubectl -n "$LAB_NAMESPACE" logs "$pod_name")
      printf '%s\n' "$logs"
      if grep -q '^INFERENCE_VALIDATED$' <<<"$logs"; then
        validated=$((validated + 1))
      fi
    done < <(kubectl -n "$LAB_NAMESPACE" get pods -l job-name="$LAB_JOB" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    [[ "$validated" == "$expected" ]] || fail "$validated of $expected pods validated inference."
    pass "End-to-end inference completed in all $validated pods"
    exit 0
  fi
  if [[ "$failed" == "True" ]]; then
    print_diagnostics
    stop_workload
    fail "The inference Job failed; the Job was deleted to release GPU capacity."
  fi
  if (( elapsed >= 2700 )); then
    print_diagnostics
    stop_workload
    fail "Timed out after 45 minutes; the Job was deleted to release GPU capacity."
  fi
  sleep 10
done
