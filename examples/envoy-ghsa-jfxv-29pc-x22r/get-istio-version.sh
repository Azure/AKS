#!/bin/bash

kubectl get deploy -n aks-istio-system istiod-asm-1-17 -o json | jq '.spec.template.spec.containers[].image'
