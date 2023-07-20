#!/bin/bash

kubectl get deploy -naks-istio-system istiod-asm-1-17 -ojson | jq '.spec.template.spec.containers[].image'
