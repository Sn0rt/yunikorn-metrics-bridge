#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
YUNIKORN_NAMESPACE="${YUNIKORN_NAMESPACE:-yunikorn}"

PROM_STACK_RELEASE="${PROM_STACK_RELEASE:-kube-prometheus-stack}"
PROM_STACK_CHART="${PROM_STACK_CHART:-prometheus-community/kube-prometheus-stack}"
PROM_STACK_CHART_VERSION="${PROM_STACK_CHART_VERSION:-82.12.0}"

YUNIKORN_RELEASE="${YUNIKORN_RELEASE:-yunikorn}"
YUNIKORN_CHART="${YUNIKORN_CHART:-yunikorn/yunikorn}"
YUNIKORN_CHART_VERSION="${YUNIKORN_CHART_VERSION:-1.8.0}"

JSON_EXPORTER_RELEASE="${JSON_EXPORTER_RELEASE:-prometheus-json-exporter}"
JSON_EXPORTER_CHART="${JSON_EXPORTER_CHART:-prometheus-community/prometheus-json-exporter}"
JSON_EXPORTER_CHART_VERSION="${JSON_EXPORTER_CHART_VERSION:-0.19.2}"

DASHBOARD_CONFIGMAP="${DASHBOARD_CONFIGMAP:-yunikorn-metrics-bridge-dashboard}"
PORT_FORWARD_DIR="${PORT_FORWARD_DIR:-/tmp/yunikorn-metrics-bridge}"
TEST_NAMESPACES=(analytics batch pending)
RUN_SUFFIX="${RUN_SUFFIX:-$(date +%s)}"
PROM_STACK_VALUES=""

ACTIVE_APP_ID="app-demo-active-${RUN_SUFFIX}"
ANALYTICS_APP_ID="app-demo-analytics-${RUN_SUFFIX}"
ANALYTICS_COMPLETED_APP_ID="app-demo-analytics-completed-${RUN_SUFFIX}"
BATCH_COMPLETED_APP_ID="app-demo-batch-completed-${RUN_SUFFIX}"
PENDING_APP_ID="app-demo-pending-${RUN_SUFFIX}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

helm_upgrade_install() {
  local release="$1"
  local chart="$2"
  local namespace="$3"
  local version="$4"
  shift 4

  helm upgrade --install "$release" "$chart" \
    --namespace "$namespace" \
    --create-namespace \
    --version "$version" \
    "$@"
}

render_manifest() {
  local source_file="$1"
  local target_file="$2"

  sed \
    -e "s/app-demo-active-001/${ACTIVE_APP_ID}/g" \
    -e "s/app-demo-analytics-001/${ANALYTICS_APP_ID}/g" \
    -e "s/app-demo-analytics-completed-001/${ANALYTICS_COMPLETED_APP_ID}/g" \
    -e "s/app-demo-completed-001/${BATCH_COMPLETED_APP_ID}/g" \
    -e "s/app-demo-pending-001/${PENDING_APP_ID}/g" \
    "$source_file" >"$target_file"
}

start_port_forward() {
  local name="$1"
  local namespace="$2"
  local resource="$3"
  local local_port="$4"
  local remote_port="$5"
  local pid_file="$PORT_FORWARD_DIR/${name}.pid"
  local log_file="$PORT_FORWARD_DIR/${name}.log"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    log "Port-forward $name already running on localhost:$local_port"
    return 0
  fi

  if command -v lsof >/dev/null 2>&1 && lsof -iTCP:"$local_port" -sTCP:LISTEN >/dev/null 2>&1; then
    log "Local port $local_port already in use, skipping $name port-forward"
    return 0
  fi

  nohup kubectl -n "$namespace" port-forward "$resource" "${local_port}:${remote_port}" >"$log_file" 2>&1 &
  local pid=$!
  echo "$pid" >"$pid_file"
  sleep 2

  if kill -0 "$pid" 2>/dev/null; then
    log "Started $name port-forward on http://localhost:$local_port"
    return 0
  fi

  echo "failed to start port-forward for $name, see $log_file" >&2
  return 1
}

require_cmd helm
require_cmd kubectl
require_cmd mktemp

mkdir -p "$PORT_FORWARD_DIR"
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$PROM_STACK_VALUES" "$RENDER_DIR"' EXIT

log "Adding required Helm repositories"
helm repo add yunikorn https://apache.github.io/yunikorn-release >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

log "Creating namespaces"
kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace "$YUNIKORN_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
for ns in "${TEST_NAMESPACES[@]}"; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

PROM_STACK_VALUES="$(mktemp)"
cat >"$PROM_STACK_VALUES" <<EOF
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      searchNamespace: ALL

prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelector: {}
EOF

log "Installing kube-prometheus-stack"
helm_upgrade_install \
  "$PROM_STACK_RELEASE" \
  "$PROM_STACK_CHART" \
  "$MONITORING_NAMESPACE" \
  "$PROM_STACK_CHART_VERSION" \
  -f "$PROM_STACK_VALUES"

log "Installing YuniKorn"
helm_upgrade_install \
  "$YUNIKORN_RELEASE" \
  "$YUNIKORN_CHART" \
  "$YUNIKORN_NAMESPACE" \
  "$YUNIKORN_CHART_VERSION" \
  -f "$ROOT_DIR/yunikorn-values.yaml"

log "Installing prometheus-json-exporter"
helm_upgrade_install \
  "$JSON_EXPORTER_RELEASE" \
  "$JSON_EXPORTER_CHART" \
  "$MONITORING_NAMESPACE" \
  "$JSON_EXPORTER_CHART_VERSION" \
  -f "$ROOT_DIR/monitoring/json-exporter-values.yaml"

log "Applying ServiceMonitor"
kubectl apply -f "$ROOT_DIR/monitoring/json-exporter-servicemonitor.yaml"
kubectl apply -f "$ROOT_DIR/monitoring/yunikorn-native-metrics-servicemonitor.yaml"

log "Applying Grafana dashboard ConfigMap"
kubectl create configmap "$DASHBOARD_CONFIGMAP" \
  --namespace "$MONITORING_NAMESPACE" \
  --from-file=yunikorn-scheduling-analytics.json="$ROOT_DIR/monitoring/grafana-dashboard.json" \
  --from-file=yunikorn-scheduler-health.json="$ROOT_DIR/monitoring/grafana-scheduler-health-dashboard.json" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap "$DASHBOARD_CONFIGMAP" \
  --namespace "$MONITORING_NAMESPACE" \
  grafana_dashboard=1 \
  --overwrite >/dev/null

log "Waiting for core workloads"
kubectl -n "$MONITORING_NAMESPACE" rollout status deploy/"$PROM_STACK_RELEASE"-operator --timeout=10m
kubectl -n "$MONITORING_NAMESPACE" rollout status deploy/"$PROM_STACK_RELEASE"-grafana --timeout=10m
kubectl -n "$MONITORING_NAMESPACE" rollout status deploy/"$JSON_EXPORTER_RELEASE" --timeout=10m
kubectl -n "$YUNIKORN_NAMESPACE" rollout status deploy/"$YUNIKORN_RELEASE"-scheduler --timeout=10m
kubectl -n "$YUNIKORN_NAMESPACE" rollout status deploy/"$YUNIKORN_RELEASE"-admission-controller --timeout=10m

log "Deploying demo workloads"
render_manifest "$ROOT_DIR/examples/active-pod.yaml" "$RENDER_DIR/active-pod.yaml"
render_manifest "$ROOT_DIR/examples/analytics-deployment.yaml" "$RENDER_DIR/analytics-deployment.yaml"
render_manifest "$ROOT_DIR/examples/completed-job.yaml" "$RENDER_DIR/completed-job.yaml"
render_manifest "$ROOT_DIR/examples/analytics-completed-job.yaml" "$RENDER_DIR/analytics-completed-job.yaml"
render_manifest "$ROOT_DIR/examples/pending-pod.yaml" "$RENDER_DIR/pending-pod.yaml"
kubectl delete -f "$ROOT_DIR/examples/active-pod.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "$ROOT_DIR/examples/analytics-deployment.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "$ROOT_DIR/examples/completed-job.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "$ROOT_DIR/examples/analytics-completed-job.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete -f "$ROOT_DIR/examples/pending-pod.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
kubectl apply -f "$RENDER_DIR/active-pod.yaml"
kubectl apply -f "$RENDER_DIR/analytics-deployment.yaml"
kubectl apply -f "$RENDER_DIR/completed-job.yaml"
kubectl apply -f "$RENDER_DIR/analytics-completed-job.yaml"
kubectl apply -f "$RENDER_DIR/pending-pod.yaml"
kubectl wait --for=condition=Ready pod/yk-demo-active -n default --timeout=5m
kubectl -n analytics rollout status deployment/yk-demo-analytics --timeout=5m
kubectl wait --for=condition=complete job/yk-demo-completed -n batch --timeout=5m
kubectl wait --for=condition=complete job/yk-demo-analytics-completed -n analytics --timeout=5m
sleep 5

log "Starting local port-forwards"
start_port_forward grafana "$MONITORING_NAMESPACE" "svc/$PROM_STACK_RELEASE-grafana" 3000 80
start_port_forward prometheus "$MONITORING_NAMESPACE" "svc/prometheus-operated" 9090 9090

log "Deployment complete"
cat <<EOF

Resources deployed:
- kube-prometheus-stack in namespace: $MONITORING_NAMESPACE
- YuniKorn in namespace: $YUNIKORN_NAMESPACE
- prometheus-json-exporter in namespace: $MONITORING_NAMESPACE
- ServiceMonitor: yunikorn-metrics-bridge
- Grafana dashboard ConfigMap: $DASHBOARD_CONFIGMAP
- Demo workloads:
  - Queue root.default: Pod yk-demo-active (${ACTIVE_APP_ID})
  - Queue root.analytics: Deployment yk-demo-analytics (${ANALYTICS_APP_ID})
  - Queue root.analytics: Job yk-demo-analytics-completed (${ANALYTICS_COMPLETED_APP_ID})
  - Queue root.batch: Parallel Job yk-demo-completed (${BATCH_COMPLETED_APP_ID})
  - Queue root.pending: Pod yk-demo-pending (${PENDING_APP_ID}, unschedulable)

Local access:

  Grafana:    http://localhost:3000
  Prometheus: http://localhost:9090

Port-forward logs:

  $PORT_FORWARD_DIR/grafana.log
  $PORT_FORWARD_DIR/prometheus.log

EOF
