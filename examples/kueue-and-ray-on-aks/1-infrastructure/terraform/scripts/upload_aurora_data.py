"""Cross-platform helper for Terraform local-exec that uploads Aurora weather data.

This script handles generating WeatherBench2 data and uploading it to Azure Blob
Storage. It works on Windows, Linux, and macOS without requiring a POSIX shell.

It reads configuration entirely from environment variables set by the Terraform
null_resource provisioner:

    GENERATOR_PATH   — path to the WeatherBench2 generator Python script
    AURORA_REGION    — region key (e.g. "gulf")
    AURORA_INIT_DATE — init timestamp in format "YYYY-MM-DDTHH:MM"
    STORAGE_ACCOUNT  — Azure storage account name
    CONTAINER_NAME   — Azure blob container name
    RESOURCE_GROUP   — Azure resource group name
"""

import atexit
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path


def find_az():
    """Locate the az CLI executable (handles az.cmd on Windows)."""
    az = shutil.which("az")
    if az is None:
        print("ERROR: 'az' CLI not found on PATH.", file=sys.stderr)
        sys.exit(1)
    return az


def main():
    # -------------------------------------------------------------------------
    # Read environment variables
    # -------------------------------------------------------------------------
    generator_path = os.environ.get("GENERATOR_PATH", "")
    aurora_region = os.environ.get("AURORA_REGION", "")
    aurora_init_date = os.environ.get("AURORA_INIT_DATE", "")
    storage_account = os.environ.get("STORAGE_ACCOUNT", "")
    container_name = os.environ.get("CONTAINER_NAME", "")
    resource_group = os.environ.get("RESOURCE_GROUP", "")

    missing = []
    for name in (
        "GENERATOR_PATH",
        "AURORA_REGION",
        "AURORA_INIT_DATE",
        "STORAGE_ACCOUNT",
        "CONTAINER_NAME",
        "RESOURCE_GROUP",
    ):
        if not os.environ.get(name):
            missing.append(name)
    if missing:
        print(
            f"ERROR: Missing required environment variables: {', '.join(missing)}",
            file=sys.stderr,
        )
        sys.exit(1)

    # -------------------------------------------------------------------------
    # Step 1: Verify the generator script exists
    # -------------------------------------------------------------------------
    generator = Path(generator_path)
    if not generator.is_file():
        print(
            f"ERROR: Generator script not found at: {generator}",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"==> Generator script found: {generator}")

    # -------------------------------------------------------------------------
    # Step 2: Create temporary directory (cleaned up on exit)
    # -------------------------------------------------------------------------
    tmpdir = tempfile.mkdtemp(prefix="aurora_data_")
    atexit.register(shutil.rmtree, tmpdir, ignore_errors=True)
    print(f"==> Created temporary directory: {tmpdir}")

    # -------------------------------------------------------------------------
    # Step 3: Compute END_DATE = AURORA_INIT_DATE + 12 hours
    # -------------------------------------------------------------------------
    init_dt = datetime.strptime(aurora_init_date, "%Y-%m-%dT%H:%M")
    end_dt = init_dt + timedelta(hours=12)
    end_date = end_dt.strftime("%Y-%m-%dT%H:%M")

    # -------------------------------------------------------------------------
    # Step 4: Extract the hour from AURORA_INIT_DATE
    # -------------------------------------------------------------------------
    hour = str(init_dt.hour)

    print(f"==> Init date: {aurora_init_date}, End date: {end_date}, Hour: {hour}")

    # -------------------------------------------------------------------------
    # Step 5: Run the generator script
    # -------------------------------------------------------------------------
    print("==> Running WeatherBench2 generator...")

    generator_cmd = [
        sys.executable,
        str(generator),
        "--region",
        aurora_region,
        "--output-root",
        tmpdir,
        "--output-name",
        "real-weather",
        "--start",
        aurora_init_date,
        "--end",
        end_date,
        "--candidate-stride-days",
        "1",
        "--hours",
        hour,
        "--cases-per-region",
        "1",
        "--lead-hours",
        "6",
        "--selection",
        "calendar",
        "--min-test-count",
        "1",
        "--min-test-seasons",
        "1",
        "--write-batch-size",
        "1",
        "--overwrite",
    ]

    result = subprocess.run(generator_cmd, capture_output=True, text=True)

    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    # -------------------------------------------------------------------------
    # Step 6: Check for NPZ files (generator may fail partially but still
    #         produce the files we need)
    # -------------------------------------------------------------------------
    output_dir = Path(tmpdir) / "real-weather"
    init_files = sorted(glob.glob(str(output_dir / "init-*.npz")))
    truth_files = sorted(glob.glob(str(output_dir / "truth-*.npz")))

    if not init_files or not truth_files:
        print(
            "ERROR: Generator did not produce the expected NPZ files "
            f"(init-*.npz and truth-*.npz) in {output_dir}",
            file=sys.stderr,
        )
        if result.returncode != 0:
            print(
                f"ERROR: Generator exited with code {result.returncode}",
                file=sys.stderr,
            )
        sys.exit(1)

    if result.returncode != 0:
        print(
            f"WARNING: Generator exited with code {result.returncode}, "
            "but NPZ files were produced. Continuing..."
        )

    print(f"==> Found init file: {init_files[0]}")
    print(f"==> Found truth file: {truth_files[0]}")

    # -------------------------------------------------------------------------
    # Step 7: Copy files with canonical names to an upload directory
    # -------------------------------------------------------------------------
    upload_dir = tempfile.mkdtemp(prefix="aurora_upload_")
    atexit.register(shutil.rmtree, upload_dir, True)
    print(f"==> Preparing upload directory: {upload_dir}")

    shutil.copy2(init_files[0], Path(upload_dir) / "init-2021-01-01-00z.npz")
    shutil.copy2(truth_files[0], Path(upload_dir) / "truth-2021-01-01-06z.npz")

    # -------------------------------------------------------------------------
    # Step 8: Upload to Azure Blob Storage
    # -------------------------------------------------------------------------
    print(f"==> Uploading to {storage_account}/{container_name}/data/ ...")

    az = find_az()

    upload_cmd = [
        az,
        "storage",
        "blob",
        "upload-batch",
        "--account-name",
        storage_account,
        "--destination",
        container_name,
        "--destination-path",
        "data",
        "--source",
        upload_dir,
        "--auth-mode",
        "login",
        "--overwrite",
        "--only-show-errors",
    ]

    upload_result = subprocess.run(upload_cmd, capture_output=True, text=True)

    if upload_result.returncode != 0:
        print(
            "WARNING: Upload with --auth-mode login failed. Falling back to account key..."
        )
        if upload_result.stderr:
            print(upload_result.stderr, file=sys.stderr)

        # Get storage account key
        keys_cmd = [
            az,
            "storage",
            "account",
            "keys",
            "list",
            "--resource-group",
            resource_group,
            "--account-name",
            storage_account,
            "--output",
            "json",
        ]

        keys_result = subprocess.run(keys_cmd, capture_output=True, text=True)
        if keys_result.returncode != 0:
            print(
                "ERROR: Failed to retrieve storage account keys.",
                file=sys.stderr,
            )
            if keys_result.stderr:
                print(keys_result.stderr, file=sys.stderr)
            shutil.rmtree(upload_dir, ignore_errors=True)
            sys.exit(1)

        keys = json.loads(keys_result.stdout)
        storage_key = keys[0]["value"]

        # Retry upload with account key
        env_with_key = os.environ.copy()
        env_with_key["AZURE_STORAGE_KEY"] = storage_key

        upload_cmd_key = [
            az,
            "storage",
            "blob",
            "upload-batch",
            "--account-name",
            storage_account,
            "--destination",
            container_name,
            "--destination-path",
            "data",
            "--source",
            upload_dir,
            "--overwrite",
            "--only-show-errors",
        ]

        upload_result_key = subprocess.run(
            upload_cmd_key, capture_output=True, text=True, env=env_with_key
        )

        if upload_result_key.returncode != 0:
            print("ERROR: Upload with account key also failed.", file=sys.stderr)
            if upload_result_key.stderr:
                print(upload_result_key.stderr, file=sys.stderr)
            shutil.rmtree(upload_dir, ignore_errors=True)
            sys.exit(1)

        if upload_result_key.stdout:
            print(upload_result_key.stdout)
    else:
        if upload_result.stdout:
            print(upload_result.stdout)

    # -------------------------------------------------------------------------
    # Step 9: Clean up upload directory
    # -------------------------------------------------------------------------
    shutil.rmtree(upload_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # Step 10: Success
    # -------------------------------------------------------------------------
    print("==> Aurora data uploaded successfully.")
    sys.exit(0)


if __name__ == "__main__":
    main()
