#!/usr/bin/env bash
# Run the same PyTorch DDP workload over TCP sockets and GPUDirect RDMA, then compare.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_command kubectl "Run: az aks install-cli"
require_command jq "Install jq."
require_command python3 "Install Python 3."
require_lab_context
ensure_lab_namespace
[[ "$LAB_GPU_PER_WORKER" == "1" ]] || fail "this codelab uses exactly one GPU on each of two nodes"
mkdir -p "$LAB_RESULTS_DIR"
rm -f "$LAB_RESULTS_DIR"/{tcp,rdma}.json "$LAB_RESULTS_DIR"/summary.{json,md} \
  "$LAB_RESULTS_DIR"/{tcp,rdma}-rank{0,1}.log

SELECTED_NODES=$(matching_gpu_nodes_json | jq -r --arg rdma "$LAB_RDMA_RESOURCE" '
  [.items[] | select(
    any(.status.conditions[]; .type=="Ready" and .status=="True") and
    ((.status.allocatable["nvidia.com/gpu"] // "0") as $gpu | $gpu != "0" and $gpu != "0m") and
    ((.status.allocatable[$rdma] // "0") as $rdmaQty | $rdmaQty != "0" and $rdmaQty != "0m")) |
    .metadata.name] | sort | .[]')
RANK0_NODE=$(printf '%s\n' "$SELECTED_NODES" | sed -n '1p')
RANK1_NODE=$(printf '%s\n' "$SELECTED_NODES" | sed -n '2p')
[[ -n "$RANK0_NODE" && -n "$RANK1_NODE" ]] || fail \
  "two Ready, labeled GPU+RDMA nodes are required"
pass "Both modes are pinned to $RANK0_NODE and $RANK1_NODE"

kubectl -n "$LAB_NAMESPACE" apply -f "$ROOT/manifests/gradient-sync-code.yaml"

run_mode() {
  local mode=$1 ib_disable=$2
  local rank0="gradient-${mode}-rank0" rank1="gradient-${mode}-rank1"
  local manifest="$LAB_RESULTS_DIR/gradient-${mode}.yaml"

  step "Running DDP gradient synchronization over $mode"
  kubectl -n "$LAB_NAMESPACE" delete jobs "$rank0" "$rank1" \
    --ignore-not-found --wait=true >/dev/null
  kubectl -n "$LAB_NAMESPACE" delete service "gradient-${mode}-master" \
    --ignore-not-found >/dev/null
  render_template "$ROOT/manifests/gradient-sync-run.yaml.tpl" "$manifest" \
    "MODE=$mode" \
    "NAMESPACE=$LAB_NAMESPACE" \
    "GPU_SKU=$LAB_GPU_SKU" \
    "NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_KEY" \
    "NODE_SELECTOR_VALUE=$LAB_NODE_SELECTOR_VALUE" \
    "RANK0_NODE=$RANK0_NODE" \
    "RANK1_NODE=$RANK1_NODE" \
    "RDMA_RESOURCE=$LAB_RDMA_RESOURCE" \
    "PYTORCH_IMAGE=$NVIDIA_PYTORCH_IMAGE" \
    "GRADIENT_MIB=$LAB_GRADIENT_MIB" \
    "WARMUP_STEPS=$LAB_WARMUP_STEPS" \
    "MEASURE_STEPS=$LAB_MEASURE_STEPS" \
    "IB_DISABLE=$ib_disable"
  kubectl apply -f "$manifest"
  wait_for_job "$rank0" 1800
  wait_for_job "$rank1" 1800

  local node0 node1
  node0=$(kubectl -n "$LAB_NAMESPACE" get pod -l "job-name=$rank0" \
    -o jsonpath='{.items[0].spec.nodeName}')
  node1=$(kubectl -n "$LAB_NAMESPACE" get pod -l "job-name=$rank1" \
    -o jsonpath='{.items[0].spec.nodeName}')
  [[ "$node0" == "$RANK0_NODE" && "$node1" == "$RANK1_NODE" ]] || fail \
    "$mode ranks ran on $node0 and $node1; expected $RANK0_NODE and $RANK1_NODE"

  kubectl -n "$LAB_NAMESPACE" logs "job/$rank0" --all-containers=true \
    >"$LAB_RESULTS_DIR/${mode}-rank0.log" 2>&1
  kubectl -n "$LAB_NAMESPACE" logs "job/$rank1" --all-containers=true \
    >"$LAB_RESULTS_DIR/${mode}-rank1.log" 2>&1

  local rank log
  for rank in 0 1; do
    log="$LAB_RESULTS_DIR/${mode}-rank${rank}.log"
    if [[ "$mode" == "rdma" ]]; then
      grep -Eq 'NET/IB.*GDRDMA' "$log" || fail \
        "NCCL rank $rank did not prove the combined IB/GPUDirect RDMA transport"
    else
      grep -q 'NET/Socket' "$log" || fail \
        "TCP rank $rank did not use NCCL's Socket transport"
      if grep -q 'GDRDMA' "$log"; then
        fail "TCP rank $rank unexpectedly used GPUDirect RDMA"
      fi
    fi
  done

  python3 - "$LAB_RESULTS_DIR/${mode}-rank0.log" "$node0" "$node1" \
    "$LAB_RESULTS_DIR/${mode}.json" <<'PY'
import json, sys
log_path, node0, node1, output = sys.argv[1:]
text = open(log_path).read()
marker = "APP_METRIC "
pos = text.find(marker)
if pos < 0:
    raise SystemExit(f"APP_METRIC was not found in {log_path}")
start = text.find("{", pos + len(marker))
metric, _ = json.JSONDecoder().raw_decode(text[start:])
metric["rank0_node"] = node0
metric["rank1_node"] = node1
open(output, "w").write(json.dumps(metric, indent=2, sort_keys=True) + "\n")
print("APP_METRIC " + json.dumps(metric, sort_keys=True))
PY
  pass "$mode run completed on $node0 and $node1"
}

# Run the control first so the RDMA result cannot benefit from being the only image-cold run.
run_mode tcp 1
run_mode rdma 0

step "Comparing application metrics"
python3 - "$LAB_RESULTS_DIR/tcp.json" "$LAB_RESULTS_DIR/rdma.json" \
  "$LAB_MIN_SPEEDUP" "$LAB_RESULTS_DIR/summary.json" "$LAB_RESULTS_DIR/summary.md" <<'PY'
import json, sys
tcp_path, rdma_path, minimum, json_out, md_out = sys.argv[1:]
tcp, rdma = json.load(open(tcp_path)), json.load(open(rdma_path))
speedup = tcp["avg_step_ms"] / rdma["avg_step_ms"]
throughput_gain = rdma["steps_per_second"] / tcp["steps_per_second"]
bandwidth_gain = rdma["effective_gradient_GBps"] / tcp["effective_gradient_GBps"]
summary = {
    "tcp": tcp,
    "rdma": rdma,
    "step_time_speedup": round(speedup, 2),
    "throughput_gain": round(throughput_gain, 2),
    "effective_bandwidth_gain": round(bandwidth_gain, 2),
    "minimum_required_speedup": float(minimum),
}
open(json_out, "w").write(json.dumps(summary, indent=2, sort_keys=True) + "\n")
markdown = f"""# RDMA training comparison\n\n| Transport | Average step | P95 step | Steps/s | Effective gradient bandwidth |\n|---|---:|---:|---:|---:|\n| TCP sockets | {tcp['avg_step_ms']:.3f} ms | {tcp['p95_step_ms']:.3f} ms | {tcp['steps_per_second']:.3f} | {tcp['effective_gradient_GBps']:.3f} GB/s |\n| GPUDirect RDMA | {rdma['avg_step_ms']:.3f} ms | {rdma['p95_step_ms']:.3f} ms | {rdma['steps_per_second']:.3f} | {rdma['effective_gradient_GBps']:.3f} GB/s |\n\nRDMA reduced distributed step time by **{speedup:.2f}x** and increased step throughput by **{throughput_gain:.2f}x**.\n"""
open(md_out, "w").write(markdown)
print(markdown)
if speedup < float(minimum):
    raise SystemExit(f"RDMA speedup {speedup:.2f}x is below required {float(minimum):.2f}x")
PY
pass "NCCL logs prove NET/Socket for the control and NET/IB/.../GDRDMA for the accelerated run"
pass "Results are in $LAB_RESULTS_DIR. Continue with modules/06-observe-results.md."
