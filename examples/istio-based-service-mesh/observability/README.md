# Telemetry samples

This directory contains sample deployments of observability with self managed prometheus and self managed grafana.

## Install

```shell
kubectl apply prometheus.yaml
kubectl apply grafana.yaml
```

## Test Grafana

```shell
kubectl -n aks-istio-system port-forward service/grafana 3000:3000
```

Open http://localhost:3000 in your browser monitor the health status of your mesh.