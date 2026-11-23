#!/usr/bin/env bash
set -euo pipefail

# Install the managed operators on an explicitly selected, clean AKS target.
# Never installs Helm releases, changes another kubeconfig, or migrates operators.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

WITH_CPU_AUTOSCALING=0
while (( $# )); do
  case "$1" in
    --with-cpu-autoscaling) WITH_CPU_AUTOSCALING=1 ;;
    --help)
      printf '%s\n' \
        'Usage: install-extensions.sh [--with-cpu-autoscaling]' \
        'Required environment: SUBSCRIPTION_ID, RESOURCE_GROUP, CLUSTER_NAME.' \
        'Optional: MANAGED_STATE_DIR, PYTHON_COMMAND, WAIT_TIMEOUT_SECONDS.' \
        'Prerequisites: az with k8s-extension >=1.9.3, kubectl, Python >=3.9,' \
        'AKS >=1.34 and no self-hosted operators.' \
        '--with-cpu-autoscaling: require the CAS-owned ProvisioningRequest v1 API before Kueue starts.' \
        'The default Ray queue path needs no CPU autoscaler. Neither mode creates a pool or a shared CRD.' \
        'Uses preview managed extensions; never adopts or uninstalls an existing operator.'
      exit 0
      ;;
    *) printf 'Unknown argument. Use --help.\n' >&2; exit 2 ;;
  esac
  shift
done
: "${SUBSCRIPTION_ID:?Set the target subscription ID}"
: "${RESOURCE_GROUP:?Set the target resource group}"
: "${CLUSTER_NAME:?Set the target AKS cluster}"
PYTHON_COMMAND=${PYTHON_COMMAND:-python3}
WAIT_TIMEOUT_SECONDS=${WAIT_TIMEOUT_SECONDS:-1200}
[[ "$WAIT_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || { printf 'Invalid wait timeout.\n' >&2; exit 2; }
for command in az kubectl "$PYTHON_COMMAND"; do
  command -v "$command" >/dev/null || { printf 'Missing prerequisite: %s\n' "$command" >&2; exit 2; }
done
for value in "$SUBSCRIPTION_ID" "$RESOURCE_GROUP" "$CLUSTER_NAME"; do
  [[ "$value" != *'<'* && "$value" != *'>'* ]] || { printf 'Replace placeholder values first.\n' >&2; exit 2; }
done

umask 077
STATE_DIR=${MANAGED_STATE_DIR:-"$SCRIPT_DIR/.managed"}
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
STATE_DIR=$(cd "$STATE_DIR" && pwd)
export KUBECONFIG="$STATE_DIR/kubeconfig"

cli_version=$(az extension show --name k8s-extension --query version --output tsv)
"$PYTHON_COMMAND" - "$cli_version" <<'PY'
import re
import sys
parts = re.match(r"^(\d+)\.(\d+)\.(\d+)", sys.argv[1])
if parts is None or tuple(map(int, parts.groups())) < (1, 9, 3):
    raise SystemExit("Update the CLI extension first: az extension add --name k8s-extension --upgrade")
PY

# Explicit subscription arguments avoid changing the CLI's global selection.
az aks show --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --query '{id:id,state:provisioningState,version:currentKubernetesVersion}' \
  --output json > "$STATE_DIR/cluster.json"
"$PYTHON_COMMAND" - "$STATE_DIR/cluster.json" <<'PY'
import json
import re
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    cluster = json.load(stream)
version = re.match(r"^(\d+)\.(\d+)", cluster.get("version") or "")
if cluster["state"] != "Succeeded" or version is None or tuple(map(int, version.groups())) < (1, 34):
    raise SystemExit("Use a successfully provisioned AKS cluster running Kubernetes >=1.34")
PY
az aks get-credentials --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" --file "$KUBECONFIG" --overwrite-existing
chmod 600 "$KUBECONFIG"

extension_target=(--subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" --cluster-type managedClusters)
az k8s-extension list "${extension_target[@]}" \
  --query '[].{name:name,extensionType:extensionType,state:provisioningState}' \
  --output json > "$STATE_DIR/extensions.json"
"$PYTHON_COMMAND" "$SCRIPT_DIR/preflight.py" names --extensions "$STATE_DIR/extensions.json" > "$STATE_DIR/managed-names.json"

# Fail before extension creation: KubeRay preflight failure can otherwise touch CRDs.
kubectl get deployments --all-namespaces --output json --request-timeout=30s \
  | "$PYTHON_COMMAND" "$SCRIPT_DIR/preflight.py" deployments --extensions "$STATE_DIR/extensions.json"
kubectl get crds --output json --request-timeout=30s \
  | "$PYTHON_COMMAND" "$SCRIPT_DIR/preflight.py" crds --extensions "$STATE_DIR/extensions.json"

# CPU provisioning is optional for the fixed-quota Ray queues. If requested,
# its CAS-owned shared API must precede Kueue startup; never create the CRD here.
if (( WITH_CPU_AUTOSCALING )); then
  if ! kubectl get crd provisioningrequests.autoscaling.x-k8s.io --output json --request-timeout=30s > "$STATE_DIR/provisioning-api.json"; then
    printf 'Enable autoscaling on a node pool and wait for its shared ProvisioningRequest v1 API before installing Kueue for the CPU demo.\n' >&2
    exit 1
  fi
  kubectl wait --for=condition=Established crd/provisioningrequests.autoscaling.x-k8s.io --timeout=2m
  kubectl get crd provisioningrequests.autoscaling.x-k8s.io --output json --request-timeout=30s \
    | "$PYTHON_COMMAND" "$SCRIPT_DIR/preflight.py" provisioning-api --extensions "$STATE_DIR/extensions.json"
fi

ensure_extension() {
  local extension_type=$1 preferred_name=$2 namespace=$3 name versions state deadline
  name=$("$PYTHON_COMMAND" - "$STATE_DIR/managed-names.json" "$extension_type" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    print(json.load(stream).get(sys.argv[2], ""))
PY
)
  if [[ -z "$name" ]]; then
    name=$preferred_name
    versions=$(az k8s-extension extension-types list-versions-by-cluster \
      "${extension_target[@]}" --extension-type "$extension_type" \
      --release-train preview --output json)
    "$PYTHON_COMMAND" -c 'import json,sys; data=json.load(sys.stdin); sys.exit(0 if data else "No compatible preview package; stop instead of installing another controller")' <<< "$versions"
    printf 'Install managed extension %s as %s.\n' "$extension_type" "$name"
    az k8s-extension create "${extension_target[@]}" --name "$name" \
      --extension-type "$extension_type" --scope cluster \
      --release-namespace "$namespace" --release-train preview \
      --auto-upgrade-mode compatible --no-wait --output none
  else
    printf 'Keep existing managed extension %s (%s); no update or ownership transfer.\n' "$name" "$extension_type"
  fi
  deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    state=$(az k8s-extension show "${extension_target[@]}" --name "$name" \
      --query provisioningState --output tsv)
    case "$state" in
      Succeeded)
        az k8s-extension show "${extension_target[@]}" --name "$name" \
          --query '{name:name,type:extensionType,version:currentVersion,state:provisioningState}' --output json
        return 0
        ;;
      Failed|Canceled|Deleting)
        printf 'Extension %s is %s. Preserve its status/events and request support; do not uninstall as a workaround.\n' "$name" "$state" >&2
        return 1
        ;;
    esac
    sleep 15
  done
  printf 'Timed out observing %s. The server-side operation may still be active; inspect it before retrying.\n' "$name" >&2
  return 1
}

ensure_extension microsoft.kueue aks-kueue kueue-system
ensure_extension microsoft.kuberay kuberay kuberay-system
kubectl rollout status deployment/kueue-controller-manager --namespace kueue-system --timeout=5m
kubectl rollout status deployment/kueue-extension --namespace kueue-system --timeout=5m
kubectl rollout status deployment/kuberay-operator --namespace kuberay-system --timeout=5m
kubectl wait --for=condition=Established \
  crd/rayclusters.ray.io crd/rayjobs.ray.io crd/rayservices.ray.io \
  crd/clusterqueues.kueue.x-k8s.io crd/localqueues.kueue.x-k8s.io \
  --timeout=2m

# This file contains identifiers, not credentials; keep it private with kubeconfig.
{
  printf 'export SUBSCRIPTION_ID=%q\n' "$SUBSCRIPTION_ID"
  printf 'export RESOURCE_GROUP=%q\n' "$RESOURCE_GROUP"
  printf 'export CLUSTER_NAME=%q\n' "$CLUSTER_NAME"
  printf 'export KUBECONFIG=%q\n' "$KUBECONFIG"
} > "$STATE_DIR/managed.env"
chmod 600 "$STATE_DIR/managed.env"
printf 'Managed operators are ready. Continue with storage/identity setup, then source %s\n' "$STATE_DIR/managed.env"
printf 'For the CPU demo, verify aks-cpu and aks-provisioning-check before queue creation as documented in Module 2.\n'
