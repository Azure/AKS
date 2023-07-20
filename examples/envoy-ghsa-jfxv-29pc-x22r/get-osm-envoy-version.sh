#!/bin/bash

kubectl get deploy -nkube-system osm-injector -ojson | jq '.spec.template.spec.containers[].env[] | select(.name == "OSM_DEFAULT_ENVOY_IMAGE")'
