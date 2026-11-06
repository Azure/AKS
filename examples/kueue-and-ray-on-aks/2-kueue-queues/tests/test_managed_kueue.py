"""Offline contract checks for the managed Kueue examples; no cluster access."""

from pathlib import Path
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

    def test_ray_flavors_remain_customer_owned(self):
        flavors = objects(MODULE / "manifests/10-resource-flavors.yaml")
        self.assertEqual({item["metadata"]["name"] for item in flavors}, {"default", "gpu"})
        self.assertTrue(all(item["kind"] == "ResourceFlavor" for item in flavors))


if __name__ == "__main__":
    unittest.main()
