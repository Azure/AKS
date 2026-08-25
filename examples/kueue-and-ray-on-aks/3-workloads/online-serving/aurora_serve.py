import os
import time
from dataclasses import dataclass
from pathlib import Path

from ray import serve


LORA_DROPOUT = 0.05
LORA_TARGET_MODULES = ["qkv", "proj"]


@dataclass(frozen=True)
class ServeConfig:
    scratch_dir: str
    storage_account_name: str
    input_container: str
    adapter_container: str
    aurora_run_id: str
    init_file: str
    lead_hours: int
    lora_rank: int
    require_gpu_name: str
    disable_hf_xet: bool
    hf_home: str


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, str(default)))


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def load_config() -> ServeConfig:
    scratch_dir = os.environ.get("AURORA_SCRATCH_DIR", "/tmp/aurora-serve")
    storage_account = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "").strip()
    if not storage_account:
        raise ValueError("AZURE_STORAGE_ACCOUNT_NAME is required")
    aurora_run_id = os.environ.get("AURORA_RUN_ID", "").strip()
    if not aurora_run_id:
        raise ValueError("AURORA_RUN_ID is required (set to the JOB_NAME from your aurora-finetune run)")

    lead_hours = env_int("AURORA_LEAD_HOURS", 6)
    if lead_hours <= 0 or lead_hours % 6 != 0:
        raise ValueError(f"AURORA_LEAD_HOURS must be a positive 6-hour multiple, got {lead_hours}")

    return ServeConfig(
        scratch_dir=scratch_dir,
        storage_account_name=storage_account,
        input_container=os.environ.get("AURORA_INPUT_CONTAINER", "aurora"),
        adapter_container=os.environ.get("AURORA_ADAPTER_CONTAINER", "aurora"),
        aurora_run_id=aurora_run_id,
        init_file=os.environ.get("AURORA_INIT_FILE", "init-2021-01-01-00z.npz"),
        lead_hours=lead_hours,
        lora_rank=env_int("AURORA_LORA_RANK", 8),
        require_gpu_name=os.environ.get("AURORA_REQUIRE_GPU_NAME", "A100"),
        disable_hf_xet=env_bool("AURORA_DISABLE_HF_XET", True),
        hf_home=os.environ.get("HF_HOME", str(Path(scratch_dir) / ".cache" / "huggingface")),
    )


def log_stage(stage: str, started: float, **fields) -> None:
    details = " ".join(f"{key}={value}" for key, value in fields.items())
    suffix = f" {details}" if details else ""
    print(f"[aurora-serve] stage={stage} elapsed={time.time() - started:.1f}s{suffix}", flush=True)


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


def prepare_runtime(config: ServeConfig):
    import torch

    if config.disable_hf_xet:
        os.environ["HF_HUB_DISABLE_XET"] = "1"
    if config.hf_home:
        os.environ["HF_HOME"] = config.hf_home
        Path(config.hf_home).mkdir(parents=True, exist_ok=True)

    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is not available; the Ray actor did not receive a GPU")

    gpu_name = torch.cuda.get_device_name(0)
    required_gpu = config.require_gpu_name.strip()
    if required_gpu and required_gpu.lower() not in gpu_name.lower():
        raise RuntimeError(f"expected GPU name containing {required_gpu!r}, got {gpu_name!r}")

    return torch.device("cuda:0"), gpu_name


def download_adapter(config: ServeConfig, started: float, credential=None) -> Path:
    adapter_path = Path(config.scratch_dir) / "aurora-adapter" / "last.safetensors"
    download_blob(
        config.storage_account_name,
        config.adapter_container,
        f"checkpoints/{config.aurora_run_id}/last.safetensors",
        adapter_path,
        "adapter",
        started,
        credential,
    )
    return adapter_path


def build_serving_model(config: ServeConfig, device, adapter_path: Path, started: float):
    from aurora import AuroraPretrained
    from huggingface_hub import hf_hub_download
    from peft import LoraConfig, get_peft_model
    from safetensors.torch import load_file

    log_stage("model_construct_start", started)
    model = AuroraPretrained(autocast=True)
    log_stage("checkpoint_download_start", started)
    checkpoint_path = hf_hub_download(
        repo_id=model.default_checkpoint_repo,
        filename=model.default_checkpoint_name,
        revision=model.default_checkpoint_revision,
    )
    model.load_checkpoint_local(checkpoint_path)

    lora = LoraConfig(
        r=config.lora_rank,
        lora_alpha=config.lora_rank * 2,
        lora_dropout=LORA_DROPOUT,
        target_modules=list(LORA_TARGET_MODULES),
        bias="none",
    )
    model = get_peft_model(model, lora)
    adapter_state = load_file(str(adapter_path))
    adapter_key_count = sum(1 for key in adapter_state if "lora_" in key)
    if adapter_key_count == 0:
        raise RuntimeError(f"adapter file has no LoRA keys: {adapter_path}")
    incompatible = model.load_state_dict(adapter_state, strict=False)
    if incompatible.unexpected_keys:
        raise RuntimeError(f"adapter has unexpected keys: {incompatible.unexpected_keys}")

    model = model.to(device).eval()
    log_stage("model_ready", started, adapter=adapter_path, adapter_keys=adapter_key_count)
    return model


def tensors_from_npz(npz, prefix: str, device) -> dict:
    import torch

    return {
        key.removeprefix(prefix): torch.from_numpy(npz[key]).to(device)
        for key in npz.files
        if key.startswith(prefix)
    }


def load_batch(init_path: Path, device):
    from datetime import datetime

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


def forecast(model, batch, lead_hours: int):
    from aurora import rollout

    base_model = model.module if hasattr(model, "module") else model
    trimmed_batch = trim_to_patch_size(batch, int(base_model.patch_size))

    prediction = None
    for prediction in rollout(base_model, trimmed_batch, lead_hours // 6):
        pass
    if prediction is None:
        raise RuntimeError(f"no forecast produced for lead={lead_hours}h")
    return prediction


def summarize_prediction(prediction, init_file: str, lead_hours: int) -> dict:
    summary = {}
    for name, tensor in prediction.surf_vars.items():
        values = tensor.detach().float().cpu()
        summary[name] = {
            "shape": list(values.shape),
            "mean": float(values.mean()),
            "min": float(values.min()),
            "max": float(values.max()),
        }
    prediction_times = tuple(prediction.metadata.time) if prediction.metadata.time is not None else ()
    return {
        "init_file": init_file,
        "lead_hours": lead_hours,
        "prediction_time": str(prediction_times[0]) if prediction_times else None,
        "surface_variables": summary,
    }


def validate_file_name(name: str) -> None:
    if "/" in name or "\\" in name or ".." in name:
        raise ValueError(f"invalid file name: {name!r}")


@serve.deployment(num_replicas=1, ray_actor_options={"num_gpus": 1, "num_cpus": 4})
class AuroraServeDeployment:
    def __init__(self):
        import torch
        from azure.identity import DefaultAzureCredential

        self.config = load_config()
        started = time.time()
        credential = DefaultAzureCredential()
        self.device, self.gpu_name = prepare_runtime(self.config)
        self.adapter_path = download_adapter(self.config, started, credential)
        self.model = build_serving_model(self.config, self.device, self.adapter_path, started)
        self.credential = credential
        self.torch_version = torch.__version__

    async def __call__(self, request):
        if request.method == "GET":
            return {
                "status": "ok",
                "gpu_name": self.gpu_name,
                "run_id": self.config.aurora_run_id,
                "adapter": f"checkpoints/{self.config.aurora_run_id}/last.safetensors",
            }

        payload = await request.json()
        if not isinstance(payload, dict):
            raise ValueError("request body must be a JSON object")

        raw_init = payload.get("init_file", self.config.init_file)
        raw_lead = payload.get("lead_hours", self.config.lead_hours)
        if raw_init is None:
            raw_init = self.config.init_file
        if raw_lead is None:
            raw_lead = self.config.lead_hours
        init_file = str(raw_init)
        lead_hours = int(raw_lead)
        if lead_hours <= 0 or lead_hours % 6 != 0:
            raise ValueError(f"lead_hours must be a positive 6-hour multiple, got {lead_hours}")
        validate_file_name(init_file)

        started = time.time()
        init_path = Path(self.config.scratch_dir) / "aurora-serve-input" / init_file
        if not init_path.exists():
            download_blob(
                self.config.storage_account_name,
                self.config.input_container,
                f"data/{init_file}",
                init_path,
                "serve-init",
                started,
                self.credential,
            )
        batch = load_batch(init_path, self.device)

        import torch

        with torch.no_grad(), torch.autocast(device_type=self.device.type, dtype=torch.bfloat16):
            prediction = forecast(self.model, batch, lead_hours)

        result = summarize_prediction(prediction, init_file, lead_hours)
        result.update({
            "elapsed_seconds": time.time() - started,
            "gpu_name": self.gpu_name,
            "torch_version": self.torch_version,
        })
        return result


app = AuroraServeDeployment.bind()
