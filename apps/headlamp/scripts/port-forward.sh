#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

values_file="${APP_DIR}/values.yaml"
namespace=$(yq e '.namespace' "${values_file}" 2>/dev/null || echo "headlamp")
service_name=$(yq e '.releaseName' "${values_file}" 2>/dev/null || echo "headlamp")
local_port="${1:-8080}"

echo "=== Headlamp Port Forward ==="
echo "Namespace: ${namespace}"
echo "Local port: ${local_port}"
echo ""

if ! kubectl get svc "${service_name}" -n "${namespace}" &> /dev/null; then
    echo "Error: Service '${service_name}' not found in namespace '${namespace}'"
    echo "Please run install.sh first:"
    echo "  ${SCRIPT_DIR}/install.sh"
    exit 1
fi

echo "Starting port-forward (Ctrl+C to stop)..."
echo "Open http://127.0.0.1:${local_port} in your browser"
echo ""

kubectl port-forward -n "${namespace}" "svc/${service_name}" "${local_port}:80"
