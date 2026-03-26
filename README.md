# yunikorn-metrics-bridge

yunikorn-metrics-bridge is a non-intrusive Prometheus exporter for Apache YuniKorn scheduler.

## Setup

`setup.sh` installs:

- `kube-prometheus-stack`
- `YuniKorn`
- `prometheus-json-exporter`
- the `ServiceMonitor` in this repo
- the Grafana dashboard in this repo as a ConfigMap for the Grafana sidecar
- demo workloads across multiple queues that generate active, completed, and pending YuniKorn metrics
- local port-forwards for Grafana and Prometheus

Run:

```bash
chmod +x setup.sh
./setup.sh
```

Optional environment overrides:

- `MONITORING_NAMESPACE`
- `YUNIKORN_NAMESPACE`
- `PROM_STACK_CHART_VERSION`
- `YUNIKORN_CHART_VERSION`
- `JSON_EXPORTER_CHART_VERSION`
- `RUN_SUFFIX`

After setup completes, the default local endpoints are:

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`

The default setup also creates test queues and workloads:

- `root.default`: one long-running pod
- `root.analytics`: one long-running deployment with two replicas
- `root.analytics`: one short job that completes
- `root.batch`: one parallel job that completes
- `root.pending`: one unschedulable pod that stays pending/accepted

`setup.sh` renders unique YuniKorn `applicationID` values on each run so that the `completed` endpoint does not accumulate duplicate label sets from repeated test installs. Set `RUN_SUFFIX` explicitly if you want deterministic IDs.

## Repository Layout

```text
.
├── docs/
│   └── YARN_TO_YUNIKORN_METRIC_MAPPING.md
├── examples/
│   ├── active-pod.yaml
│   ├── analytics-completed-job.yaml
│   ├── analytics-deployment.yaml
│   ├── completed-job.yaml
│   └── pending-pod.yaml
├── monitoring/
│   ├── grafana-dashboard.json
│   ├── grafana-scheduler-health-dashboard.json
│   ├── json-exporter-servicemonitor.yaml
│   ├── json-exporter-values.yaml
│   └── yunikorn-native-metrics-servicemonitor.yaml
├── README.md
├── setup.sh
└── yunikorn-values.yaml
```

Structure by responsibility:

- `examples/`: demo workloads for active, pending, multi-replica, and completed scenarios
- `monitoring/`: Prometheus and Grafana resources, plus the raw dashboard JSON used by `setup.sh`
- `yunikorn-values.yaml`: Helm values for the test queue topology
- `docs/`: migration and design notes

## ServiceMonitor

`monitoring/json-exporter-servicemonitor.yaml` scrapes 4 JSON exporter modules through `/probe`:

- `yunikorn_active_apps`
- `yunikorn_partitions`
- `yunikorn_queues`
- `yunikorn_completed_apps`

Current defaults:

- namespace: `monitoring`
- exporter service selector: `app.kubernetes.io/name=prometheus-json-exporter`
- exporter service port: `http`
- YuniKorn API target base: `http://yunikorn-service.yunikorn.svc.cluster.local:9080`

Example validation:

```bash
kubectl apply --dry-run=client -f monitoring/json-exporter-servicemonitor.yaml
```

`monitoring/yunikorn-native-metrics-servicemonitor.yaml` scrapes YuniKorn native `/ws/v1/metrics` directly for:

- `yunikorn_queue_app`
- `yunikorn_queue_resource`
- `yunikorn_scheduler_*`
- `yunikorn_runtime_go_*`

## Grafana

Each Grafana dashboard JSON is a source of truth and is imported by `setup.sh` via a generated ConfigMap.

`monitoring/grafana-dashboard.json` covers:

- `yunikorn_active_apps`
- `yunikorn_partitions`
- `yunikorn_queues`
- `yunikorn_completed_apps`

`monitoring/grafana-scheduler-health-dashboard.json` covers:

- `yunikorn_queue_app`
- `yunikorn_queue_resource`
- `yunikorn_scheduler_*`
- `yunikorn_runtime_go_*`

Import either dashboard and select your Prometheus datasource when prompted. The scheduling analytics dashboard defaults partition to `default`. The scheduler health dashboard defaults queue to `All`.

## Migration Notes

For YARN-to-YuniKorn bean coverage and PromQL mapping, see [YARN_TO_YUNIKORN_METRIC_MAPPING.md](/Users/guohao/workspace/yunikorn-metrics-bridge/docs/YARN_TO_YUNIKORN_METRIC_MAPPING.md).

For the JSON-exporter bridge metric reference, see [JSON_EXPORTER_METRICS.md](/Users/guohao/workspace/yunikorn-metrics-bridge/docs/JSON_EXPORTER_METRICS.md).
