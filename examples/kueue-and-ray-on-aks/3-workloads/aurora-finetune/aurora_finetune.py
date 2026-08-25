import json
import os
import random
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path

import ray


LORA_DROPOUT = 0.05
LORA_TARGET_MODULES = ["qkv", "proj"]
SEED = 1337
WEIGHT_DECAY = 0.01


@dataclass(frozen=True)
class Config:
    run_id: str
    scratch_dir: str
    storage_account_name: str
    input_container: str
    output_container: str
    init_file: str
    truth_file: str
    lead_hours: int
    max_steps: int
    lora_rank: int
    require_gpu_name: str
    task_timeout_seconds: int
    disable_hf_xet: bool
    hf_home: str


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, str(default)))


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def load_config() -> Config:
    lead_hours = env_int("AURORA_LEAD_HOURS", 6)
    if lead_hours <= 0 or lead_hours % 6 != 0:
        raise ValueError(f"AURORA_LEAD_HOURS must be a positive 6-hour multiple, got {lead_hours}")

    scratch_dir = os.environ.get("AURORA_SCRATCH_DIR", "/tmp/aurora")
    storage_account = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "").strip()
    if not storage_account:
        raise ValueError("AZURE_STORAGE_ACCOUNT_NAME is required")

    return Config(
        run_id=os.environ.get("AURORA_RUN_ID", "aurora-finetune-smoke"),
        scratch_dir=scratch_dir,
        storage_account_name=storage_account,
        input_container=os.environ.get("AURORA_INPUT_CONTAINER", "aurora"),
        output_container=os.environ.get("AURORA_OUTPUT_CONTAINER", "aurora"),
        init_file=os.environ.get("AURORA_INIT_FILE", "init-2021-01-01-00z.npz"),
        truth_file=os.environ.get("AURORA_TRUTH_FILE", ""),
        lead_hours=lead_hours,
        max_steps=env_int("AURORA_MAX_STEPS", 1),
        lora_rank=env_int("AURORA_LORA_RANK", 8),
        require_gpu_name=os.environ.get("AURORA_REQUIRE_GPU_NAME", "A100"),
        task_timeout_seconds=env_int("AURORA_GPU_TASK_TIMEOUT_SECONDS", 3600),
        disable_hf_xet=env_bool("AURORA_DISABLE_HF_XET", True),
        hf_home=os.environ.get("HF_HOME", str(Path(scratch_dir) / ".cache" / "huggingface")),
    )


def log_stage(stage: str, started: float, **fields) -> None:
    details = " ".join(f"{key}={value}" for key, value in fields.items())
    suffix = f" {details}" if details else ""
    print(f"[aurora] stage={stage} elapsed={time.time() - started:.1f}s{suffix}", flush=True)


def blob_account_url(account_name: str) -> str:
    return f"https://{account_name}.blob.core.windows.net"


def download_blob(account_name: str, container: str, blob_path: str, dest: Path, label: str, started: float, credential=None) -> None:
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobClient

    log_stage("download_start", started, label=label, container=container, blob=blob_path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(f"{dest.name}.download")
    client = BlobClient(
        account_url=blob_account_url(account_name),
        container_name=container,
        blob_name=blob_path,
        credential=credential or DefaultAzureCredential(),
    )
    with tmp.open("wb") as handle:
        client.download_blob().readinto(handle)
    tmp.replace(dest)
    log_stage("download_done", started, label=label, path=dest, bytes=dest.stat().st_size)


def upload_blob(account_name: str, container: str, blob_path: str, source: Path, content_type: str, started: float, credential=None) -> str:
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobClient, ContentSettings

    log_stage("upload_start", started, path=source, container=container, blob=blob_path)
    client = BlobClient(
        account_url=blob_account_url(account_name),
        container_name=container,
        blob_name=blob_path,
        credential=credential or DefaultAzureCredential(),
    )
    with source.open("rb") as handle:
        client.upload_blob(handle, overwrite=True, content_settings=ContentSettings(content_type=content_type))
    url = f"{blob_account_url(account_name)}/{container}/{blob_path}"
    log_stage("upload_done", started, url=url)
    return url


def prepare_runtime(config: Config):
    import numpy as np
    import torch

    if config.disable_hf_xet:
        os.environ["HF_HUB_DISABLE_XET"] = "1"
    if config.hf_home:
        os.environ["HF_HOME"] = config.hf_home
        Path(config.hf_home).mkdir(parents=True, exist_ok=True)

    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is not available; the Ray task did not receive a GPU")

    gpu_name = torch.cuda.get_device_name(0)
    required_gpu = config.require_gpu_name.strip()
    if required_gpu and required_gpu.lower() not in gpu_name.lower():
        raise RuntimeError(f"expected GPU name containing {required_gpu!r}, got {gpu_name!r}")

    random.seed(SEED)
    np.random.seed(SEED)
    torch.manual_seed(SEED)
    torch.cuda.manual_seed_all(SEED)
    return torch.device("cuda:0"), gpu_name


def timestamp_from_file_name(name: str, prefix: str) -> datetime:
    if not name.startswith(f"{prefix}-") or not name.endswith(".npz"):
        raise ValueError(f"{name} is not a {prefix}-*.npz file")
    stamp = name[len(prefix) + 1 : -len(".npz")]
    return datetime(int(stamp[:4]), int(stamp[5:7]), int(stamp[8:10]), int(stamp[11:13]))


def truth_file_for_init(init_file: str, lead_hours: int) -> str:
    truth_time = timestamp_from_file_name(init_file, "init") + timedelta(hours=lead_hours)
    return f"truth-{truth_time.strftime('%Y-%m-%d-%Hz')}.npz"


def stage_training_pair(config: Config, started: float, credential=None) -> tuple[Path, Path]:
    input_dir = Path(config.scratch_dir) / "aurora-input"
    truth_file = config.truth_file or truth_file_for_init(config.init_file, config.lead_hours)

    init_path = input_dir / config.init_file
    truth_path = input_dir / truth_file

    download_blob(
        config.storage_account_name,
        config.input_container,
        f"data/{config.init_file}",
        init_path,
        "init",
        started,
        credential,
    )
    download_blob(
        config.storage_account_name,
        config.input_container,
        f"data/{truth_file}",
        truth_path,
        "truth",
        started,
        credential,
    )
    return init_path, truth_path


def upload_outputs(config: Config, checkpoint_path: Path, metrics_path: Path, started: float, credential=None) -> dict:
    return {
        "checkpoint": upload_blob(
            config.storage_account_name,
            config.output_container,
            f"checkpoints/{config.run_id}/last.safetensors",
            checkpoint_path,
            "application/octet-stream",
            started,
            credential,
        ),
        "metrics": upload_blob(
            config.storage_account_name,
            config.output_container,
            f"checkpoints/{config.run_id}/train-metrics.json",
            metrics_path,
            "application/json",
            started,
            credential,
        ),
    }


def tensors_from_npz(npz, prefix: str, device) -> dict:
    import torch

    return {
        key.removeprefix(prefix): torch.from_numpy(npz[key]).to(device)
        for key in npz.files
        if key.startswith(prefix)
    }


def load_batch(init_path: Path, device):
    import numpy as np
    import torch
    from aurora import Batch, Metadata

    with np.load(init_path, allow_pickle=False) as npz:
        last_time = np.asarray(npz["times"])[-1].astype("datetime64[us]").astype(datetime)
        return Batch(
            surf_vars=tensors_from_npz(npz, "surf_", device),
            atmos_vars=tensors_from_npz(npz, "atmos_", device),
            static_vars=tensors_from_npz(npz, "static_", device),
            metadata=Metadata(
                lat=torch.from_numpy(np.asarray(npz["lat"])).to(device),
                lon=torch.from_numpy(np.asarray(npz["lon"])).to(device),
                time=(last_time,),
                atmos_levels=tuple(int(value) for value in npz["levels"].tolist()),
            ),
        )


def load_target(truth_path: Path, device) -> dict:
    import numpy as np
    import torch

    with np.load(truth_path, allow_pickle=False) as npz:
        return {
            key.removeprefix("surf_"): torch.from_numpy(npz[key][:, 0:1]).to(device)
            for key in npz.files
            if key.startswith("surf_")
        }


def trim_to_patch_size(batch, patch_size: int):
    from aurora import Batch, Metadata

    height, width = batch.spatial_shape
    target_height = height - (height % patch_size)
    target_width = width - (width % patch_size)
    if target_height <= 0 or target_width <= 0:
        raise ValueError(f"regional grid {height}x{width} is smaller than patch size {patch_size}")
    if (target_height, target_width) == (height, width):
        return batch

    return Batch(
        surf_vars={key: value[..., :target_height, :target_width] for key, value in batch.surf_vars.items()},
        atmos_vars={key: value[..., :target_height, :target_width] for key, value in batch.atmos_vars.items()},
        static_vars={key: value[..., :target_height, :target_width] for key, value in batch.static_vars.items()},
        metadata=Metadata(
            lat=batch.metadata.lat[:target_height],
            lon=batch.metadata.lon[:target_width],
            time=batch.metadata.time,
            atmos_levels=batch.metadata.atmos_levels,
            rollout_step=batch.metadata.rollout_step,
        ),
    )


def _unwrap_model(model):
    return model.module if hasattr(model, "module") else model


def forecast(model, batch, lead_hours: int):
    from aurora import rollout

    base_model = _unwrap_model(model)
    trimmed_batch = trim_to_patch_size(batch, int(base_model.patch_size))

    prediction = None
    for prediction in rollout(base_model, trimmed_batch, lead_hours // 6):
        pass
    if prediction is None:
        raise RuntimeError(f"no forecast produced for lead={lead_hours}h")
    return prediction


def compute_surface_loss(prediction, target: dict):
    import torch

    losses = []
    for name, target_tensor in target.items():
        predicted_tensor = prediction.surf_vars.get(name)
        if predicted_tensor is None:
            continue

        predicted_surface = predicted_tensor[:, :1]
        height = min(predicted_surface.shape[-2], target_tensor.shape[-2])
        width = min(predicted_surface.shape[-1], target_tensor.shape[-1])
        losses.append(
            torch.nn.functional.mse_loss(
                predicted_surface[..., :height, :width],
                target_tensor[..., :height, :width],
            )
        )

    if not losses:
        raise RuntimeError("no overlapping surface variables between prediction and target")
    return torch.stack(losses).mean()


def build_lora_model(config: Config, started: float):
    from aurora import AuroraPretrained
    from huggingface_hub import hf_hub_download
    from peft import LoraConfig, get_peft_model

    log_stage("model_construct_start", started)
    model = AuroraPretrained(autocast=True)
    log_stage("model_construct_done", started)

    log_stage("checkpoint_download_start", started)
    checkpoint_path = hf_hub_download(
        repo_id=model.default_checkpoint_repo,
        filename=model.default_checkpoint_name,
        revision=model.default_checkpoint_revision,
    )
    log_stage("checkpoint_load_start", started, path=checkpoint_path)
    model.load_checkpoint_local(checkpoint_path)

    lora = LoraConfig(
        r=config.lora_rank,
        lora_alpha=config.lora_rank * 2,
        lora_dropout=LORA_DROPOUT,
        target_modules=LORA_TARGET_MODULES,
        bias="none",
    )
    model.configure_activation_checkpointing()
    model = get_peft_model(model, lora)
    log_stage("lora_wrap_done", started, rank=config.lora_rank)
    return model, checkpoint_path


def build_optimizer(model):
    import torch

    return torch.optim.AdamW(
        (parameter for parameter in model.parameters() if parameter.requires_grad),
        lr=5e-5,
        weight_decay=WEIGHT_DECAY,
    )


def fine_tune_step(model, optimizer, batch, target: dict, config: Config, device) -> float:
    import torch

    optimizer.zero_grad(set_to_none=True)
    with torch.autocast(device_type=device.type, dtype=torch.bfloat16):
        prediction = forecast(model, batch, config.lead_hours)
        loss = compute_surface_loss(prediction, target)
    loss.backward()
    optimizer.step()
    return float(loss.detach())


def trainable_state_dict(model) -> dict:
    base_model = _unwrap_model(model)
    return {
        name.replace("_checkpoint_wrapped_module.", ""): parameter.detach().cpu().contiguous()
        for name, parameter in base_model.named_parameters()
        if parameter.requires_grad
    }


@ray.remote(num_gpus=1, num_cpus=4)
def train_on_gpu(raw_config: dict) -> dict:
    import torch
    from azure.identity import DefaultAzureCredential
    from safetensors.torch import save_file

    config = Config(**raw_config)
    started = time.time()
    device, gpu_name = prepare_runtime(config)
    credential = DefaultAzureCredential()

    init_path, truth_path = stage_training_pair(config, started, credential)
    print(
        f"[aurora] pair init={init_path.name} truth={truth_path.name} "
        f"gpu={gpu_name} torch={torch.__version__} cuda={torch.version.cuda}",
        flush=True,
    )
    batch = load_batch(init_path, device)
    target = load_target(truth_path, device)
    log_stage("data_loaded", started)

    model, source_checkpoint_path = build_lora_model(config, started)
    model = model.to(device).train()
    trainable_params = sum(int(p.numel()) for p in model.parameters() if p.requires_grad)
    optimizer = build_optimizer(model)

    initial_loss = float("inf")
    try:
        initial_loss = compute_loss_safely(model, batch, target, config, device)
    except Exception as exc:
        print(f"[aurora] initial eval skipped: {exc}", flush=True)

    print(f"[aurora] initial_loss={initial_loss:.4f} trainable_params={trainable_params}", flush=True)

    loss_history = []
    log_stage("training_start", started, steps=config.max_steps)
    for step in range(config.max_steps):
        loss_history.append(fine_tune_step(model, optimizer, batch, target, config, device))
        print(f"[aurora] step={step + 1}/{config.max_steps} loss={loss_history[-1]:.4f}", flush=True)

    final_loss = compute_loss_safely(model, batch, target, config, device)

    output_dir = Path(config.scratch_dir) / "aurora-output" / config.run_id
    output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint_path = output_dir / "last.safetensors"
    metrics_path = output_dir / "train-metrics.json"

    save_file(trainable_state_dict(model), str(checkpoint_path))
    metrics = {
        "run_id": config.run_id,
        "kind": "aurora-rayjob-finetune",
        "pair": {
            "init": str(init_path),
            "truth": str(truth_path),
            "lead_hours": config.lead_hours,
        },
        "max_steps": config.max_steps,
        "initial_loss": initial_loss,
        "final_loss": final_loss,
        "loss_improvement": initial_loss - final_loss,
        "loss_history": loss_history,
        "checkpoint_path": str(checkpoint_path),
        "source_checkpoint_path": str(source_checkpoint_path),
        "trainable_parameters": trainable_params,
        "lora": {
            "rank": config.lora_rank,
            "target_modules": LORA_TARGET_MODULES,
        },
        "gpu_name": gpu_name,
        "torch_version": torch.__version__,
        "cuda_version": torch.version.cuda,
        "max_memory_allocated_bytes": int(torch.cuda.max_memory_allocated()),
        "elapsed_seconds": time.time() - started,
    }
    metrics_path.write_text(json.dumps(metrics, indent=2, sort_keys=True))

    remote_outputs = upload_outputs(config, checkpoint_path, metrics_path, started, credential)
    metrics["remote_outputs"] = remote_outputs

    print(
        f"[aurora] final_loss={final_loss:.4f} checkpoint={checkpoint_path} "
        f"remote_checkpoint={remote_outputs['checkpoint']}",
        flush=True,
    )
    return metrics


def compute_loss_safely(model, batch, target, config, device) -> float:
    import torch

    was_training = model.training
    model.eval()
    with torch.no_grad(), torch.autocast(device_type=device.type, dtype=torch.bfloat16):
        prediction = forecast(model, batch, config.lead_hours)
        loss = compute_surface_loss(prediction, target)
    if was_training:
        model.train()
    return float(loss.detach().cpu())


def main() -> None:
    config = load_config()
    print("[aurora] config:", json.dumps(asdict(config), sort_keys=True), flush=True)
    ray.init()

    result = ray.get(
        train_on_gpu.remote(asdict(config)),
        timeout=config.task_timeout_seconds,
    )
    summary = {
        "run_id": result["run_id"],
        "initial_loss": result["initial_loss"],
        "final_loss": result["final_loss"],
        "loss_improvement": result["loss_improvement"],
        "remote_outputs": result["remote_outputs"],
        "gpu_name": result["gpu_name"],
        "elapsed_seconds": result["elapsed_seconds"],
    }
    print("[aurora] result:", json.dumps(summary, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
