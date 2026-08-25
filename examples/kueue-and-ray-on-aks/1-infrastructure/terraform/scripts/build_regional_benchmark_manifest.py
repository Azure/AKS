#!/usr/bin/env python3
"""Build a regional benchmark split manifest from init/truth NPZ files."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from evaluate_regional_baseline import (
    format_np_datetime,
    parse_lead_hours,
    timestamp_from_npz_name,
)


SEASONS = {
    12: "DJF",
    1: "DJF",
    2: "DJF",
    3: "MAM",
    4: "MAM",
    5: "MAM",
    6: "JJA",
    7: "JJA",
    8: "JJA",
    9: "SON",
    10: "SON",
    11: "SON",
}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build benchmark-splits.json for regional Aurora paper runs.")
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--region-name", required=True)
    parser.add_argument("--lead-hours", default="6,12,24")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--train-fraction", type=float, default=0.6)
    parser.add_argument("--validation-fraction", type=float, default=0.2)
    parser.add_argument("--min-test-count", type=int, default=30)
    parser.add_argument("--min-test-seasons", type=int, default=2)
    parser.add_argument(
        "--allow-threshold-failures",
        action="store_true",
        help="write the manifest even if test count/season thresholds fail",
    )
    args = parser.parse_args(argv)

    lead_hours = parse_lead_hours(args.lead_hours)
    cases = collect_complete_cases(args.data_dir, lead_hours)
    splits = split_cases(cases, train_fraction=args.train_fraction, validation_fraction=args.validation_fraction)
    manifest = build_manifest(
        region_name=args.region_name,
        data_dir=args.data_dir,
        lead_hours=lead_hours,
        cases=cases,
        splits=splits,
        min_test_count=args.min_test_count,
        min_test_seasons=args.min_test_seasons,
    )
    errors = validate_manifest(manifest)
    output = args.output or (args.data_dir / "benchmark-splits.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(summary_line(manifest, output, errors))
    if errors and not args.allow_threshold_failures:
        return 1
    return 0


def collect_complete_cases(data_dir: Path, lead_hours: list[int]) -> list[dict[str, Any]]:
    import numpy as np

    if not data_dir.exists():
        raise SystemExit(f"data dir does not exist: {data_dir}")
    truth_names = {path.name for path in data_dir.glob("truth-*.npz")}
    cases: list[dict[str, Any]] = []
    for init_path in sorted(data_dir.glob("init-*.npz")):
        init_time = timestamp_from_npz_name(init_path, "init")
        truth_paths: dict[str, str] = {}
        for lead in lead_hours:
            truth_time = init_time + np.timedelta64(int(lead), "h")
            truth_name = f"truth-{format_np_datetime(truth_time)}.npz"
            if truth_name not in truth_names:
                break
            truth_paths[str(lead)] = truth_name
        if len(truth_paths) != len(lead_hours):
            continue
        dt = init_time.astype("datetime64[h]").astype(datetime)
        cases.append({
            "case_id": case_id_from_init_name(init_path.name),
            "init": init_path.name,
            "truth": truth_paths,
            "month": dt.month,
            "season": SEASONS[dt.month],
        })
    return cases


def split_cases(
    cases: list[dict[str, Any]],
    *,
    train_fraction: float,
    validation_fraction: float,
) -> dict[str, list[str]]:
    if train_fraction < 0 or validation_fraction < 0 or train_fraction + validation_fraction >= 1:
        raise ValueError("train_fraction and validation_fraction must be non-negative and sum to < 1")
    ordered = sorted(cases, key=lambda item: item["case_id"])
    n = len(ordered)
    train_end = int(n * train_fraction)
    validation_end = train_end + int(n * validation_fraction)
    if n >= 3:
        train_end = max(1, min(train_end, n - 2))
        validation_end = max(train_end + 1, min(validation_end, n - 1))
    return {
        "train": [item["case_id"] for item in ordered[:train_end]],
        "validation": [item["case_id"] for item in ordered[train_end:validation_end]],
        "test": [item["case_id"] for item in ordered[validation_end:]],
    }


def build_manifest(
    *,
    region_name: str,
    data_dir: Path,
    lead_hours: list[int],
    cases: list[dict[str, Any]],
    splits: dict[str, list[str]],
    min_test_count: int,
    min_test_seasons: int,
) -> dict[str, Any]:
    case_by_id = {item["case_id"]: item for item in cases}
    split_seasons = {
        split: sorted({case_by_id[case_id]["season"] for case_id in case_ids if case_id in case_by_id})
        for split, case_ids in splits.items()
    }
    return {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "region": region_name,
        "data_dir": str(data_dir),
        "lead_hours": lead_hours,
        "case_count": len(cases),
        "cases": cases,
        "splits": splits,
        "split_counts": {split: len(case_ids) for split, case_ids in splits.items()},
        "split_seasons": split_seasons,
        "requirements": {
            "min_test_count": min_test_count,
            "min_test_seasons": min_test_seasons,
            "complete_lead_coverage": True,
            "chronological_splits": True,
        },
        "errors": [],
    }


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    requirements = manifest.get("requirements", {})
    splits = manifest.get("splits", {})
    test_cases = splits.get("test", [])
    test_seasons = manifest.get("split_seasons", {}).get("test", [])
    if len(test_cases) < int(requirements.get("min_test_count", 0)):
        errors.append(
            f"test split has {len(test_cases)} cases; need >= {requirements.get('min_test_count')}"
        )
    if len(test_seasons) < int(requirements.get("min_test_seasons", 0)):
        errors.append(
            f"test split covers {len(test_seasons)} seasons; need >= {requirements.get('min_test_seasons')}"
        )
    seen: dict[str, str] = {}
    for split, case_ids in splits.items():
        for case_id in case_ids:
            if case_id in seen:
                errors.append(f"case {case_id} appears in both {seen[case_id]} and {split}")
            seen[case_id] = split
    manifest["errors"] = errors
    return errors


def case_id_from_init_name(name: str) -> str:
    if not name.startswith("init-") or not name.endswith(".npz"):
        raise ValueError(f"{name!r} is not an init-*.npz name")
    return name[len("init-"):-len(".npz")]


def summary_line(manifest: dict[str, Any], output: Path, errors: list[str]) -> str:
    split_counts = manifest["split_counts"]
    status = "OK" if not errors else "FAIL: " + "; ".join(errors)
    return (
        f"wrote {output} region={manifest['region']} cases={manifest['case_count']} "
        f"train={split_counts.get('train', 0)} validation={split_counts.get('validation', 0)} "
        f"test={split_counts.get('test', 0)} status={status}"
    )


if __name__ == "__main__":
    raise SystemExit(main())
