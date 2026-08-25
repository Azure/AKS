#!/usr/bin/env python3
"""Populate regional Aurora NPZ datasets from public WeatherBench2 ERA5."""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable

import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from build_regional_benchmark_manifest import main as build_manifest_main


DEFAULT_STORE = "gs://weatherbench2/datasets/era5/1959-2023_01_10-wb13-6h-1440x721_with_derived_variables.zarr"
DEFAULT_LEVELS = (50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000)
DEFAULT_HISTORY_HOURS = (-6, 0)
DEFAULT_LEAD_HOURS = (6, 12, 24)
AURORA_PATCH_SIZE = 4

SURFACE_VARS = {
    "2t": "2m_temperature",
    "10u": "10m_u_component_of_wind",
    "10v": "10m_v_component_of_wind",
    "msl": "mean_sea_level_pressure",
}
ATMOS_VARS = {
    "z": "geopotential",
    "u": "u_component_of_wind",
    "v": "v_component_of_wind",
    "t": "temperature",
    "q": "specific_humidity",
}
STATIC_VARS = {
    "z": "geopotential_at_surface",
    "lsm": "land_sea_mask",
    "slt": "soil_type",
}
REGIONS = {
    "hawaii": {"lat": (15.0, 25.0), "lon": (196.0, 210.0), "out": "hawaii-paper"},
    "gulf": {"lat": (18.0, 31.0), "lon": (260.0, 285.0), "out": "gulf-paper"},
    "california": {"lat": (30.0, 42.0), "lon": (232.0, 246.0), "out": "california-paper"},
}


@dataclass(frozen=True)
class Candidate:
    time: datetime
    score: float
    wind_max: float
    msl_range: float
    temp_spread: float
    wind_ramp: float = math.nan
    msl_tendency: float = math.nan
    temp_tendency: float = math.nan
    wind_direction_shift: float = math.nan
    moisture_tendency: float = math.nan


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Populate regional WeatherBench2 NPZ files for Aurora.")
    parser.add_argument("--region", choices=sorted(REGIONS), action="append", help="region to populate; repeatable")
    parser.add_argument("--output-root", type=Path, default=Path("/data/aurora-data"))
    parser.add_argument("--output-name", help="override output directory name; only valid with one region")
    parser.add_argument("--store", default=DEFAULT_STORE)
    parser.add_argument("--start", default="2018-01-01T00:00")
    parser.add_argument("--end", default="2022-12-31T18:00")
    parser.add_argument("--candidate-stride-days", type=int, default=5)
    parser.add_argument("--hours", default="0,12", help="comma-separated UTC hours for candidate initializations")
    parser.add_argument("--cases-per-region", type=int, default=150)
    parser.add_argument("--event-fraction", type=float, default=0.5)
    parser.add_argument("--lead-hours", default="6,12,24")
    parser.add_argument("--levels", default=",".join(str(v) for v in DEFAULT_LEVELS))
    parser.add_argument(
        "--selection",
        choices=["event-balanced", "transition-balanced", "regime-longlead", "calendar"],
        default="event-balanced",
    )
    parser.add_argument("--min-test-count", type=int, default=30)
    parser.add_argument("--min-test-seasons", type=int, default=2)
    parser.add_argument(
        "--write-batch-size",
        type=int,
        default=25,
        help="number of selected cases to materialize from WeatherBench2 per read batch",
    )
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    ensure_runtime_deps()
    import xarray as xr

    regions = args.region or sorted(REGIONS)
    if args.output_name and len(regions) != 1:
        raise ValueError("--output-name is only valid when exactly one --region is selected")
    lead_hours = parse_int_list(args.lead_hours)
    levels = parse_int_list(args.levels)
    hours = parse_int_list(args.hours)
    ds = open_weatherbench_store(xr, args.store)
    created: list[dict[str, Any]] = []
    for region_name in regions:
        spec = REGIONS[region_name]
        out_dir = args.output_root / (args.output_name or spec["out"])
        region_ds = select_region(ds, spec["lat"], spec["lon"])
        candidate_times = generate_candidate_times(
            parse_datetime(args.start),
            parse_datetime(args.end),
            stride_days=args.candidate_stride_days,
            hours=hours,
            max_lead_hours=max(lead_hours),
        )
        print(
            f"Scoring {len(candidate_times)} candidate initializations for {region_name} "
            f"with selection={args.selection}",
            flush=True,
        )
        selected = select_cases(
            region_ds,
            candidate_times,
            count=args.cases_per_region,
            selection=args.selection,
            event_fraction=args.event_fraction,
            lead_hours=lead_hours,
        )
        print(f"Selected {len(selected)} cases for {region_name}; writing NPZ files", flush=True)
        record = {
            "region": region_name,
            "output_dir": str(out_dir),
            "candidate_count": len(candidate_times),
            "selected_count": len(selected),
            "selection": args.selection,
        }
        if args.dry_run:
            print(json.dumps({**record, "selected": [format_time(item.time) for item in selected[:10]]}, sort_keys=True))
            created.append(record)
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        write_region_cases(
            region_ds,
            out_dir=out_dir,
            cases=selected,
            lead_hours=lead_hours,
            levels=levels,
            overwrite=args.overwrite,
            progress_label=region_name,
            batch_size=args.write_batch_size,
        )
        metadata = {
            **record,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "store": args.store,
            "lat": spec["lat"],
            "lon": spec["lon"],
            "lead_hours": lead_hours,
            "levels": levels,
            "cases": [candidate.__dict__ | {"time": format_time(candidate.time)} for candidate in selected],
            "variables": {
                "surface": SURFACE_VARS,
                "atmospheric": ATMOS_VARS,
                "static": STATIC_VARS,
            },
        }
        (out_dir / "population-metadata.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
        build_manifest_main([
            "--data-dir", str(out_dir),
            "--region-name", region_name,
            "--lead-hours", ",".join(str(v) for v in lead_hours),
            "--min-test-count", str(args.min_test_count),
            "--min-test-seasons", str(args.min_test_seasons),
        ])
        created.append(record)
    # Explicitly close the zarr store before returning so the gcsfs HTTP
    # session releases its socket. Without this, gcsfs/aiohttp leak
    # non-daemon worker threads that keep the interpreter alive past main(),
    # which on Windows manifests as `terraform apply` hanging indefinitely
    # after the generator has finished writing all NPZ files.
    try:
        ds.close()
    except Exception:
        pass
    print(json.dumps({"created": created}, indent=2, sort_keys=True))
    return 0


def ensure_runtime_deps() -> None:
    missing = []
    for module in ("xarray", "zarr", "gcsfs", "dask"):
        try:
            __import__(module)
        except ImportError:
            missing.append(module)
    if missing:
        raise SystemExit(
            "missing WeatherBench2 ingestion dependencies: "
            + ", ".join(missing)
            + ". Install with `python -m pip install xarray zarr gcsfs dask`."
        )


def open_weatherbench_store(xr, store: str):
    kwargs: dict[str, Any] = {"consolidated": True}
    if store.startswith("gs://"):
        kwargs["storage_options"] = {"token": "anon"}
    return xr.open_zarr(store, **kwargs)


def parse_int_list(raw: str) -> list[int]:
    values = [int(item.strip()) for item in raw.replace(":", ",").split(",") if item.strip()]
    if not values:
        raise ValueError(f"expected at least one integer in {raw!r}")
    return values


def parse_datetime(raw: str) -> datetime:
    return datetime.fromisoformat(raw.replace("Z", "+00:00")).replace(tzinfo=None)


def generate_candidate_times(
    start: datetime,
    end: datetime,
    *,
    stride_days: int,
    hours: list[int],
    max_lead_hours: int,
) -> list[datetime]:
    out: list[datetime] = []
    day = datetime(start.year, start.month, start.day)
    latest = end - timedelta(hours=max_lead_hours)
    while day <= latest:
        for hour in hours:
            t = day.replace(hour=hour)
            if start <= t <= latest:
                out.append(t)
        day += timedelta(days=stride_days)
    return out


def select_region(ds, lat_bounds: tuple[float, float], lon_bounds: tuple[float, float]):
    lat_min, lat_max = sorted(lat_bounds)
    lon_min, lon_max = sorted(lon_bounds)
    return trim_region_to_patch(
        ds.sel(latitude=slice(lat_max, lat_min), longitude=slice(lon_min, lon_max)),
        AURORA_PATCH_SIZE,
    )


def trim_region_to_patch(ds, patch_size: int):
    lat_count = len(ds.latitude)
    lon_count = len(ds.longitude)
    target_lat = lat_count - (lat_count % patch_size)
    target_lon = lon_count - (lon_count % patch_size)
    if target_lat <= 0 or target_lon <= 0:
        raise ValueError(
            f"selected region {lat_count}x{lon_count} is smaller than Aurora patch size {patch_size}"
        )
    return ds.isel(latitude=slice(0, target_lat), longitude=slice(0, target_lon))


def select_cases(
    ds,
    times: list[datetime],
    *,
    count: int,
    selection: str,
    event_fraction: float,
    lead_hours: list[int] | None = None,
) -> list[Candidate]:
    if selection == "calendar":
        selected_times = evenly_spaced(times, count)
        return [Candidate(t, math.nan, math.nan, math.nan, math.nan) for t in selected_times]
    if selection == "transition-balanced":
        scored = score_transition_candidates(ds, times, lead_hours or list(DEFAULT_LEAD_HOURS))
    elif selection == "regime-longlead":
        scored = score_regime_longlead_candidates(ds, times, lead_hours or list(DEFAULT_LEAD_HOURS))
    else:
        scored = score_candidates(ds, times)
    event_count = min(len(scored), int(round(count * event_fraction)))
    control_count = max(0, min(len(scored) - event_count, count - event_count))
    events = sorted(scored, key=lambda item: item.score, reverse=True)[:event_count]
    event_times = {item.time for item in events}
    controls = [
        Candidate(t, math.nan, math.nan, math.nan, math.nan)
        for t in evenly_spaced([item.time for item in scored if item.time not in event_times], control_count)
    ]
    return sorted(events + controls, key=lambda item: item.time)


def score_candidates(ds, times: list[datetime]) -> list[Candidate]:
    if not times:
        return []
    time_values = [np.datetime64(time) for time in times]
    frame = ds[
        [
            SURFACE_VARS["10u"],
            SURFACE_VARS["10v"],
            SURFACE_VARS["msl"],
            SURFACE_VARS["2t"],
        ]
    ].sel(time=time_values).load()
    u = np.asarray(frame[SURFACE_VARS["10u"]])
    v = np.asarray(frame[SURFACE_VARS["10v"]])
    msl = np.asarray(frame[SURFACE_VARS["msl"]])
    temp = np.asarray(frame[SURFACE_VARS["2t"]])
    if len(u) != len(times) or len(v) != len(times) or len(msl) != len(times) or len(temp) != len(times):
        raise ValueError("WeatherBench2 candidate selection did not preserve the requested time dimension")

    wind_max = reduce_spatial(np.sqrt(u ** 2 + v ** 2), np.nanmax)
    msl_range = reduce_spatial(msl, np.nanmax) - reduce_spatial(msl, np.nanmin)
    temp_spread = reduce_spatial(temp, np.nanmax) - reduce_spatial(temp, np.nanmin)
    return [
        Candidate(
            time=time,
            score=zsafe(float(wind), 15.0) + zsafe(float(pressure), 800.0) + zsafe(float(temperature), 8.0),
            wind_max=float(wind),
            msl_range=float(pressure),
            temp_spread=float(temperature),
        )
        for time, wind, pressure, temperature in zip(times, wind_max, msl_range, temp_spread, strict=True)
    ]


def score_transition_candidates(ds, times: list[datetime], lead_hours: list[int]) -> list[Candidate]:
    if not times:
        return []
    if not lead_hours:
        raise ValueError("transition scoring requires at least one lead hour")
    time_values = [np.datetime64(time) for time in times]
    init_frame = ds[
        [
            SURFACE_VARS["10u"],
            SURFACE_VARS["10v"],
            SURFACE_VARS["msl"],
            SURFACE_VARS["2t"],
        ]
    ].sel(time=time_values).load()
    u0 = np.asarray(init_frame[SURFACE_VARS["10u"]])
    v0 = np.asarray(init_frame[SURFACE_VARS["10v"]])
    msl0 = np.asarray(init_frame[SURFACE_VARS["msl"]])
    temp0 = np.asarray(init_frame[SURFACE_VARS["2t"]])
    speed0 = np.sqrt(u0 ** 2 + v0 ** 2)
    wind_max = reduce_spatial(speed0, np.nanmax)
    msl_range = reduce_spatial(msl0, np.nanmax) - reduce_spatial(msl0, np.nanmin)
    temp_spread = reduce_spatial(temp0, np.nanmax) - reduce_spatial(temp0, np.nanmin)
    wind_ramp = np.zeros(len(times), dtype=np.float64)
    msl_tendency = np.zeros(len(times), dtype=np.float64)
    temp_tendency = np.zeros(len(times), dtype=np.float64)

    for lead in sorted({int(value) for value in lead_hours}):
        print(f"Scoring transition lead={lead}h for {len(times)} candidates", flush=True)
        future_times = [np.datetime64(time + timedelta(hours=lead)) for time in times]
        future_frame = ds[
            [
                SURFACE_VARS["10u"],
                SURFACE_VARS["10v"],
                SURFACE_VARS["msl"],
                SURFACE_VARS["2t"],
            ]
        ].sel(time=future_times).load()
        u1 = np.asarray(future_frame[SURFACE_VARS["10u"]])
        v1 = np.asarray(future_frame[SURFACE_VARS["10v"]])
        msl1 = np.asarray(future_frame[SURFACE_VARS["msl"]])
        temp1 = np.asarray(future_frame[SURFACE_VARS["2t"]])
        speed1 = np.sqrt(u1 ** 2 + v1 ** 2)
        wind_max = np.maximum(wind_max, reduce_spatial(speed1, np.nanmax))
        msl_range = np.maximum(msl_range, reduce_spatial(msl1, np.nanmax) - reduce_spatial(msl1, np.nanmin))
        temp_spread = np.maximum(temp_spread, reduce_spatial(temp1, np.nanmax) - reduce_spatial(temp1, np.nanmin))
        wind_ramp = np.maximum(wind_ramp, reduce_spatial(np.abs(speed1 - speed0), np.nanmax))
        msl_tendency = np.maximum(msl_tendency, reduce_spatial(np.abs(msl1 - msl0), np.nanmax))
        temp_tendency = np.maximum(temp_tendency, reduce_spatial(np.abs(temp1 - temp0), np.nanmax))

    return [
        Candidate(
            time=time,
            score=(
                zsafe(float(wind_change), 4.0)
                + zsafe(float(pressure_change), 600.0)
                + zsafe(float(temperature_change), 3.0)
                + 0.25 * zsafe(float(wind), 15.0)
                + 0.25 * zsafe(float(pressure_range), 800.0)
            ),
            wind_max=float(wind),
            msl_range=float(pressure_range),
            temp_spread=float(temperature_range),
            wind_ramp=float(wind_change),
            msl_tendency=float(pressure_change),
            temp_tendency=float(temperature_change),
        )
        for time, wind, pressure_range, temperature_range, wind_change, pressure_change, temperature_change in zip(
            times,
            wind_max,
            msl_range,
            temp_spread,
            wind_ramp,
            msl_tendency,
            temp_tendency,
            strict=True,
        )
    ]


def score_regime_longlead_candidates(ds, times: list[datetime], lead_hours: list[int]) -> list[Candidate]:
    """Score candidates for Hawaii-like regimes where persistence should decay.

    This extends transition scoring beyond scalar state changes by adding wind
    direction shifts and low-level moisture change. Those are closer to the
    regime-transition cases we want Hawaii LoRA to learn than raw pressure range.
    """
    if not times:
        return []
    if not lead_hours:
        raise ValueError("regime-longlead scoring requires at least one lead hour")
    time_values = [np.datetime64(time) for time in times]
    init_frame = ds[
        [
            SURFACE_VARS["10u"],
            SURFACE_VARS["10v"],
            SURFACE_VARS["msl"],
            SURFACE_VARS["2t"],
        ]
    ].sel(time=time_values).load()
    q_var = ATMOS_VARS["q"]
    q0 = None
    if q_var in ds:
        q0 = np.asarray(ds[q_var].sel(time=time_values, level=850).load())

    u0 = np.asarray(init_frame[SURFACE_VARS["10u"]])
    v0 = np.asarray(init_frame[SURFACE_VARS["10v"]])
    msl0 = np.asarray(init_frame[SURFACE_VARS["msl"]])
    temp0 = np.asarray(init_frame[SURFACE_VARS["2t"]])
    speed0 = np.sqrt(u0 ** 2 + v0 ** 2)
    wind_max = reduce_spatial(speed0, np.nanmax)
    msl_range = reduce_spatial(msl0, np.nanmax) - reduce_spatial(msl0, np.nanmin)
    temp_spread = reduce_spatial(temp0, np.nanmax) - reduce_spatial(temp0, np.nanmin)
    wind_ramp = np.zeros(len(times), dtype=np.float64)
    msl_tendency = np.zeros(len(times), dtype=np.float64)
    temp_tendency = np.zeros(len(times), dtype=np.float64)
    wind_direction_shift = np.zeros(len(times), dtype=np.float64)
    moisture_tendency = np.zeros(len(times), dtype=np.float64)

    for lead in sorted({int(value) for value in lead_hours}):
        print(f"Scoring regime-longlead lead={lead}h for {len(times)} candidates", flush=True)
        future_times = [np.datetime64(time + timedelta(hours=lead)) for time in times]
        future_frame = ds[
            [
                SURFACE_VARS["10u"],
                SURFACE_VARS["10v"],
                SURFACE_VARS["msl"],
                SURFACE_VARS["2t"],
            ]
        ].sel(time=future_times).load()
        u1 = np.asarray(future_frame[SURFACE_VARS["10u"]])
        v1 = np.asarray(future_frame[SURFACE_VARS["10v"]])
        msl1 = np.asarray(future_frame[SURFACE_VARS["msl"]])
        temp1 = np.asarray(future_frame[SURFACE_VARS["2t"]])
        speed1 = np.sqrt(u1 ** 2 + v1 ** 2)
        wind_max = np.maximum(wind_max, reduce_spatial(speed1, np.nanmax))
        msl_range = np.maximum(msl_range, reduce_spatial(msl1, np.nanmax) - reduce_spatial(msl1, np.nanmin))
        temp_spread = np.maximum(temp_spread, reduce_spatial(temp1, np.nanmax) - reduce_spatial(temp1, np.nanmin))
        wind_ramp = np.maximum(wind_ramp, reduce_spatial(np.abs(speed1 - speed0), np.nanmax))
        msl_tendency = np.maximum(msl_tendency, reduce_spatial(np.abs(msl1 - msl0), np.nanmax))
        temp_tendency = np.maximum(temp_tendency, reduce_spatial(np.abs(temp1 - temp0), np.nanmax))
        wind_direction_shift = np.maximum(
            wind_direction_shift,
            reduce_spatial(wind_direction_change_degrees(u0, v0, u1, v1), np.nanmax),
        )
        if q0 is not None:
            q1 = np.asarray(ds[q_var].sel(time=future_times, level=850).load())
            moisture_tendency = np.maximum(moisture_tendency, reduce_spatial(np.abs(q1 - q0), np.nanmax))

    return [
        Candidate(
            time=time,
            score=(
                zsafe(float(wind_change), 6.0)
                + zsafe(float(direction_change), 60.0)
                + zsafe(float(pressure_change), 600.0)
                + zsafe(float(temperature_change), 6.0)
                + zsafe(float(moisture_change), 0.003)
                + 0.2 * zsafe(float(wind), 15.0)
                + 0.1 * zsafe(float(pressure_range), 800.0)
                + 0.1 * zsafe(float(temperature_range), 8.0)
            ),
            wind_max=float(wind),
            msl_range=float(pressure_range),
            temp_spread=float(temperature_range),
            wind_ramp=float(wind_change),
            msl_tendency=float(pressure_change),
            temp_tendency=float(temperature_change),
            wind_direction_shift=float(direction_change),
            moisture_tendency=float(moisture_change),
        )
        for (
            time,
            wind,
            pressure_range,
            temperature_range,
            wind_change,
            pressure_change,
            temperature_change,
            direction_change,
            moisture_change,
        ) in zip(
            times,
            wind_max,
            msl_range,
            temp_spread,
            wind_ramp,
            msl_tendency,
            temp_tendency,
            wind_direction_shift,
            moisture_tendency,
            strict=True,
        )
    ]


def reduce_spatial(values: np.ndarray, reducer) -> np.ndarray:
    arr = np.asarray(values)
    if arr.ndim < 2:
        raise ValueError(f"expected time plus spatial dimensions, got shape {arr.shape}")
    return reducer(arr, axis=tuple(range(1, arr.ndim)))


def wind_direction_change_degrees(
    u0: np.ndarray,
    v0: np.ndarray,
    u1: np.ndarray,
    v1: np.ndarray,
    *,
    min_speed: float = 2.0,
) -> np.ndarray:
    speed0 = np.sqrt(u0 ** 2 + v0 ** 2)
    speed1 = np.sqrt(u1 ** 2 + v1 ** 2)
    angle0 = np.arctan2(v0, u0)
    angle1 = np.arctan2(v1, u1)
    wrapped = np.arctan2(np.sin(angle1 - angle0), np.cos(angle1 - angle0))
    degrees = np.abs(np.degrees(wrapped))
    return np.where((speed0 >= min_speed) & (speed1 >= min_speed), degrees, 0.0)


def score_candidate(ds, time: datetime) -> Candidate:
    frame = ds.sel(time=np.datetime64(time))
    u = np.asarray(frame[SURFACE_VARS["10u"]].load())
    v = np.asarray(frame[SURFACE_VARS["10v"]].load())
    msl = np.asarray(frame[SURFACE_VARS["msl"]].load())
    temp = np.asarray(frame[SURFACE_VARS["2t"]].load())
    wind_max = float(np.sqrt(u ** 2 + v ** 2).max())
    msl_range = float(np.nanmax(msl) - np.nanmin(msl))
    temp_spread = float(np.nanmax(temp) - np.nanmin(temp))
    score = zsafe(wind_max, 15.0) + zsafe(msl_range, 800.0) + zsafe(temp_spread, 8.0)
    return Candidate(time, score, wind_max, msl_range, temp_spread)


def zsafe(value: float, scale: float) -> float:
    return value / scale if math.isfinite(value) else 0.0


def evenly_spaced(items: list[datetime], count: int) -> list[datetime]:
    if count <= 0 or not items:
        return []
    if len(items) <= count:
        return list(items)
    if count == 1:
        return [items[len(items) // 2]]
    return [items[round(i * (len(items) - 1) / (count - 1))] for i in range(count)]


def write_region_cases(
    ds,
    *,
    out_dir: Path,
    cases: list[Candidate],
    lead_hours: list[int],
    levels: list[int],
    overwrite: bool,
    progress_label: str | None = None,
    batch_size: int = 25,
) -> None:
    total = len(cases)
    if total == 0:
        return
    batch_size = total if batch_size <= 0 else batch_size
    common_payload = {
        "lat": np.asarray(ds.latitude.values, dtype=np.float32),
        "lon": np.asarray(ds.longitude.values, dtype=np.float32),
        "levels": np.asarray(levels, dtype=np.int32),
        **{f"static_{out_name}": select_static(ds, var_name) for out_name, var_name in STATIC_VARS.items()},
    }
    written = 0
    for batch_start in range(0, total, batch_size):
        batch_cases = cases[batch_start:batch_start + batch_size]
        cache = load_case_batch(ds, batch_cases, lead_hours=lead_hours, levels=levels)
        for case in batch_cases:
            init_path = out_dir / f"init-{format_time(case.time)}.npz"
            if overwrite or not init_path.exists():
                write_init_npz_from_cache(case.time, init_path, cache, common_payload)
            for lead in lead_hours:
                truth_time = case.time + timedelta(hours=int(lead))
                truth_path = out_dir / f"truth-{format_time(truth_time)}.npz"
                if overwrite or not truth_path.exists():
                    write_truth_npz_from_cache(truth_time, truth_path, cache, common_payload)
            written += 1
            if progress_label and (written == 1 or written % 25 == 0 or written == total):
                print(f"{progress_label}: wrote {written}/{total} cases", flush=True)


def load_case_batch(ds, cases: list[Candidate], *, lead_hours: list[int], levels: list[int]) -> dict[str, Any]:
    surface_times = unique_datetimes(
        time
        for case in cases
        for time in case_surface_times(case.time, lead_hours)
    )
    history_times = unique_datetimes(
        case.time + timedelta(hours=offset)
        for case in cases
        for offset in DEFAULT_HISTORY_HOURS
    )
    return {
        "surface_times": {format_time(time): index for index, time in enumerate(surface_times)},
        "history_times": {format_time(time): index for index, time in enumerate(history_times)},
        "surface": {
            out_name: select_time_stack(ds[var_name], surface_times)
            for out_name, var_name in SURFACE_VARS.items()
        },
        "atmos": {
            out_name: select_time_level_stack(ds[var_name], history_times, levels)
            for out_name, var_name in ATMOS_VARS.items()
        },
    }


def case_surface_times(init_time: datetime, lead_hours: list[int]) -> list[datetime]:
    return (
        [init_time + timedelta(hours=offset) for offset in DEFAULT_HISTORY_HOURS]
        + [init_time + timedelta(hours=int(lead)) for lead in lead_hours]
    )


def unique_datetimes(values: Iterable[datetime]) -> list[datetime]:
    return sorted({value for value in values})


def write_init_npz_from_cache(init_time: datetime, path: Path, cache: dict[str, Any], common_payload: dict[str, Any]) -> None:
    history_times = [init_time + timedelta(hours=offset) for offset in DEFAULT_HISTORY_HOURS]
    surface_indices = [cache["surface_times"][format_time(time)] for time in history_times]
    history_indices = [cache["history_times"][format_time(time)] for time in history_times]
    payload: dict[str, Any] = {
        **common_payload,
        "times": np.asarray(history_times, dtype="datetime64[ns]"),
    }
    for out_name in SURFACE_VARS:
        payload[f"surf_{out_name}"] = cache["surface"][out_name][surface_indices][None, ...]
    for out_name in ATMOS_VARS:
        payload[f"atmos_{out_name}"] = cache["atmos"][out_name][history_indices][None, ...]
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, **payload)


def write_truth_npz_from_cache(truth_time: datetime, path: Path, cache: dict[str, Any], common_payload: dict[str, Any]) -> None:
    index = cache["surface_times"][format_time(truth_time)]
    payload: dict[str, Any] = {
        "lat": common_payload["lat"],
        "lon": common_payload["lon"],
        "times": np.asarray([truth_time], dtype="datetime64[ns]"),
    }
    for out_name in SURFACE_VARS:
        payload[f"surf_{out_name}"] = cache["surface"][out_name][[index]][None, ...]
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, **payload)


def write_init_npz(ds, init_time: datetime, path: Path, levels: list[int]) -> None:
    history_times = [init_time + timedelta(hours=offset) for offset in DEFAULT_HISTORY_HOURS]
    payload: dict[str, Any] = {
        "lat": np.asarray(ds.latitude.values, dtype=np.float32),
        "lon": np.asarray(ds.longitude.values, dtype=np.float32),
        "levels": np.asarray(levels, dtype=np.int32),
        "times": np.asarray(history_times, dtype="datetime64[ns]"),
    }
    for out_name, var_name in SURFACE_VARS.items():
        payload[f"surf_{out_name}"] = select_time_stack(ds[var_name], history_times)[None, ...]
    for out_name, var_name in ATMOS_VARS.items():
        payload[f"atmos_{out_name}"] = select_time_level_stack(ds[var_name], history_times, levels)[None, ...]
    for out_name, var_name in STATIC_VARS.items():
        payload[f"static_{out_name}"] = select_static(ds, var_name)
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, **payload)


def write_truth_npz(ds, truth_time: datetime, path: Path) -> None:
    payload: dict[str, Any] = {
        "lat": np.asarray(ds.latitude.values, dtype=np.float32),
        "lon": np.asarray(ds.longitude.values, dtype=np.float32),
        "times": np.asarray([truth_time], dtype="datetime64[ns]"),
    }
    for out_name, var_name in SURFACE_VARS.items():
        payload[f"surf_{out_name}"] = select_time_stack(ds[var_name], [truth_time])[None, ...]
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, **payload)


def select_time_stack(data_array, times: Iterable[datetime]) -> np.ndarray:
    values = data_array.sel(time=[np.datetime64(t) for t in times]).load()
    return np.asarray(values, dtype=np.float32)


def select_time_level_stack(data_array, times: Iterable[datetime], levels: list[int]) -> np.ndarray:
    values = data_array.sel(time=[np.datetime64(t) for t in times], level=levels).load()
    return np.asarray(values, dtype=np.float32)


def select_static(ds, var_name: str) -> np.ndarray:
    if var_name not in ds:
        if var_name == "soil_type":
            return np.zeros((len(ds.latitude), len(ds.longitude)), dtype=np.float32)
        raise KeyError(f"static variable {var_name!r} missing from WeatherBench2 store")
    values = ds[var_name]
    if "time" in values.dims:
        values = values.isel(time=0)
    if "level" in values.dims:
        values = values.isel(level=0)
    return np.asarray(values.load(), dtype=np.float32)


def format_time(value: datetime) -> str:
    return value.strftime("%Y-%m-%d-%Hz")


if __name__ == "__main__":
    # gcsfs/aiohttp spawn non-daemon background threads for HTTP keep-alive
    # connection pools that survive past the natural end of main(). Calling
    # sys.exit() (or letting the interpreter run __atexit__ + shutdown) would
    # block on joining those threads, hanging the process for the caller
    # (terraform local-exec, CI, etc.). Force-exit with the script's status
    # code instead.
    os._exit(main())
