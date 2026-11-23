#!/usr/bin/env bash
# Print the measured application comparison and the transport evidence behind it.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_command jq "Install jq."
require_command python3 "Install Python 3."
[[ -f "$LAB_RESULTS_DIR/summary.json" ]] || fail \
  "no comparison results found; run scripts/40-run-training-comparison.sh first"
python3 - "$LAB_RESULTS_DIR/summary.json" <<'PY' || fail \
  "stored result does not meet its required RDMA speedup"
import json, sys
summary = json.load(open(sys.argv[1]))
measured = float(summary["tcp"]["avg_step_ms"]) / float(summary["rdma"]["avg_step_ms"])
required = float(summary["minimum_required_speedup"])
raise SystemExit(0 if measured >= required else 1)
PY

step "Application result"
cat "$LAB_RESULTS_DIR/summary.md"

step "NCCL transport evidence"
for rank in 0 1; do
  tcp_log="$LAB_RESULTS_DIR/tcp-rank${rank}.log"
  rdma_log="$LAB_RESULTS_DIR/rdma-rank${rank}.log"
  [[ -f "$tcp_log" && -f "$rdma_log" ]] || fail "rank $rank transport logs are missing"
  grep -q 'NET/Socket' "$tcp_log" || fail "Socket evidence is missing for rank $rank"
  ! grep -q 'GDRDMA' "$tcp_log" || fail "TCP rank $rank unexpectedly used GDRDMA"
  grep -Eq 'NET/IB.*GDRDMA' "$rdma_log" || fail \
    "combined IB/GPUDirect RDMA evidence is missing for rank $rank"
done
printf 'TCP control (rank 0):\n'
grep -m1 -E 'NET/Socket' "$LAB_RESULTS_DIR/tcp-rank0.log"
printf '\nGPUDirect RDMA (rank 0):\n'
grep -m1 -E 'NET/IB.*GDRDMA' "$LAB_RESULTS_DIR/rdma-rank0.log"

if [[ -f "$LAB_RESULTS_DIR/fabric.json" ]]; then
  step "InfiniBand fabric result"
  jq . "$LAB_RESULTS_DIR/fabric.json"
fi

step "Interpretation"
cat <<'EOF'
The two application runs use the same image, nodes, GPU count, gradient size,
and measured steps. NCCL_IB_DISABLE is the controlled variable: 1 forces the
Ethernet Socket baseline; 0 permits InfiniBand. A speedup is credited to RDMA
only when the logs also contain NET/IB/.../GDRDMA.
EOF
