#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAMESPACE="observability"

echo "=== Installing Observability Stack (VictoriaMetrics + VictoriaLogs + Grafana) ==="
echo ""

helm repo add vm https://victoriametrics.github.io/helm-charts/ 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "Installing VictoriaMetrics Single..."
helm upgrade --install victoria-metrics vm/victoria-metrics-single \
  --namespace "${NAMESPACE}" \
  --values "${SCRIPT_DIR}/victoria-metrics-values.yaml" \
  --wait --timeout 180s

echo "Installing VictoriaLogs Single..."
helm upgrade --install victoria-logs vm/victoria-logs-single \
  --namespace "${NAMESPACE}" \
  --values "${SCRIPT_DIR}/victoria-logs-values.yaml" \
  --wait --timeout 180s

echo "Installing VictoriaLogs Collector..."
helm upgrade --install victoria-logs-collector vm/victoria-logs-collector \
  --namespace "${NAMESPACE}" \
  --values "${SCRIPT_DIR}/victoria-logs-collector-values.yaml" \
  --wait --timeout 180s

echo "Installing kube-state-metrics..."
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  --namespace "${NAMESPACE}" \
  --version 7.3.0 \
  --values "${SCRIPT_DIR}/kube-state-metrics-values.yaml" \
  --wait --timeout 180s

echo "Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace "${NAMESPACE}" \
  --values "${SCRIPT_DIR}/grafana-values.yaml" \
  --wait --timeout 180s

echo ""
echo "=== Observability Stack Installed ==="
echo ""
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "Access Grafana: http://grafana.local"
echo "(Add '192.168.64.2 grafana.local' to /etc/hosts if not already present)"
