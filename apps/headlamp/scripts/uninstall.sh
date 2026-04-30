#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

values_file="${APP_DIR}/values.yaml"
release_name=$(yq e '.releaseName' "${values_file}" 2>/dev/null || echo "headlamp")
namespace=$(yq e '.namespace' "${values_file}" 2>/dev/null || echo "headlamp")

echo "=== Uninstalling Headlamp ==="
echo "Release: ${release_name}"
echo "Namespace: ${namespace}"
echo ""

if helm list -n "${namespace}" -q | grep -q "^${release_name}$"; then
    helm uninstall "${release_name}" -n "${namespace}"
    echo ""
    echo "Helm release '${release_name}' uninstalled."
else
    echo "Helm release '${release_name}' not found in namespace '${namespace}'."
fi

read -p "Also delete namespace '${namespace}'? (y/N): " confirm
if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    kubectl delete namespace "${namespace}" --wait=false
    echo "Namespace '${namespace}' deletion initiated."
fi

echo ""
echo "Uninstall complete."
