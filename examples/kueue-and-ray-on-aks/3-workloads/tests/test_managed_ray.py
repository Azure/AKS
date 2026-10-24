"""Offline managed-Ray regression checks. No cluster or model calls are made."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import yaml

WORKLOADS = Path(__file__).resolve().parents[1]
BATCH = ("aurora-finetune", "llm-training", "batch-inference")


def environment(**extra):
    return dict(os.environ, AZURE_STORAGE_ACCOUNT_NAME="fixturestorage",
                AURORA_RUN_ID="fixture-aurora-run", JOB_NAME="fixture-job",
                SERVICE_NAME="fixture-service", **extra)


def render(folder):
    directory = WORKLOADS / folder
    result = subprocess.check_output(
        ["bash", "-c", 'source env.example; envsubst < manifests/rayjob.yaml.tmpl'],
        cwd=directory, env=environment(), text=True,
    )
    return yaml.safe_load(result)


@unittest.skipUnless(shutil.which("envsubst"), "Install GNU envsubst (gettext)")
class ManagedRayTest(unittest.TestCase):
    def test_batch_submitters_supply_python_alias_without_replacing_generated_command(self):
        for folder in BATCH:
            with self.subTest(folder=folder):
                job = render(folder)
                pod = job["spec"]["submitterPodTemplate"]["spec"]
                submitter = pod["containers"][0]
                self.assertNotIn("command", submitter)
                self.assertNotIn("args", submitter)
                self.assertEqual(pod["volumes"], [{"name": "python-compat", "emptyDir": {}}])
                self.assertEqual(submitter["volumeMounts"], [{
                    "name": "python-compat", "mountPath": "/usr/local/bin/python",
                    "subPath": "python", "readOnly": True,
                }])
                self.assertEqual(pod["initContainers"][0]["image"], submitter["image"])
                self.assertTrue(job["spec"]["suspend"])
                self.assertEqual(job["spec"]["rayClusterSpec"]["rayVersion"], "2.55.1")

    def test_python_alias_preserves_arguments(self):
        for folder in BATCH:
            with self.subTest(folder=folder), tempfile.TemporaryDirectory() as temporary:
                init = render(folder)["spec"]["submitterPodTemplate"]["spec"]["initContainers"][0]
                command = list(init["command"])
                command[-1] = command[-1].replace("/python-compat", temporary)
                subprocess.run(command, check=True, timeout=10)
                output = subprocess.check_output(
                    [str(Path(temporary) / "python"), "-c", 'print("GCS health-check arguments preserved")'],
                    text=True, timeout=10,
                )
                self.assertEqual(output.strip(), "GCS health-check arguments preserved")

    def test_client_dry_run_returns_success_without_a_cluster(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            kubectl = directory / "kubectl"
            kubectl.write_text(f"#!{sys.executable}\n" + '''
import sys
args = sys.argv[1:]
assert "--dry-run=client" in args, "Only client dry-run operations are allowed"
if args[0] == "create":
    print("apiVersion: v1\\nkind: ConfigMap\\nmetadata: {name: fixture}")
elif args[0] == "apply":
    assert sys.stdin.read(), "Expected rendered YAML on stdin"
else:
    raise SystemExit("Unexpected kubectl operation")
''')
            kubectl.chmod(0o700)
            for folder in (*BATCH, "online-serving"):
                with self.subTest(folder=folder):
                    script = "submit-service.sh" if folder == "online-serving" else "submit.sh"
                    env = environment(PATH=str(directory) + os.pathsep + os.environ["PATH"])
                    result = subprocess.run(
                        ["bash", script, "--dry-run"], cwd=WORKLOADS / folder,
                        env=env, text=True, capture_output=True, timeout=30,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
