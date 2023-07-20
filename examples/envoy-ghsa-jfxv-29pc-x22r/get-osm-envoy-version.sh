#!/bin/bash

kubectl get deploy -n kube-system osm-injector -o json | jq '.spec.template.spec.containers[].env[] | select(.name == "OSM_DEFAULT_ENVOY_IMAGE")'
