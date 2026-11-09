"""Offline checks: don't contact Azure, Kubernetes, or a model endpoint."""

import importlib.util
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("managed_preflight", ROOT / "preflight.py")
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


def deployment(name="kueue-controller-manager", namespace="kueue-system", release=None, image="mcr.microsoft.com/oss/v2/kueue/kueue:v0.19.6"):
    return {
        "metadata": {"name": name, "namespace": namespace, "annotations": {} if release is None else {"meta.helm.sh/release-name": release}},
        "spec": {"template": {"spec": {"containers": [{"image": image}]}}},
    }


class ManagedPreflightTest(unittest.TestCase):
    def test_extension_inventory_requires_one_successful_instance(self):
        self.assertEqual(preflight.extension_names([]), {})
        item = {"name": "aks-kueue", "extensionType": "microsoft.kueue", "state": "Succeeded"}
        self.assertEqual(preflight.extension_names([item]), {"microsoft.kueue": "aks-kueue"})
        with self.assertRaises(ValueError):
            preflight.extension_names([item, dict(item, name="second")])
        with self.assertRaises(ValueError):
            preflight.extension_names([dict(item, state="Failed")])

    def test_mcr_image_is_not_managed_provenance(self):
        with self.assertRaises(ValueError):
            preflight.check_deployments([deployment(release="kueue")], {})

    def test_reuses_only_the_expected_managed_controller(self):
        preflight.check_deployments([deployment(release="aks-kueue")], {"microsoft.kueue": "aks-kueue"})
        for item in [deployment(namespace="another", release="aks-kueue"), deployment(release="foreign"), deployment(release=None)]:
            with self.assertRaises(ValueError):
                preflight.check_deployments([item], {"microsoft.kueue": "aks-kueue"})

    def test_unmanaged_controller_in_another_namespace_is_rejected(self):
        item = deployment(name="taugrid-kueue-controller-manager", namespace="tau-system", release="taugrid")
        with self.assertRaises(ValueError):
            preflight.check_deployments([item], {})

    def test_kuberay_requires_its_managed_release(self):
        item = deployment(name="kuberay-operator", namespace="kuberay-system", release="kuberay", image="mcr.microsoft.com/oss/v2/kuberay/operator:v1.7.0")
        preflight.check_deployments([item], {"microsoft.kuberay": "kuberay"})
        with self.assertRaises(ValueError):
            preflight.check_deployments([item], {})

    def test_retained_crds_are_not_silently_adopted(self):
        crd = {"metadata": {"name": "rayjobs.ray.io"}, "spec": {"group": "ray.io"}}
        with self.assertRaises(ValueError):
            preflight.check_crds([crd], {})
        preflight.check_crds([crd], {"microsoft.kuberay": "kuberay"})
        preflight.check_crds([{"metadata": {"name": "provisioningrequests.autoscaling.x-k8s.io"}, "spec": {"group": "autoscaling.x-k8s.io"}}], {})

    def test_provisioning_api_requires_served_v1_and_establishment(self):
        crd = {"spec": {"versions": [{"name": "v1", "served": True}]}, "status": {"conditions": [{"type": "Established", "status": "True"}]}}
        preflight.check_provisioning_api(crd)
        crd["spec"]["versions"][0]["served"] = False
        with self.assertRaises(ValueError):
            preflight.check_provisioning_api(crd)
        crd["spec"]["versions"][0]["served"] = True
        crd["status"]["conditions"] = []
        with self.assertRaises(ValueError):
            preflight.check_provisioning_api(crd)

    def test_installer_help_is_offline(self):
        output = subprocess.check_output(["bash", str(ROOT / "install-extensions.sh"), "--help"], text=True)
        self.assertIn("SUBSCRIPTION_ID", output)
        self.assertIn("never adopts", output.lower())

    def test_installer_contract_has_no_helm_or_unsupported_settings(self):
        code = (ROOT / "install-extensions.sh").read_text()
        self.assertIn("ensure_extension microsoft.kueue aks-kueue kueue-system", code)
        self.assertIn("ensure_extension microsoft.kuberay kuberay kuberay-system", code)
        self.assertIn("--auto-upgrade-mode compatible", code)
        self.assertIn("--release-train preview", code)
        self.assertNotIn("helm install", code)
        self.assertNotIn("--configuration-settings", code)
        self.assertNotIn("--config-protected-settings", code)
        self.assertNotIn("--admin", code)
        self.assertNotIn("az account set", code)
        self.assertLess(code.index('preflight.py\" crds'), code.index("ensure_extension microsoft.kueue"))
        self.assertLess(code.index('preflight.py\" provisioning-api'), code.index("ensure_extension microsoft.kueue"))


if __name__ == "__main__":
    unittest.main()
