"""Offline regression for rank-local RNG checkpoints masquerading as adapters."""

import ast
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "llm-training/llm_training.py"


def functions():
    """Load only the tested functions; no Ray/ML/Azure imports or model calls."""
    names = {"_adapter_directory", "_retrieve_checkpoint_from_workers", "upload_lora_to_azure"}
    nodes = [node for node in ast.parse(SOURCE.read_text()).body
             if isinstance(node, ast.FunctionDef) and node.name in names]
    assert len(nodes) == len(names)
    scope = {"Path": Path, "os": os}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(SOURCE), "exec"), scope)
    return scope


def adapter(directory, weights="adapter_model.safetensors"):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "adapter_config.json").write_text('{"peft_type":"LORA","r":8}')
    (directory / weights).write_bytes(b"test-weights")


class FakeRay:
    def __init__(self, remote_roots):
        self.remote_roots = remote_roots
        self.visited = []

    def nodes(self):
        return [{"Alive": True, "NodeID": name, "Resources": {"GPU": 1}}
                for name in self.remote_roots]

    def remote(self, **resources):
        owner = self

        def decorate(function):
            class Remote:
                def options(self, scheduling_strategy):
                    self.node_id = scheduling_strategy.node_id
                    return self

                def remote(self, unused_head_path):
                    owner.visited.append(self.node_id)
                    return function(str(owner.remote_roots[self.node_id]))
            return Remote()
        return decorate

    def get(self, result, timeout=None):
        return result


class LoRACheckpointTest(unittest.TestCase):
    def test_rng_only_or_empty_adapter_is_not_a_model(self):
        select = functions()["_adapter_directory"]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "rng_state_2.pth").write_bytes(b"rng")
            self.assertIsNone(select(root))
            (root / "adapter_config.json").write_text('{"r":8}')
            (root / "adapter_model.safetensors").touch()
            self.assertIsNone(select(root))

    def test_nested_and_direct_adapter_formats(self):
        select = functions()["_adapter_directory"]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            adapter(root / "checkpoint")
            self.assertEqual(select(root), root / "checkpoint")
            adapter(root / "direct", weights="adapter_model.bin")
            self.assertEqual(select(root / "direct"), root / "direct")

    def test_retrieval_skips_first_rng_rank_and_copies_complete_rank_zero(self):
        scope = functions()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = Path("lora_sft_ray/TorchTrainer_test/checkpoint_000000/checkpoint")
            rng = root / "rank2" / relative
            rng.mkdir(parents=True)
            (rng / "rng_state_2.pth").write_bytes(b"rng-only")
            adapter(root / "rank0" / relative)
            ray = FakeRay({"rank2": root / "rank2", "rank0": root / "rank0"})
            scope.update(ray=ray, NodeAffinitySchedulingStrategy=lambda **kwargs: SimpleNamespace(**kwargs))
            path = scope["_retrieve_checkpoint_from_workers"](str(root / "head"))
            self.assertEqual(ray.visited, ["rank2", "rank0"])
            self.assertEqual(Path(path), root / "head" / relative)
            self.assertTrue((Path(path) / "adapter_config.json").is_file())
            self.assertEqual((Path(path) / "adapter_model.safetensors").read_bytes(), b"test-weights")

    def test_no_complete_rank_fails_instead_of_publishing_rng(self):
        scope = functions()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "rank2/lora_sft_ray/TorchTrainer_test/checkpoint_000000/checkpoint"
            path.mkdir(parents=True)
            (path / "rng_state_2.pth").write_bytes(b"rng-only")
            scope.update(ray=FakeRay({"rank2": root / "rank2"}),
                         NodeAffinitySchedulingStrategy=lambda **kwargs: SimpleNamespace(**kwargs))
            with self.assertRaisesRegex(FileNotFoundError, "complete LoRA adapter"):
                scope["_retrieve_checkpoint_from_workers"](str(root / "head"))

    def test_upload_rejects_incomplete_artifact_before_azure_calls(self):
        upload = functions()["upload_lora_to_azure"]
        with tempfile.TemporaryDirectory() as temporary:
            (Path(temporary) / "rng_state_1.pth").write_bytes(b"rng")
            with self.assertRaisesRegex(ValueError, "incomplete LoRA adapter"):
                upload(temporary)


if __name__ == "__main__":
    unittest.main()
