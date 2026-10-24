# Prepare data for the managed Ray examples

The managed operators don't upload datasets. Use your existing compatible data,
or prepare the sample files below. Run uploads as an identity with Storage Blob
Data Contributor access to the account from [managed setup](README.md). All
uploads use Azure AD; don't retrieve account keys to bypass a permission error.

## Prerequisites

- Python 3.10 or later for the WeatherBench2 generator, plus its requirements.
- Azure CLI signed in to the intended subscription.
- `AZURE_STORAGE_ACCOUNT_NAME` and `SUBSCRIPTION_ID` from managed setup.
- Private `aurora` and `llm-pipeline` containers already created.

From `examples/kueue-and-ray-on-aks`, set:

```bash
EXAMPLES_DIR="$PWD"
DATA_DIR="$HOME/ray-example-data"
mkdir -p "$DATA_DIR"
```

## Aurora input and truth files

The default workload settings expect `aurora/data/init-2021-01-01-00z.npz` and
`aurora/data/truth-2021-01-01-06z.npz`. Generate the matching regional case with
the existing sample generator. Its first WeatherBench2 access can download a
substantial amount of data:

```bash
python3 -m pip install -r "$EXAMPLES_DIR/1-infrastructure/terraform/requirements-generator.txt"
python3 "$EXAMPLES_DIR/1-infrastructure/terraform/scripts/populate_weatherbench2_regional_data.py" \
  --region gulf --output-root "$DATA_DIR" --output-name aurora \
  --start 2021-01-01T00:00 --end 2021-01-01T12:00 \
  --candidate-stride-days 1 --hours 0 --cases-per-region 1 \
  --lead-hours 6 --selection calendar --min-test-count 1 \
  --min-test-seasons 1 --write-batch-size 1

az storage blob upload-batch --subscription "$SUBSCRIPTION_ID" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --destination aurora \
  --destination-path data --source "$DATA_DIR/aurora" --pattern '*.npz' \
  --auth-mode login --overwrite true
az storage blob list --subscription "$SUBSCRIPTION_ID" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --container-name aurora \
  --prefix data/ --auth-mode login --output table
```

Verify both expected files before submitting the workload. If you choose another
case date, set `AURORA_INIT_FILE` and `AURORA_TRUTH_FILE` to the actual uploaded
names before sourcing the workload's `env.example`; don't silently relabel the
timestamps or assume the defaults still match.

## ViGGO training and inference files

Download the four files used by the sample and normalize metadata file names to
basenames, matching the workload's expectations:

```bash
mkdir -p "$DATA_DIR/viggo"
for FILE in train.jsonl val.jsonl test.jsonl dataset_info.json; do
  curl --fail --location "https://viggo-ds.s3.amazonaws.com/$FILE" \
    --output "$DATA_DIR/viggo/$FILE"
done
python3 - "$DATA_DIR/viggo/dataset_info.json" <<'PY'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
for entry in data.values():
    if "file_name" in entry:
        entry["file_name"] = os.path.basename(entry["file_name"])
path.write_text(json.dumps(data, indent=2))
PY
az storage blob upload-batch --subscription "$SUBSCRIPTION_ID" \
  --account-name "$AZURE_STORAGE_ACCOUNT_NAME" --destination llm-pipeline \
  --destination-path data --source "$DATA_DIR/viggo" \
  --auth-mode login --overwrite true
```

Keep the `llm-pipeline` container name: the current training code uses it. LLM
training writes its LoRA adapter and pointer under `lora/`; run batch inference
only after those artifacts exist. Online serving similarly requires the Aurora
checkpoint from a completed fine-tuning Job.

The legacy Terraform upload helpers have their own behavior and aren't invoked
by this managed path. Dataset uploads, successful identity authentication, model
training, inference, and serving must be observed separately; an operator
readiness check or a rendered manifest doesn't prove them.
