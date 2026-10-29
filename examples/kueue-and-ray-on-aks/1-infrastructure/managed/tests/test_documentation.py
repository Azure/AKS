"""Offline contracts for the managed-only, three-module documentation route."""

from pathlib import Path
import unittest

EXAMPLES = Path(__file__).resolve().parents[3]


class ManagedDocumentationTest(unittest.TestCase):
    def test_root_covers_all_modules_without_repeating_workload_internals(self):
        root = (EXAMPLES / "README.md").read_text()
        diagram = root.split("```mermaid\n", 1)[1].split("```", 1)[0]
        for module in ("Module 1", "Module 2", "Module 3"):
            self.assertIn(module, diagram)
        self.assertIn("Managed KubeRay and Kueue", diagram)
        self.assertNotIn("The serving example uses", root)
        self.assertNotIn("The CPU autoscaler example is independent", root)
        self.assertNotIn("aks-provisioning-config", root)

    def test_validation_precedes_submission_and_cleanup_is_separate(self):
        root = (EXAMPLES / "README.md").read_text()
        self.assertLess(root.index("## Prerequisites and validation"), root.index("## Managed quick start"))
        cleanup = root.split("## Cleanup", 1)[1]
        self.assertNotIn("unittest", cleanup)
        self.assertIn("Module 3 workload guide", cleanup)
        self.assertIn("Module 2 cleanup", cleanup)
        self.assertIn("Module 1 resource cleanup", cleanup)

    def test_managed_route_has_no_controller_install_alternative(self):
        for path in EXAMPLES.rglob("*.md"):
            text = path.read_text().lower()
            for obsolete in ("legacy-guide.md", "legacy terraform", "self-managed alternative",
                             "self-managed terraform alternative", "terraform output"):
                self.assertNotIn(obsolete, text, str(path))
        managed = (EXAMPLES / "1-infrastructure/managed/README.md").read_text()
        self.assertIn("no self-installed Kueue", managed)
        self.assertIn("or KubeRay controllers", managed)
        self.assertFalse((EXAMPLES / "1-infrastructure/terraform/legacy-guide.md").exists())


if __name__ == "__main__":
    unittest.main()
