"""
Batch Inference with Ray Data + vLLM on AKS
============================================

Runs vLLM offline batch inference using a LoRA adapter produced by
the llm-training example (Example 2). Reads test.jsonl from Azure
Blob Storage and the LoRA adapter via workload identity.

Environment variables (set by the RayJob manifest):
  AZURE_STORAGE_ACCOUNT_NAME  - Storage account from Module 1
  LLM_DATA_CONTAINER          - Container holding viggo data (default: llm-pipeline)
  LLM_LORA_CONTAINER          - Container holding LoRA adapters (default: llm-pipeline)
  INFERENCE_RUN_ID             - Run ID for this inference job (default: JOB_NAME)
"""

import asyncio
import json
import os

asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())

import ray
from ray.data.llm import build_processor, vLLMEngineProcessorConfig

MODEL_SOURCE = "Qwen/Qwen2.5-7B-Instruct"
SYSTEM_PROMPT = (
    "Given a target sentence construct the underlying meaning representation "
    "of the input sentence as a single function with attributes and attribute "
    "values. This function should describe the target string accurately and "
    "the function must be one of the following ['inform', 'request', "
    "'give_opinion', 'confirm', 'verify_attribute', 'suggest', "
    "'request_explanation', 'recommend', 'request_attribute']. The attributes "
    "must be one of the following: ['name', 'exp_release_date', 'release_year', "
    "'developer', 'esrb', 'rating', 'genres', 'player_perspective', "
    "'has_multiplayer', 'platforms', 'available_on_steam', 'has_linux_release', "
    "'has_mac_release', 'specifier']"
)


def _blob_client(container_name: str):
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import ContainerClient

    account = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    url = f"https://{account}.blob.core.windows.net"
    return ContainerClient(url, container_name, credential=DefaultAzureCredential())


def load_test_data(container_name: str) -> list[dict]:
    """Load test.jsonl from Azure Blob Storage into memory."""
    client = _blob_client(container_name)
    raw = client.download_blob("data/test.jsonl").readall().decode()
    rows = [json.loads(line) for line in raw.strip().split("\n") if line.strip()]
    print(f"Loaded {len(rows)} test samples from {container_name}/data/test.jsonl")
    return rows


def resolve_lora_path(container_name: str) -> str:
    """Resolve the LoRA adapter azure:// URI from lora/latest.txt."""
    client = _blob_client(container_name)
    try:
        data = client.download_blob("lora/latest.txt").readall()
    except Exception as exc:
        raise FileNotFoundError(
            "lora/latest.txt not found — run Example 2 (llm-training) first "
            "to train and upload a LoRA adapter."
        ) from exc

    cloud_lora_path = data.decode().strip()
    print(f"Resolved LoRA path from lora/latest.txt: {cloud_lora_path}")
    return cloud_lora_path


def _verify_lora_exists(azure_uri: str, lora_id: str) -> None:
    """Verify that a LoRA adapter exists in Azure Blob Storage."""
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import ContainerClient

    authority = azure_uri.split("://")[1]
    container_name, rest = authority.split("@", 1)
    if "/" in rest:
        blob_host, blob_path_prefix = rest.split("/", 1)
        blob_lookup = f"{blob_path_prefix}/{lora_id}/"
    else:
        blob_host = rest
        blob_lookup = f"{lora_id}/"

    client = ContainerClient(
        f"https://{blob_host}", container_name,
        credential=DefaultAzureCredential(),
    )
    first_page = client.list_blobs(name_starts_with=blob_lookup, results_per_page=1)
    if not any(True for _ in first_page):
        raise FileNotFoundError(
            f"No LoRA adapter files at {azure_uri}/{lora_id}/ "
            f"— run Example 2 (llm-training) first."
        )
    print(f"Verified LoRA adapter exists at {azure_uri}/{lora_id}/")


def _worker_setup_hook():
    """Reset asyncio event loop policy on workers (uvloop incompatibility)."""
    import asyncio as _asyncio
    _asyncio.set_event_loop_policy(_asyncio.DefaultEventLoopPolicy())


def run_batch_inference(
    test_rows: list[dict],
    lora_path: str,
    num_gpus: int = 1,
) -> list:
    """Run batch inference using Ray Data + vLLM with LoRA adapter."""
    dynamic_lora_loading_path = None
    lora_name = lora_path

    if lora_path and lora_path.startswith("azure://"):
        lora_path = lora_path.rstrip("/")
        dynamic_lora_loading_path, lora_name = lora_path.rsplit("/", 1)
        _verify_lora_exists(dynamic_lora_loading_path, lora_name)

    print(f"\nModel: {MODEL_SOURCE}")
    print(f"LoRA adapter: {lora_path}")
    if dynamic_lora_loading_path:
        print(f"  dynamic_lora_loading_path: {dynamic_lora_loading_path}")
        print(f"  adapter name: {lora_name}")
    print(f"GPU concurrency: {num_gpus}")

    config_kwargs = dict(
        model_source=MODEL_SOURCE,
        engine_kwargs={
            "enable_lora": True,
            "max_lora_rank": 8,
            "max_loras": 1,
            "pipeline_parallel_size": 1,
            "tensor_parallel_size": 1,
            "enable_prefix_caching": True,
            "enable_chunked_prefill": True,
            "max_num_batched_tokens": 4096,
            "max_model_len": 4096,
            "enforce_eager": True,
        },
        concurrency=num_gpus,
        batch_size=16,
    )
    if dynamic_lora_loading_path:
        config_kwargs["dynamic_lora_loading_path"] = dynamic_lora_loading_path
    config = vLLMEngineProcessorConfig(**config_kwargs)

    def preprocess(row):
        return dict(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": row["input"]},
            ],
            sampling_params={"temperature": 0.0, "max_tokens": 250},
            model=lora_name,
        )

    def postprocess(row):
        return {
            "input": row.get("input", ""),
            "expected": row.get("output", ""),
            "generated": row.get("generated_text", ""),
        }

    processor = build_processor(config, preprocess=preprocess, postprocess=postprocess)

    print(f"\nCreating Ray Dataset from {len(test_rows)} samples...")
    ds = ray.data.from_items(test_rows)
    print(f"Running batch inference on {len(test_rows)} samples...")

    ds = processor(ds)
    results = ds.take_all()
    return results


def evaluate_results(results: list) -> dict:
    """Compare generated outputs against expected (viggo grammar) outputs."""
    total = len(results)
    exact_matches = 0
    function_matches = 0

    print(f"\n{'=' * 60}")
    print(f"Evaluation Results ({total} samples)")
    print(f"{'=' * 60}")

    for i, r in enumerate(results[:5]):
        print(f"\n--- Sample {i + 1} ---")
        print(f"  Input:    {r['input'][:80]}...")
        print(f"  Expected: {r['expected']}")
        print(f"  Got:      {r['generated']}")

    for r in results:
        if r["generated"].strip() == r["expected"].strip():
            exact_matches += 1
        expected_func = r["expected"].strip().split("(")[0] if "(" in r["expected"] else ""
        generated_func = r["generated"].strip().split("(")[0] if "(" in r["generated"] else ""
        if expected_func and expected_func == generated_func:
            function_matches += 1

    metrics = {
        "total_samples": total,
        "exact_match": exact_matches,
        "exact_match_pct": round(exact_matches / total * 100, 1) if total else 0,
        "function_match": function_matches,
        "function_match_pct": round(function_matches / total * 100, 1) if total else 0,
    }

    print(f"\n{'=' * 60}")
    print(f"  Exact match:    {metrics['exact_match']}/{total} ({metrics['exact_match_pct']}%)")
    print(f"  Function match: {metrics['function_match']}/{total} ({metrics['function_match_pct']}%)")
    print(f"{'=' * 60}")
    return metrics


def upload_predictions(results: list, metrics: dict, container_name: str, run_id: str) -> None:
    """Upload predictions and metrics to Azure Blob Storage."""
    client = _blob_client(container_name)
    prefix = f"inference/{run_id}"

    predictions = "\n".join(json.dumps(r) for r in results) + "\n"
    client.upload_blob(f"{prefix}/predictions.jsonl", predictions.encode(), overwrite=True)
    print(f"Uploaded predictions → {prefix}/predictions.jsonl ({len(results)} rows)")

    client.upload_blob(f"{prefix}/metrics.json", json.dumps(metrics, indent=2).encode(), overwrite=True)
    print(f"Uploaded metrics → {prefix}/metrics.json")


def main():
    data_container = os.environ.get("LLM_DATA_CONTAINER", "llm-pipeline")
    lora_container = os.environ.get("LLM_LORA_CONTAINER", "llm-pipeline")
    run_id = os.environ.get("INFERENCE_RUN_ID", "batch-inference")

    print("=" * 60)
    print("Step 1  Loading test data from Azure Blob Storage")
    print("=" * 60)
    test_rows = load_test_data(data_container)

    print("\n" + "=" * 60)
    print("Step 2  Resolving LoRA adapter path")
    print("=" * 60)
    lora_path = resolve_lora_path(lora_container)

    if ray.is_initialized():
        ray.shutdown()
    ray.init(
        address="auto",
        runtime_env={"worker_process_setup_hook": _worker_setup_hook},
    )

    print("\n" + "=" * 60)
    print("Step 3  Batch inference (Ray Data + vLLM)")
    print("=" * 60)
    results = run_batch_inference(test_rows, lora_path)

    print("\n" + "=" * 60)
    print("Step 4  Evaluate predictions")
    print("=" * 60)
    metrics = evaluate_results(results)

    print("\n" + "=" * 60)
    print("Step 5  Uploading predictions to Azure Blob Storage")
    print("=" * 60)
    upload_predictions(results, metrics, data_container, run_id)

    print("\n" + "=" * 60)
    print("Batch inference complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()
