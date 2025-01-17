# Telemetry samples

The addon already has native integration with Azure managed Prometheus and managed Grafana etc. We strongly recommend Azure customers use these managed solutions.

Based on artifacts from the open-source community, this directory contains sample deployments of observability in a **self**-managed scenario.

## Prometheus + Grafana

### Install

```shell
kubectl apply prometheus.yaml
kubectl apply grafana.yaml
```

### Test Grafana

```shell
kubectl -n aks-istio-system port-forward service/grafana 3000:3000
```

Open http://localhost:3000 in your browser to monitor the health status of your mesh.