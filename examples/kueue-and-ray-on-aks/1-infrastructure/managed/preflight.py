#!/usr/bin/env python3
"""Read-only safety checks for a managed-extension example target."""

import argparse
import json
import sys

EXTENSIONS = ("microsoft.kueue", "microsoft.kuberay")
DEPLOYMENTS = {
    "microsoft.kueue": ("kueue-system", {"kueue-controller-manager", "kueue-extension"}),
    "microsoft.kuberay": ("kuberay-system", {"kuberay-operator"}),
}


def extension_names(items):
    result = {}
    for kind in EXTENSIONS:
        matches = [x for x in items if x.get("extensionType", "").lower() == kind]
        if len(matches) > 1:
            raise ValueError(f"Multiple {kind} extension instances; review the target manually")
        if matches:
            item = matches[0]
            if item.get("state") != "Succeeded":
                raise ValueError(f"Existing {kind} operation isn't successful; inspect it before retrying")
            result[kind] = item["name"]
    return result


def controller_type(deployment):
    name = deployment["metadata"]["name"]
    images = [x.get("image", "") for x in deployment.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])]
    if name == "kueue-extension" or name.endswith("kueue-controller-manager") or any("/kueue/kueue:" in x or "/kueue/kueue@" in x or "kueue-extension-controller" in x for x in images):
        return "microsoft.kueue"
    if name.endswith("kuberay-operator") or any("/kuberay/operator:" in x or "/kuberay/operator@" in x for x in images):
        return "microsoft.kuberay"
    return None


def check_deployments(items, managed):
    for item in items:
        kind = controller_type(item)
        if kind is None:
            continue
        metadata = item["metadata"]
        namespace, names = DEPLOYMENTS[kind]
        release = metadata.get("annotations", {}).get("meta.helm.sh/release-name")
        if kind not in managed or metadata.get("namespace") != namespace or metadata["name"] not in names or release != managed[kind]:
            raise ValueError(
                f"Existing controller {metadata.get('namespace')}/{metadata['name']} isn't owned by the expected managed extension; "
                "use a clean cluster or an owner-reviewed removal/migration plan. No ownership transfer is performed"
            )


def check_crds(items, managed):
    groups = {"kueue.x-k8s.io": "microsoft.kueue", "ray.io": "microsoft.kuberay"}
    for item in items:
        kind = groups.get(item.get("spec", {}).get("group"))
        if kind and kind not in managed:
            raise ValueError(
                f"Existing {item['metadata']['name']} without its managed extension; review retained resources before installation. "
                "Don't delete CRDs or rewrite ownership to bypass this check"
            )


def check_provisioning_api(crd):
    if not any(x.get("name") == "v1" and x.get("served") is True for x in crd["spec"]["versions"]):
        raise ValueError("The shared ProvisioningRequest CRD must serve v1")
    if not any(x.get("type") == "Established" and x.get("status") == "True" for x in crd.get("status", {}).get("conditions", [])):
        raise ValueError("The shared ProvisioningRequest API isn't established yet")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("names", "deployments", "crds", "provisioning-api"))
    parser.add_argument("--extensions", required=True)
    args = parser.parse_args()
    with open(args.extensions, encoding="utf-8") as stream:
        managed = extension_names(json.load(stream))
    if args.mode == "names":
        print(json.dumps(managed))
        return
    incoming = json.load(sys.stdin)
    if args.mode == "deployments":
        check_deployments(incoming.get("items", []), managed)
    elif args.mode == "crds":
        check_crds(incoming.get("items", []), managed)
    else:
        check_provisioning_api(incoming)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError) as error:
        print(f"Preflight failed: {error}", file=sys.stderr)
        sys.exit(1)
