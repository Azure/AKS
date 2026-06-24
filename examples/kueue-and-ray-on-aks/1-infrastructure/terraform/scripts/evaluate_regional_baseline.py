#!/usr/bin/env python3
"""Evaluate simple non-neural regional baselines against init/truth NPZ pairs."""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np


AURORA_PATCH_SIZE = 4


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Evaluate a simple regional baseline.")
    parser.add_argument("--baseline", choices=["persistence"], default="persistence")
    parser.add_argument("--data-dir", type=Path, required=True, help="directory containing init-*.npz and truth-*.npz")
    parser.add_argument("--lead-hours", default="6", help="comma-separated lead hours, e.g. 6,12,24")
    parser.add_argument("--split", default="", help="optional split manifest key, e.g. test")
    parser.add_argument("--region-name", default="region")
    parser.add_argument("--primary-metric", default="mean_surface_rmse")
    parser.add_argument("--output", type=Path, help="where to write eval-metrics.json")
    parser.add_argument("--dry-run", action="store_true", help="validate arguments without reading data")
    args = parser.parse_args(argv)

    lead_hours = parse_lead_hours(args.lead_hours)
    if args.dry_run:
        print(
            json.dumps(
                {
                    "baseline": args.baseline,
                    "data_dir": str(args.data_dir),
                    "lead_hours": lead_hours,
                    "split": args.split or None,
                    "output": None if args.output is None else str(args.output),
                    "status": "dry_run",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 0

    pairs = list_init_truth_pairs(args.data_dir, lead_hours, split=args.split or None)
    if not pairs:
        raise SystemExit(
            f"no init/truth pairs found under {args.data_dir} "
            f"for leads {lead_hours} split={args.split or 'all'}"
        )

    per_pair_metrics = [
        score_persistence_pair(init_path, truth_path)
        for init_path, truth_path in pairs
    ]
    metrics = build_metrics(
        baseline=args.baseline,
        region_name=args.region_name,
        data_dir=args.data_dir,
        lead_hours=lead_hours,
        split=args.split or None,
        primary_metric=args.primary_metric,
        per_pair_metrics=per_pair_metrics,
    )
    rendered = json.dumps(metrics, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n")
        print(f"wrote {args.output}")
    else:
        print(rendered)
    return 0


def parse_lead_hours(raw: str) -> list[int]:
    values = [int(part.strip()) for part in raw.replace(":", ",").split(",") if part.strip()]
    if not values:
        raise ValueError("lead hours must contain at least one integer")
    if any(value <= 0 for value in values):
        raise ValueError(f"lead hours must be positive: {values}")
    return values


SPLIT_MANIFEST_NAMES = ("benchmark-splits.json", "splits.json", "benchmark-manifest.json")


def list_init_truth_pairs(
    cache_dir: Path,
    lead_hours: list[int],
    *,
    split: str | None = None,
) -> list[tuple[Path, Path]]:
    normalized_split = normalize_split(split)
    if normalized_split:
        init_paths = [cache_dir / name for name in split_init_names(cache_dir, normalized_split)]
    else:
        init_paths = sorted(cache_dir.glob("init-*.npz"))
    pairs: list[tuple[Path, Path]] = []
    missing_truths: list[str] = []
    for init_path in init_paths:
        if not init_path.exists():
            raise FileNotFoundError(f"split {normalized_split!r} references missing init file: {init_path}")
        init_time = timestamp_from_npz_name(init_path, "init")
        for lead in lead_hours:
            truth_time = init_time + np.timedelta64(int(lead), "h")
            truth_path = cache_dir / f"truth-{format_np_datetime(truth_time)}.npz"
            if truth_path.exists():
                pairs.append((init_path, truth_path))
            elif normalized_split:
                missing_truths.append(
                    f"{init_path.name} lead={lead} expected={truth_path.name}"
                )
    if missing_truths:
        raise FileNotFoundError(
            f"split {normalized_split!r} has missing truth files: {missing_truths[:5]}"
        )
    return pairs


def normalize_split(split: str | None) -> str | None:
    if split is None:
        return None
    value = str(split).strip()
    if not value or value.lower() in {"all", "*"}:
        return None
    return value


def split_init_names(cache_dir: Path, split: str) -> list[str]:
    manifest_path = find_split_manifest(cache_dir)
    if manifest_path is None:
        raise FileNotFoundError(
            f"split {split!r} requested but no split manifest found under {cache_dir}; "
            f"expected one of {', '.join(SPLIT_MANIFEST_NAMES)}"
        )
    data = json.loads(manifest_path.read_text())
    splits = data.get("splits", data) if isinstance(data, dict) else {}
    if split not in splits:
        raise KeyError(f"split manifest {manifest_path} has no split {split!r}")
    case_ids = splits[split]
    if not isinstance(case_ids, list):
        raise ValueError(f"split manifest {manifest_path} split {split!r} must be a list")
    return [init_name_from_case_id(str(value)) for value in case_ids]


def find_split_manifest(cache_dir: Path) -> Path | None:
    for name in SPLIT_MANIFEST_NAMES:
        path = cache_dir / name
        if path.exists():
            return path
    return None


def init_name_from_case_id(value: str) -> str:
    name = os.path.basename(value)
    if name.startswith("init-") and name.endswith(".npz"):
        return name
    if name.endswith(".npz"):
        name = name[:-len(".npz")]
    return f"init-{name}.npz"


def score_persistence_pair(init_path: Path, truth_path: Path) -> dict[str, Any]:
    pred = load_persistence_surface(init_path)
    truth = load_truth_surface(truth_path)
    out: dict[str, Any] = {
        "init_path": str(init_path),
        "truth_path": str(truth_path),
        "lead_time_hours": infer_lead_time_hours(init_path, truth_path),
        "rmse": {},
        "mae": {},
        "bias": {},
        "max_abs": {},
        "p95_abs": {},
    }
    for key, pred_value in pred.items():
        truth_value = truth.get(key)
        if truth_value is None:
            continue
        for metric_name, value in surface_error_metrics(pred_value, truth_value).items():
            out[metric_name][key] = value
    if not out["rmse"]:
        raise ValueError(f"{init_path} and {truth_path} have no overlapping surface variables")
    return out


def load_persistence_surface(init_path: Path) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    with np.load(init_path) as npz:
        for key in npz.files:
            if not key.startswith("surf_"):
                continue
            arr = np.asarray(npz[key])
            if arr.ndim < 3:
                raise ValueError(f"{init_path}:{key} expected at least 3 dimensions, got {arr.shape}")
            latest = arr[:, -1:, ...] if arr.ndim >= 4 else arr
            out[key.removeprefix("surf_")] = trim_spatial_to_patch(latest)
    return out


def load_truth_surface(truth_path: Path) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    with np.load(truth_path) as npz:
        for key in npz.files:
            if not key.startswith("surf_"):
                continue
            arr = np.asarray(npz[key])
            truth = arr[:, 0:1, ...] if arr.ndim >= 4 else arr
            out[key.removeprefix("surf_")] = trim_spatial_to_patch(truth)
    return out


def trim_spatial_to_patch(arr: np.ndarray, patch_size: int = AURORA_PATCH_SIZE) -> np.ndarray:
    if arr.ndim < 2:
        return arr
    height, width = int(arr.shape[-2]), int(arr.shape[-1])
    if height < patch_size or width < patch_size:
        return arr
    target_height = height - (height % patch_size)
    target_width = width - (width % patch_size)
    return arr[..., :target_height, :target_width]


def surface_error_metrics(pred: np.ndarray, truth: np.ndarray) -> dict[str, float]:
    p = np.atleast_2d(np.asarray(pred).squeeze())
    t = np.atleast_2d(np.asarray(truth).squeeze())
    h = min(p.shape[-2], t.shape[-2])
    w = min(p.shape[-1], t.shape[-1])
    diff = p[..., :h, :w] - t[..., :h, :w]
    abs_diff = np.abs(diff)
    return {
        "rmse": float(np.sqrt(np.mean(diff ** 2))),
        "mae": float(np.mean(abs_diff)),
        "bias": float(np.mean(diff)),
        "max_abs": float(np.max(abs_diff)),
        "p95_abs": float(np.percentile(abs_diff, 95)),
    }


def build_metrics(
    *,
    baseline: str,
    region_name: str,
    data_dir: Path,
    lead_hours: list[int],
    split: str | None,
    primary_metric: str,
    per_pair_metrics: list[dict[str, Any]],
) -> dict[str, Any]:
    per_pair = [dict(item["rmse"]) for item in per_pair_metrics]
    metric_families = {
        name: average_metric_family(per_pair_metrics, name)
        for name in ("rmse", "mae", "bias", "max_abs", "p95_abs")
    }
    primary_value = mean_metric_values(metric_families["rmse"])
    if primary_value is None:
        raise RuntimeError("no RMSE values found")
    return {
        "run_name": None,
        "eval_name": f"{region_name}-{baseline}",
        "eval_kind": baseline,
        "baseline": baseline,
        "per_pair": per_pair,
        "per_pair_metrics": per_pair_metrics,
        "metric_families": metric_families,
        "lead_time_metrics": lead_time_metric_summary(per_pair_metrics),
        "rmse": metric_families["rmse"],
        "mae": metric_families["mae"],
        "bias": metric_families["bias"],
        "max_abs": metric_families["max_abs"],
        "p95_abs": metric_families["p95_abs"],
        "primary_metric": {
            "name": primary_metric,
            "value": primary_value,
            "lower_is_better": True,
        },
        "num_pairs": len(per_pair_metrics),
        "checkpoint": None,
        "manifest": {
            "dataset": {
                "cache_dir": str(data_dir),
                "lead_hours": lead_hours,
                "eval_split": split,
            },
            "research": {
                "baseline": baseline,
                "region_name": region_name,
                "primary_metric": primary_metric,
                "lower_is_better": True,
            },
        },
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


def average_metric_family(per_pair_metrics: list[dict[str, Any]], family: str) -> dict[str, float]:
    keys = sorted({key for item in per_pair_metrics for key in item.get(family, {})})
    out: dict[str, float] = {}
    for key in keys:
        values = [float(item[family][key]) for item in per_pair_metrics if key in item.get(family, {})]
        if values:
            out[key] = sum(values) / len(values)
    return out


def mean_metric_values(values: dict[str, float]) -> float | None:
    return sum(values.values()) / len(values) if values else None


def lead_time_metric_summary(per_pair_metrics: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    lead_hours = sorted({int(item["lead_time_hours"]) for item in per_pair_metrics if item.get("lead_time_hours") is not None})
    out: dict[str, dict[str, Any]] = {}
    for lead in lead_hours:
        items = [item for item in per_pair_metrics if item.get("lead_time_hours") == lead]
        rmse = average_metric_family(items, "rmse")
        out[str(lead)] = {
            "num_pairs": len(items),
            "mean_surface_rmse": mean_metric_values(rmse),
            "rmse": rmse,
        }
    return out


def infer_lead_time_hours(init_path: Path, truth_path: Path) -> int | None:
    try:
        init_time = timestamp_from_npz_name(init_path, "init")
        truth_time = timestamp_from_npz_name(truth_path, "truth")
    except ValueError:
        return None
    delta = truth_time - init_time
    return int(delta / np.timedelta64(1, "h"))


def timestamp_from_npz_name(path: Path, prefix: str) -> np.datetime64:
    name = os.path.basename(path)
    if not name.startswith(f"{prefix}-") or not name.endswith(".npz"):
        raise ValueError(f"{path!r} is not a {prefix}-*.npz file")
    ts = name[len(prefix) + 1:-len(".npz")]
    dt = datetime(int(ts[:4]), int(ts[5:7]), int(ts[8:10]), int(ts[11:13]))
    return np.datetime64(dt, "h")


def format_np_datetime(value: np.datetime64) -> str:
    dt = value.astype("datetime64[h]").astype(datetime)
    return dt.strftime("%Y-%m-%d-%Hz")


if __name__ == "__main__":
    raise SystemExit(main())
