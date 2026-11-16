#!/usr/bin/env bash
# PIS NodeImageBuildTime customization: bake Qwen2.5-7B-Instruct weights into the image.
# Lessons baked in from prior runs: Ubuntu 24.04 PEP-668 -> use a venv; huggingface_hub 1.x
# dropped the [cli] extra -> use `hf download`; no trailing positionals (they become filenames).
set -euxo pipefail

MODEL_ID="Qwen/Qwen2.5-7B-Instruct"
MODEL_DIR="/opt/models/qwen"
mkdir -p "$MODEL_DIR"

# The node image ships python3 but not the venv module (PEP-668 base). Install it first.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3-venv python3-pip

python3 -m venv /opt/hfenv
/opt/hfenv/bin/pip install --upgrade pip
/opt/hfenv/bin/pip install "huggingface_hub[hf_transfer]"

HF_HUB_ENABLE_HF_TRANSFER=1 /opt/hfenv/bin/hf download "$MODEL_ID" --local-dir "$MODEL_DIR"

cat > /opt/pis-marker <<MARKER
pis_customized=true
example=model-weights
model_id=$MODEL_ID
model_dir=$MODEL_DIR
MARKER
du -sh "$MODEL_DIR" || true
ls -la "$MODEL_DIR" || true
