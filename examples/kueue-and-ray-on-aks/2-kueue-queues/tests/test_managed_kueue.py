"""Offline contract checks for the managed Kueue examples; no cluster access."""

from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest

import yaml


MODULE = Path(__file__).resolve().parents[1]
EXAMPLES = MODULE.parent


def objects(path):
    return [item for item in yaml.safe_load_all(path.read_text()) if item]


class ManagedKueueExamplesTest(unittest.TestCase):
    def setUp(self):
        self.queue_objects = objects(MODULE / "manifests/40-autoscale-queue.yaml")
        self.by_kind = {item["kind"]: item for item in self.queue_objects}
        self.job = objects(
            EXAMPLES / "3-workloads/cas-batch-job/manifests/job.yaml"
        )[0]

    def test_autoscale_manifest_owns_only_demo_namespace_and_queues(self):
        self.assertEqual(len(self.queue_objects), 3)
        self.assertEqual(set(self.by_kind), {"Namespace", "ClusterQueue", "LocalQueue"})
        self.assertEqual(self.by_kind["Namespace"]["metadata"]["name"], "cas-kueue-demo")
        for item in self.queue_objects:
            self.assertFalse(item["metadata"]["name"].startswith("aks-"))

    def test_queue_references_existing_managed_flavor_and_admission_check(self):
        spec = self.by_kind["ClusterQueue"]["spec"]
        self.assertEqual(spec["resourceGroups"][0]["flavors"][0]["name"], "aks-cpu")
        self.assertEqual(
            spec["admissionChecksStrategy"]["admissionChecks"],
            [{"name": "aks-provisioning-check", "onFlavors": ["aks-cpu"]}],
        )

    def test_job_queue_namespace_and_pool_selector_match(self):
        local_queue = self.by_kind["LocalQueue"]
        self.assertEqual(
            local_queue["spec"]["clusterQueue"],
            self.by_kind["ClusterQueue"]["metadata"]["name"],
        )
        self.assertEqual(self.job["metadata"]["namespace"], local_queue["metadata"]["namespace"])
        self.assertEqual(
            self.job["metadata"]["labels"]["kueue.x-k8s.io/queue-name"],
            local_queue["metadata"]["name"],
        )
        self.assertIs(self.job["spec"]["suspend"], True)
        self.assertEqual(
            self.job["spec"]["template"]["spec"]["nodeSelector"]["agentpool"],
            "scalepool",
        )

    def test_managed_prerequisites_precede_queue_apply(self):
        guide = (MODULE / "README.md").read_text()
        apply = guide.index("kubectl apply -f manifests/40-autoscale-queue.yaml")
        for check in (
            "deployment/kueue-controller-manager",
            "deployment/kueue-extension",
            "resourceflavor/aks-cpu",
            "admissioncheck/aks-provisioning-check",
        ):
            self.assertLess(guide.index(check), apply)

    def test_provisioned_capacity_does_not_imply_node_readiness(self):
        guide = (EXAMPLES / "3-workloads/cas-batch-job/README.md").read_text()
        prose = " ".join(guide.split())
        self.assertIn("A `Provisioned=True` condition doesn't guarantee `Ready` Kubernetes nodes", prose)
        self.assertIn("`aks-default` hostname topology can delay admission", prose)
        self.assertIn("not Kubernetes node readiness or simultaneous pod scheduling", prose)
        self.assertNotIn("admitted once nodes exist", guide)
        self.assertIn("Nodes aren't `Ready`, or a node label doesn't match", guide)
        self.assertIn('id="why-this-matters-no-wasted-spend-on-partial-capacity"', guide)

    def test_cpu_azure_mutations_are_explicitly_subscription_scoped(self):
        guide = (EXAMPLES / "3-workloads/cas-batch-job/README.md").read_text()
        commands = re.findall(
            r'^\s*az aks (?:nodepool (?:add|delete)|update)\b[^\n]*',
            guide.replace("\\\n", " "), re.MULTILINE,
        )
        self.assertEqual(len(commands), 3)
        for command in commands:
            self.assertIn('--subscription "$SUBSCRIPTION_ID"', command)

    def test_recommended_ray_policy_references_existing_managed_flavors(self):
        template = (MODULE / "manifests/15-managed-queue.yaml.tmpl").read_text()
        rendered = template.replace("${CPU_RESOURCE_FLAVOR}", "aks-cpu").replace(
            "${GPU_RESOURCE_FLAVOR}", "fixture-managed-gpu"
        )
        resources = [item for item in yaml.safe_load_all(rendered) if item]
        self.assertEqual({item["kind"] for item in resources}, {"ClusterQueue", "LocalQueue"})
        self.assertEqual(len(resources), 2)
        queue = next(item for item in resources if item["kind"] == "ClusterQueue")
        local = next(item for item in resources if item["kind"] == "LocalQueue")
        self.assertEqual(local["spec"]["clusterQueue"], queue["metadata"]["name"])
        self.assertEqual(queue["spec"]["namespaceSelector"]["matchLabels"],
                         {"kubernetes.io/metadata.name": local["metadata"]["namespace"]})
        groups = queue["spec"]["resourceGroups"]
        self.assertEqual(len(groups), 1)
        self.assertEqual(set(groups[0]["coveredResources"]), {"cpu", "memory", "nvidia.com/gpu"})
        self.assertEqual([item["name"] for item in groups[0]["flavors"]],
                         ["aks-cpu", "fixture-managed-gpu"])
        for flavor in groups[0]["flavors"]:
            self.assertEqual({r["name"] for r in flavor["resources"]},
                             {"cpu", "memory", "nvidia.com/gpu"})
        gpu_quota = next(r for r in groups[0]["flavors"][0]["resources"] if r["name"] == "nvidia.com/gpu")
        self.assertEqual(str(gpu_quota["nominalQuota"]), "0")

    def test_managed_policy_is_recommended_and_custom_flavors_are_optional(self):
        guide = (MODULE / "README.md").read_text()
        self.assertLess(guide.index("### Use managed Ray placement flavors"),
                        guide.index("### Optional custom placement and queue policies"))
        self.assertIn("manifests/15-managed-queue.yaml.tmpl", guide)
        custom = (MODULE / "manifests/10-resource-flavors.yaml").read_text()
        self.assertIn("OPTIONAL", custom)
        self.assertIn("managed Kueue/KubeRay", custom)
        self.assertIn("Prefer existing AKS-managed ResourceFlavors", custom)

    def test_manual_install_uses_one_owned_kubeconfig_not_inherited_list(self):
        guide = (MODULE / "README.md").read_text()
        line = next(value for value in guide.splitlines() if value.startswith("export KUBECONFIG="))
        self.assertEqual(line, 'export KUBECONFIG="$PWD/.managed/kubeconfig"')
        with tempfile.TemporaryDirectory() as temporary:
            value = subprocess.check_output(
                ["bash", "-c", line + '\nprintf "%s" "$KUBECONFIG"'],
                cwd=temporary, text=True,
                env=dict(os.environ, KUBECONFIG="/unrelated/first:/unrelated/second"),
            )
            self.assertEqual(Path(value).resolve(), (Path(temporary) / ".managed/kubeconfig").resolve())
            self.assertNotIn(":", value)
        self.assertIn('--file "$KUBECONFIG" --overwrite-existing', guide)

    def test_ray_flavors_remain_customer_owned(self):
        flavors = objects(MODULE / "manifests/10-resource-flavors.yaml")
        self.assertEqual({item["metadata"]["name"] for item in flavors}, {"default", "gpu"})
        self.assertTrue(all(item["kind"] == "ResourceFlavor" for item in flavors))


if __name__ == "__main__":
    unittest.main()
