# yunikorn-metrics-bridge

yunikorn-metrics-bridge is a non-intrusive Prometheus exporter for Apache YuniKorn scheduler.

## ServiceMonitor

`servicemonitor.yaml` scrapes 3 JSON exporter modules through `/probe`:

- `yunikorn_active_apps`
- `yunikorn_partitions`
- `yunikorn_completed_apps`

Before applying it, replace:

- `REPLACE_ME_NAMESPACE` with the namespace that contains the exporter `Service`
- `REPLACE_ME_EXPORTER_SERVICE` with the label value used by the exporter `Service`
- `port: http` if your exporter `Service` uses a different port name
- the YuniKorn service DNS name if it is not `yunikorn-service.yunikorn.svc.cluster.local`

Example validation:

```bash
kubectl apply --dry-run=client -f servicemonitor.yaml
```

## Grafana

`grafana-dashboard.json` is an importable Grafana dashboard for:

- `yunikorn_active_apps`
- `yunikorn_partitions`
- `yunikorn_completed_apps`

Import the dashboard and select your Prometheus datasource when prompted. The default partition variable is `default`.
