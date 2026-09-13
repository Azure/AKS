#!/usr/bin/env bash
# Print the Kueue, ProvisioningRequest, node pool, pod, and Job state as one timeline.

. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

start=$(date +%s)
last=""
printf '%-8s %-5s %-18s %-14s %-12s %-12s\n' "ELAPSED" "NODES" "WORKLOAD" "PROVISIONING" "SUSPENDED" "POD"

while true; do
  now=$(date +%s)
  elapsed=$((now - start))
  nodes=$(az aks nodepool show -g "$LAB_RESOURCE_GROUP" --cluster-name "$LAB_CLUSTER" \
    -n "$LAB_GPU_POOL" --query count -o tsv 2>/dev/null || echo "?")
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

  line="$nodes|$workload|$provisioning|$suspended|$pod"
  if [[ "$line" != "$last" ]]; then
    printf '%-8ss %-5s %-18s %-14s %-12s %-12s\n' \
      "$elapsed" "$nodes" "$workload" "$provisioning" "$suspended" "$pod"
    last="$line"
  fi

  complete=$(kubectl -n "$LAB_NAMESPACE" get job "$LAB_JOB" \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)
  failed=$(kubectl -n "$LAB_NAMESPACE" get job "$LAB_JOB" \
    -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || true)
  if [[ "$complete" == "True" ]]; then
    echo
    kubectl -n "$LAB_NAMESPACE" logs "job/$LAB_JOB"
    pass "End-to-end inference completed"
    exit 0
  fi
  [[ "$failed" != "True" ]] || fail "The inference Job failed. Run: kubectl -n $LAB_NAMESPACE describe job $LAB_JOB"
  (( elapsed < 2700 )) || fail "Timed out after 45 minutes. Continue with modules/07-observe-and-troubleshoot.md."
  sleep 10
done
