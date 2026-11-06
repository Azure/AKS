# Terraform directory notes

Follow [managed setup](../managed/) to prepare the AKS target and install the
managed KubeRay and Kueue extensions. This directory isn't an operator-install
entry point for the three-module walkthrough.

## Dataset helpers

The managed examples still use these files:

- [WeatherBench2 regional data generator](scripts/populate_weatherbench2_regional_data.py).
- [Generator requirements](requirements-generator.txt).

Use the copyable generation and upload commands in
[managed dataset preparation](../managed/data.md). The managed operators don't
create or upload application datasets.

## Retained resource files

The Terraform resource files remain for existing environments. They include
Helm-managed operator resources, so don't apply this configuration to a cluster
using the managed extensions. Removing the previous installation guide doesn't
migrate Terraform state, transfer controller ownership, or delete existing
resources.

Keep existing state and resources intact until their owners plan any lifecycle
changes. Use the managed setup guide for this example, not a second operator
installation or a blanket infrastructure teardown.
