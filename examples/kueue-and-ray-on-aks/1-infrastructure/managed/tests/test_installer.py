"""Exercise installer branching with fake CLIs, never an Azure/Kubernetes target."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

# Existing healthy extensions, but no shared ProvisioningRequest API. Unexpected
# operations fail, so the fixture cannot silently accept a create/delete/update.
CLI = r'''
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
name = Path(sys.argv[0]).name
with open(os.environ["CLI_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "az":
    if args[:2] == ["extension", "show"]:
        print("1.9.3")
    elif args[:2] == ["aks", "show"]:
        print(json.dumps({"id": "fixture", "state": "Succeeded", "version": "1.35.9"}))
    elif args[:2] == ["aks", "get-credentials"]:
        Path(os.environ["KUBECONFIG"]).touch()
    elif args[:2] == ["k8s-extension", "list"]:
        print(json.dumps([
            {"name": "aks-kueue", "extensionType": "microsoft.kueue", "state": "Succeeded"},
            {"name": "kuberay", "extensionType": "microsoft.kuberay", "state": "Succeeded"},
        ]))
    elif args[:2] == ["k8s-extension", "show"]:
        print("Succeeded" if args[args.index("--query") + 1] == "provisioningState" else "{}")
    else:
        raise SystemExit("Unexpected Azure operation: " + repr(args))
elif name == "kubectl":
    if args[:2] == ["get", "crd"]:
        raise SystemExit("Fixture has no ProvisioningRequest API")
    if args[0] == "get":
        print(json.dumps({"items": []}))
    elif args[0] not in ["wait", "rollout"]:
        raise SystemExit("Unexpected Kubernetes operation: " + repr(args))
'''


def run_fixture(*args):
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        for name in ("az", "kubectl"):
            executable = directory / name
            executable.write_text(f"#!{sys.executable}\n" + CLI)
            executable.chmod(0o700)
        env = dict(os.environ, SUBSCRIPTION_ID="fixture-subscription",
                   RESOURCE_GROUP="fixture-group", CLUSTER_NAME="fixture-cluster",
                   PYTHON_COMMAND=sys.executable,
                   MANAGED_STATE_DIR=str(directory / "state"),
                   CLI_LOG=str(directory / "calls.jsonl"),
                   PATH=str(directory) + os.pathsep + os.environ["PATH"])
        result = subprocess.run(["bash", str(ROOT / "install-extensions.sh"), *args],
                                env=env, text=True, capture_output=True, timeout=30)
        calls = [json.loads(line) for line in (directory / "calls.jsonl").read_text().splitlines()]
        return result, calls


class InstallerFixtureTest(unittest.TestCase):
    def test_ray_path_does_not_require_cpu_autoscaler_api(self):
        result, calls = run_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Managed operators are ready", result.stdout)
        self.assertNotIn("provisioningrequests.autoscaling.x-k8s.io", json.dumps(calls))

    def test_cpu_mode_fails_before_extension_operations_when_api_missing(self):
        result, calls = run_fixture("--with-cpu-autoscaling")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("before installing Kueue for the CPU demo", result.stderr)
        self.assertNotIn(["az", "k8s-extension", "create"], [call[:3] for call in calls])
        self.assertNotIn(["az", "k8s-extension", "show"], [call[:3] for call in calls])


if __name__ == "__main__":
    unittest.main()
