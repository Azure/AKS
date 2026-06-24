"""
LLM Training — LoRA fine-tuning of Qwen2.5-7B on viggo with LLaMA-Factory.

Reads training data (train.jsonl, val.jsonl, dataset_info.json) from Azure
Blob Storage, runs distributed LoRA SFT via Ray Train + LLaMA-Factory, and
uploads the resulting adapter to blob storage for downstream consumption by
the batch-inference example.

Environment variables:
  AZURE_STORAGE_ACCOUNT_NAME  - Storage account provisioned by Module 1
  LLM_DATA_CONTAINER          - Container holding viggo data (default: llm-pipeline)
  LLM_LORA_CONTAINER          - Container for LoRA upload (default: llm-pipeline)
  LLM_RUN_ID                  - Run identifier for LoRA prefix (default: auto)
  NUM_WORKERS                 - Number of GPU workers (default: 4)
"""

import json
import os
import subprocess
from pathlib import Path

import ray
import yaml
from ray.util.scheduling_strategies import NodeAffinitySchedulingStrategy

DATA_DIR = "/tmp/viggo"
MODEL_SOURCE = "Qwen/Qwen2.5-7B-Instruct"
DATA_FILES = ["train.jsonl", "val.jsonl", "dataset_info.json"]


def download_data_from_blob(data_dir: str = DATA_DIR) -> str:
    """Download viggo dataset files from Azure Blob Storage to local disk."""
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import ContainerClient

    account_name = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    container_name = os.environ.get("LLM_DATA_CONTAINER", "llm-pipeline")
    account_url = f"https://{account_name}.blob.core.windows.net"

    client = ContainerClient(
        account_url=account_url,
        container_name=container_name,
        credential=DefaultAzureCredential(),
    )

    os.makedirs(data_dir, exist_ok=True)

    for fname in DATA_FILES:
        dest = os.path.join(data_dir, fname)
        if os.path.exists(dest):
            print(f"{fname} already exists, skipping.")
            continue
        blob_name = f"data/{fname}"
        print(f"Downloading {blob_name} → {dest} ...")
        with open(dest, "wb") as f:
            stream = client.download_blob(blob_name)
            stream.readinto(f)

    info_path = os.path.join(data_dir, "dataset_info.json")
    with open(info_path) as f:
        info = json.load(f)
    for ds in info.values():
        if "file_name" in ds:
            ds["file_name"] = os.path.join(data_dir, os.path.basename(ds["file_name"]))
    with open(info_path, "w") as f:
        json.dump(info, f, indent=2)

    print(f"Data ready at {data_dir}")
    return data_dir


def _distribute_files_to_gpu_nodes(
    file_data: dict, dest_dir: str, label: str, expected_workers: int = 0
) -> None:
    """Copy files to every alive GPU worker via the Ray object store."""
    import time

    total_mb = sum(len(v) for v in file_data.values()) / 1024 / 1024
    print(
        f"Distributing {label} ({total_mb:.1f} MB, "
        f"{len(file_data)} files) to GPU workers …"
    )

    data_ref = ray.put(file_data)

    @ray.remote(num_cpus=0.1, num_gpus=0)
    def _write_files(path: str, data):
        os.makedirs(path, exist_ok=True)
        for name, content in data.items():
            with open(os.path.join(path, name), "wb") as fh:
                fh.write(content)
        return True

    for attempt in range(5):
        nodes = [
            n
            for n in ray.nodes()
            if n["Alive"] and n.get("Resources", {}).get("GPU", 0) > 0
        ]
        if not nodes or (expected_workers and len(nodes) < expected_workers):
            print(
                f"  {len(nodes)}/{expected_workers or '?'} GPU nodes ready "
                f"(attempt {attempt + 1}/5), waiting …"
            )
            time.sleep(30)
            continue
        try:
            refs = []
            for node in nodes:
                strategy = NodeAffinitySchedulingStrategy(
                    node_id=node["NodeID"], soft=True
                )
                refs.append(
                    _write_files.options(scheduling_strategy=strategy).remote(
                        dest_dir, data_ref
                    )
                )
            ray.get(refs, timeout=600)
            print(f"  {label} distributed to {len(nodes)} GPU node(s).")
            return
        except Exception as e:
            print(f"  Distribution attempt {attempt + 1} failed: {e}")
            if attempt < 4:
                time.sleep(30)
    raise RuntimeError(f"Failed to distribute {label} to GPU workers after 5 attempts")


def distribute_data_to_workers(data_dir: str, num_workers: int = 0) -> None:
    """Copy dataset files and Ray Train storage marker to every GPU worker."""
    file_data = {}
    for fname in DATA_FILES:
        fpath = os.path.join(data_dir, fname)
        if os.path.exists(fpath):
            with open(fpath, "rb") as f:
                file_data[fname] = f.read()
    _distribute_files_to_gpu_nodes(file_data, data_dir, "dataset", num_workers)

    saves_dir = os.path.join(data_dir, "saves")
    marker_dir = os.path.join(saves_dir, "lora_sft_ray")
    os.makedirs(marker_dir, exist_ok=True)
    _distribute_files_to_gpu_nodes(
        {".validate_storage_marker": b""}, marker_dir, "storage marker", num_workers
    )


def run_training(data_dir: str, num_workers: int = 4) -> str:
    """Run LoRA SFT with LLaMA-Factory + Ray Train. Returns checkpoint path."""
    output_dir = os.path.join(data_dir, "outputs")
    saves_dir = os.path.join(data_dir, "saves")
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(saves_dir, exist_ok=True)

    training_config = {
        "model_name_or_path": MODEL_SOURCE,
        "trust_remote_code": True,
        "stage": "sft",
        "do_train": True,
        "finetuning_type": "lora",
        "lora_rank": 8,
        "lora_target": "all",
        "dataset": "viggo-train",
        "dataset_dir": data_dir,
        "template": "qwen",
        "cutoff_len": 2048,
        "max_samples": 1000,
        "overwrite_cache": True,
        "preprocessing_num_workers": 16,
        "dataloader_num_workers": 4,
        "output_dir": output_dir,
        "logging_steps": 10,
        "save_steps": 500,
        "plot_loss": True,
        "overwrite_output_dir": True,
        "save_only_model": False,
        "ray_run_name": "lora_sft_ray",
        "ray_storage_path": saves_dir,
        "ray_num_workers": num_workers,
        "resources_per_worker": {"GPU": 1},
        "placement_strategy": "PACK",
        "per_device_train_batch_size": 1,
        "gradient_accumulation_steps": 8,
        "learning_rate": 1.0e-4,
        "num_train_epochs": 5.0,
        "lr_scheduler_type": "cosine",
        "warmup_ratio": 0.1,
        "bf16": True,
        "ddp_timeout": 180000000,
        "resume_from_checkpoint": None,
        "eval_dataset": "viggo-val",
        "per_device_eval_batch_size": 1,
        "eval_strategy": "steps",
        "eval_steps": 500,
    }

    config_path = os.path.join(data_dir, "lora_sft_ray.yaml")
    with open(config_path, "w") as f:
        yaml.dump(training_config, f, default_flow_style=False)

    print("Training config written to", config_path)

    env = {**os.environ, "USE_RAY": "1"}
    result = subprocess.run(
        ["llamafactory-cli", "train", config_path],
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"llamafactory-cli train failed with exit code {result.returncode}"
        )

    lora_path = _retrieve_checkpoint_from_workers(saves_dir)
    print(f"LoRA adapter saved at: {lora_path}")

    output_path = os.path.join(output_dir, "all_results.json")
    if not os.path.exists(output_path):
        _retrieve_file_from_workers(output_path)
    if os.path.exists(output_path):
        with open(output_path) as f:
            print(f"Training results: {f.read()}")

    return lora_path


def _retrieve_checkpoint_from_workers(saves_dir: str) -> str:
    """Find the LoRA checkpoint on a GPU worker and copy it to the head node."""

    @ray.remote(num_cpus=0.1, num_gpus=0)
    def _find_and_read_checkpoint(saves_dir):
        base = Path(saves_dir) / "lora_sft_ray"
        if not base.exists():
            return None
        trial_dirs = [
            d
            for d in base.iterdir()
            if d.name.startswith("TorchTrainer_") and d.is_dir()
        ]
        if not trial_dirs:
            trial_dirs = [base]
        latest_trial = max(trial_dirs, key=lambda d: d.stat().st_mtime)
        ckpt_dirs = [
            d
            for d in latest_trial.iterdir()
            if d.name.startswith("checkpoint_") and d.is_dir()
        ]
        if not ckpt_dirs:
            return None
        latest_ckpt = max(ckpt_dirs, key=lambda d: d.stat().st_mtime)
        files = {}
        for f in latest_ckpt.rglob("*"):
            if f.is_file():
                files[str(f.relative_to(latest_ckpt))] = f.read_bytes()
        return {
            "rel_path": str(latest_ckpt.relative_to(Path(saves_dir))),
            "files": files,
        }

    nodes = [
        n
        for n in ray.nodes()
        if n["Alive"] and n.get("Resources", {}).get("GPU", 0) > 0
    ]
    for node in nodes:
        strategy = NodeAffinitySchedulingStrategy(node_id=node["NodeID"], soft=True)
        result = ray.get(
            _find_and_read_checkpoint.options(scheduling_strategy=strategy).remote(
                saves_dir
            ),
            timeout=120,
        )
        if result is not None:
            local_path = os.path.join(saves_dir, result["rel_path"])
            os.makedirs(local_path, exist_ok=True)
            for rel_name, content in result["files"].items():
                fpath = os.path.join(local_path, rel_name)
                os.makedirs(os.path.dirname(fpath), exist_ok=True)
                with open(fpath, "wb") as f:
                    f.write(content)
            total_mb = sum(len(v) for v in result["files"].values()) / 1024 / 1024
            print(
                f"  Retrieved checkpoint ({total_mb:.1f} MB) from worker to head: {local_path}"
            )
            adapter_path = os.path.join(local_path, "checkpoint")
            if os.path.isdir(adapter_path):
                return adapter_path
            return local_path

    raise FileNotFoundError("No checkpoint found on any GPU worker node")


def _retrieve_file_from_workers(file_path: str) -> None:
    """Retrieve a single file from a GPU worker node to the head."""

    @ray.remote(num_cpus=0.1, num_gpus=0)
    def _read_file(path):
        if os.path.exists(path):
            with open(path, "rb") as f:
                return f.read()
        return None

    nodes = [
        n
        for n in ray.nodes()
        if n["Alive"] and n.get("Resources", {}).get("GPU", 0) > 0
    ]
    for node in nodes:
        strategy = NodeAffinitySchedulingStrategy(node_id=node["NodeID"], soft=True)
        content = ray.get(
            _read_file.options(scheduling_strategy=strategy).remote(file_path),
            timeout=60,
        )
        if content is not None:
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            with open(file_path, "wb") as f:
                f.write(content)
            print(f"  Retrieved {file_path} from worker.")
            return
    print(f"  Warning: {file_path} not found on any GPU worker.")


def upload_lora_to_azure(
    lora_path: str,
    blob_prefix: str = "",
    container_name: str = "llm-pipeline",
) -> tuple[str, str]:
    """Upload a local LoRA adapter directory to Azure Blob Storage.

    Returns (dynamic_lora_loading_path, lora_id).
    """
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import ContainerClient

    account_name = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    account_url = f"https://{account_name}.blob.core.windows.net"

    client = ContainerClient(
        account_url=account_url,
        container_name=container_name,
        credential=DefaultAzureCredential(),
    )

    if not blob_prefix:
        blob_prefix = os.path.basename(lora_path)

    uploaded = 0
    for root, _dirs, files in os.walk(lora_path):
        for fname in files:
            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, lora_path)
            blob_name = f"{blob_prefix}/{rel}"
            with open(fpath, "rb") as fh:
                client.upload_blob(blob_name, fh, overwrite=True)
            uploaded += 1
    blob_host = f"{account_name}.blob.core.windows.net"
    print(
        f"  Uploaded {uploaded} files to "
        f"azure://{container_name}@{blob_host}/{blob_prefix}/"
    )

    container_root = f"azure://{container_name}@{blob_host}"
    if "/" in blob_prefix:
        parent, lora_id = blob_prefix.rsplit("/", 1)
        dynamic_lora_loading_path = f"{container_root}/{parent}"
    else:
        lora_id = blob_prefix
        dynamic_lora_loading_path = container_root

    return dynamic_lora_loading_path, lora_id


def write_latest_lora_pointer(
    cloud_lora_path: str,
    container_name: str = "llm-pipeline",
) -> None:
    """Write the cloud LoRA path to lora/latest.txt for downstream discovery."""
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import ContainerClient

    account_name = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    account_url = f"https://{account_name}.blob.core.windows.net"

    client = ContainerClient(
        account_url=account_url,
        container_name=container_name,
        credential=DefaultAzureCredential(),
    )
    client.upload_blob(
        "lora/latest.txt",
        cloud_lora_path.encode(),
        overwrite=True,
    )
    print(f"  Updated lora/latest.txt → {cloud_lora_path}")


def main():
    data_dir = DATA_DIR
    num_workers = int(os.environ.get("NUM_WORKERS", "4"))
    run_id = os.environ.get("LLM_RUN_ID", "")
    lora_container = os.environ.get("LLM_LORA_CONTAINER", "llm-pipeline")

    print("=" * 60)
    print("Step 1  Downloading dataset from Azure Blob Storage")
    print("=" * 60)
    data_dir = download_data_from_blob(data_dir)

    distribute_data_to_workers(data_dir, num_workers=num_workers)

    print("\n" + "=" * 60)
    print("Step 2  Distributed fine-tuning (Ray Train + LLaMA-Factory)")
    print("=" * 60)
    lora_path = run_training(data_dir, num_workers=num_workers)

    print("\n" + "=" * 60)
    print("Step 3  Uploading LoRA adapter to Azure Blob Storage")
    print("=" * 60)
    blob_prefix = f"lora/{run_id}" if run_id else "lora/" + str(
        Path(lora_path).relative_to(Path(data_dir) / "saves")
    )
    azure_lora_uri, lora_id = upload_lora_to_azure(
        lora_path, blob_prefix=blob_prefix, container_name=lora_container,
    )
    cloud_lora_path = f"{azure_lora_uri}/{lora_id}"
    print(f"Cloud LoRA path: {cloud_lora_path}")
    write_latest_lora_pointer(cloud_lora_path, container_name=lora_container)

    print("\n" + "=" * 60)
    print("Training complete!")
    print(f"  LoRA adapter: {cloud_lora_path}")
    print(f"  Pointer:      lora/latest.txt")
    print(f"  Run ID:       {run_id}")
    print("=" * 60)


if __name__ == "__main__":
    main()
