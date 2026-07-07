"""Cross-platform helper for Terraform local-exec that uploads the ViGGO dataset.

This script handles downloading the ViGGO NLG dataset and uploading it to Azure
Blob Storage. It works on Windows, Linux, and macOS without requiring a POSIX shell.

It reads configuration from environment variables set by Terraform:
  STORAGE_ACCOUNT  — Azure storage account name
  CONTAINER_NAME   — Azure blob container name (e.g. "llm-pipeline")
  RESOURCE_GROUP   — Azure resource group name
"""

import atexit
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# Timeout for network operations (seconds). Prevents indefinite hangs on
# flaky connections during the viggo dataset download.
socket.setdefaulttimeout(120)

BASE_URL = "https://viggo-ds.s3.amazonaws.com/"
FILES = ["train.jsonl", "val.jsonl", "test.jsonl", "dataset_info.json"]


def find_az():
    """Locate the az CLI executable (handles az.cmd on Windows)."""
    az = shutil.which("az")
    if az is None:
        print("ERROR: 'az' CLI not found on PATH.", file=sys.stderr)
        sys.exit(1)
    return az


def main():
    # Read required environment variables
    storage_account = os.environ.get("STORAGE_ACCOUNT")
    container_name = os.environ.get("CONTAINER_NAME")
    resource_group = os.environ.get("RESOURCE_GROUP")

    if not storage_account or not container_name or not resource_group:
        print(
            "ERROR: STORAGE_ACCOUNT, CONTAINER_NAME, and RESOURCE_GROUP "
            "environment variables must be set.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Step 1: Create a temporary directory with cleanup registered
    tmpdir = Path(tempfile.mkdtemp(prefix="viggo_dataset_"))
    atexit.register(shutil.rmtree, str(tmpdir), True)

    print(f"==> Created temporary directory: {tmpdir}")

    # Step 2: Download dataset files
    print("==> Downloading ViGGO dataset files...")
    for filename in FILES:
        url = BASE_URL + filename
        dest = tmpdir / filename
        print(f"    Downloading {filename}...")
        local_path, _ = urllib.request.urlretrieve(url, str(dest))
        size = Path(local_path).stat().st_size
        print(f"    Downloaded {filename} ({size} bytes)")

    # Step 3: Rewrite dataset_info.json to use basenames for file_name fields
    print("==> Rewriting dataset_info.json file_name fields to use basenames...")
    dataset_info_path = tmpdir / "dataset_info.json"
    with open(dataset_info_path, "r", encoding="utf-8") as f:
        dataset_info = json.load(f)

    for dataset_name, entry in dataset_info.items():
        if "file_name" in entry:
            entry["file_name"] = os.path.basename(entry["file_name"])

    with open(dataset_info_path, "w", encoding="utf-8") as f:
        json.dump(dataset_info, f, indent=2)

    print("    dataset_info.json rewritten with basename-only file_name fields")

    # Step 4: Upload all files to blob storage
    print(f"==> Uploading files to {container_name}/data/ ...")

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
        str(tmpdir),
        "--auth-mode",
        "login",
        "--overwrite",
        "--only-show-errors",
    ]

    print("    Trying upload with --auth-mode login...")
    result = subprocess.run(upload_cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print("    Auth-mode login failed, falling back to storage key...")

        # Get storage account key
        key_cmd = [
            az,
            "storage",
            "account",
            "keys",
            "list",
            "--account-name",
            storage_account,
            "--resource-group",
            resource_group,
            "--query",
            "[0].value",
            "-o",
            "tsv",
        ]

        key_result = subprocess.run(key_cmd, capture_output=True, text=True)
        if key_result.returncode != 0:
            print(
                f"ERROR: Failed to retrieve storage key:\n{key_result.stderr}",
                file=sys.stderr,
            )
            sys.exit(1)

        storage_key = key_result.stdout.strip()

        # Retry upload with storage key in environment
        upload_cmd_no_auth = [
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
            str(tmpdir),
            "--overwrite",
            "--only-show-errors",
        ]

        env = {**os.environ, "AZURE_STORAGE_KEY": storage_key}
        retry_result = subprocess.run(
            upload_cmd_no_auth, capture_output=True, text=True, env=env
        )

        if retry_result.returncode != 0:
            print(
                f"ERROR: Upload failed with storage key:\n{retry_result.stderr}",
                file=sys.stderr,
            )
            sys.exit(1)

        print("    Upload succeeded using storage key")
    else:
        print("    Upload succeeded using auth-mode login")

    # Step 5: Success
    print(
        f"==> Successfully uploaded ViGGO dataset to "
        f"{storage_account}/{container_name}/data/"
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
