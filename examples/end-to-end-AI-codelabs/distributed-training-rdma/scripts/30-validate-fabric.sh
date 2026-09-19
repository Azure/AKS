#!/usr/bin/env bash
# Prove that two distinct nodes have active IB links and measure verbs bandwidth/latency.

# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

require_command kubectl "Run: az aks install-cli"
require_command jq "Install jq."
require_command python3 "Install Python 3."
require_lab_context
ensure_lab_namespace
mkdir -p "$LAB_RESULTS_DIR"
rm -f "$LAB_RESULTS_DIR/fabric.json" "$LAB_RESULTS_DIR/ib-server.log" \
  "$LAB_RESULTS_DIR/ib-client.log"

step "Checking two Ready nodes with GPU and RDMA resources"
nodes=$(matching_gpu_nodes_json)
summary=$(jq --arg rdma "$LAB_RDMA_RESOURCE" '[.items[] | {
  name: .metadata.name,
  ready: ([.status.conditions[] | select(.type=="Ready")][0].status // "False"),
  gpu: (.status.allocatable["nvidia.com/gpu"] // "0" | tonumber),
  rdma: (.status.allocatable[$rdma] // "0" | tonumber)
}]' <<<"$nodes")
printf '%s\n' "$summary"
good=$(jq '[.[] | select(.ready=="True" and .gpu>0 and .rdma>0)] | length' <<<"$summary")
(( good >= 2 )) || fail "two Ready $LAB_GPU_SKU nodes must advertise nvidia.com/gpu and $LAB_RDMA_RESOURCE"
pass "$good matching nodes expose both resources"

step "Running cross-node ib_read_lat and ib_write_bw"
kubectl -n "$LAB_NAMESPACE" delete jobs ib-benchmark-server ib-benchmark-client \
  --ignore-not-found --wait=true >/dev/null
kubectl -n "$LAB_NAMESPACE" delete service ib-benchmark-server \
  --ignore-not-found >/dev/null
TMP_MANIFEST=$(mktemp)
trap 'rm -f "$TMP_MANIFEST"' EXIT
render_template "$ROOT/manifests/ib-benchmark.yaml.tpl" "$TMP_MANIFEST" \
  "NAMESPACE=$LAB_NAMESPACE" \
  "GPU_SKU=$LAB_GPU_SKU" \
  "NODE_SELECTOR_KEY=$LAB_NODE_SELECTOR_KEY" \
  "NODE_SELECTOR_VALUE=$LAB_NODE_SELECTOR_VALUE" \
  "RDMA_RESOURCE=$LAB_RDMA_RESOURCE" \
  "PYTORCH_IMAGE=$NVIDIA_PYTORCH_IMAGE"
kubectl apply -f "$TMP_MANIFEST"
wait_for_job ib-benchmark-client 1200
wait_for_job ib-benchmark-server 1200

server_node=$(kubectl -n "$LAB_NAMESPACE" get pod -l job-name=ib-benchmark-server \
  -o jsonpath='{.items[0].spec.nodeName}')
client_node=$(kubectl -n "$LAB_NAMESPACE" get pod -l job-name=ib-benchmark-client \
  -o jsonpath='{.items[0].spec.nodeName}')
[[ -n "$server_node" && -n "$client_node" && "$server_node" != "$client_node" ]] || fail \
  "IB peers must run on distinct nodes; got server=$server_node client=$client_node"

kubectl -n "$LAB_NAMESPACE" logs job/ib-benchmark-server --all-containers=true \
  >"$LAB_RESULTS_DIR/ib-server.log"
kubectl -n "$LAB_NAMESPACE" logs job/ib-benchmark-client --all-containers=true \
  >"$LAB_RESULTS_DIR/ib-client.log"
cat "$LAB_RESULTS_DIR/ib-client.log"

METRIC=$(python3 - "$LAB_RESULTS_DIR/ib-server.log" "$LAB_RESULTS_DIR/ib-client.log" \
  "$server_node" "$client_node" <<'PY'
import json, re, sys
server_path, client_path, server_node, client_node = sys.argv[1:]
server = open(server_path).read()
client = open(client_path).read()
if "Link layer: InfiniBand" not in server and "Link layer       : InfiniBand" not in server:
    raise SystemExit("server HCA did not report the InfiniBand link layer")
if "State: Active" not in server:
    raise SystemExit("server HCA did not report State: Active")
section = None
latency = bandwidth = None
for raw in client.splitlines():
    line = raw.strip()
    if line == "BEGIN_IB_READ_LAT":
        section = "latency"
        continue
    if line == "BEGIN_IB_WRITE_BW":
        section = "bandwidth"
        continue
    fields = line.split()
    try:
        if section == "latency" and len(fields) >= 6 and fields[0] == "2":
            latency = float(fields[5])
        if section == "bandwidth" and len(fields) >= 5 and fields[0] == "8388608":
            # Zero-based fields: bytes, iterations, peak, average, message rate.
            bandwidth = float(fields[3])
    except ValueError:
        pass
if latency is None or bandwidth is None:
    raise SystemExit(f"could not parse perftest output (latency={latency}, bandwidth={bandwidth})")
rate = re.search(r"Rate:\s*([0-9.]+)", server)
hca = re.search(r"IB_DEVICE=([^\s]+)", client)
print(json.dumps({
    "server_node": server_node,
    "client_node": client_node,
    "hca": hca.group(1) if hca else "unknown",
    "link_rate_gbps": float(rate.group(1)) if rate else None,
    "read_latency_us": latency,
    "write_bandwidth_gbps": bandwidth,
}, sort_keys=True))
PY
) || fail "$METRIC"
printf '%s\n' "$METRIC" >"$LAB_RESULTS_DIR/fabric.json"
printf 'FABRIC_METRIC %s\n' "$METRIC"

IB_BW=$(jq -r '.write_bandwidth_gbps' <<<"$METRIC")
IB_LATENCY=$(jq -r '.read_latency_us' <<<"$METRIC")
python3 - "$IB_BW" "$LAB_MIN_IB_GBPS" "$IB_LATENCY" "$LAB_MAX_IB_LATENCY_US" <<'PY' || fail \
  "IB result missed a performance floor (bandwidth >= $LAB_MIN_IB_GBPS Gb/s, latency <= $LAB_MAX_IB_LATENCY_US us)"
import sys
bandwidth, min_bandwidth, latency, max_latency = map(float, sys.argv[1:])
raise SystemExit(0 if bandwidth >= min_bandwidth and latency <= max_latency else 1)
PY
pass "InfiniBand is active across $server_node and $client_node at $IB_BW Gb/s and $IB_LATENCY us"
pass "Continue with modules/05-run-training-comparison.md."
