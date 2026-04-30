#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${APP_DIR}/../.." && pwd)"

HELM_REPO_URL="https://kubernetes-sigs.github.io/headlamp/"
HELM_REPO_NAME="headlamp"
CHART_NAME="headlamp/headlamp"

values_file="${APP_DIR}/values.yaml"

release_name=$(yq e '.releaseName' "${values_file}" 2>/dev/null || echo "headlamp")
namespace=$(yq e '.namespace' "${values_file}" 2>/dev/null || echo "headlamp")

echo "=== Installing Headlamp (Operator-style Helm reconciliation) ==="
echo ""

if ! command -v helm &> /dev/null; then
    echo "Error: Helm is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Warning: yq not found. Using default release name 'headlamp' and namespace 'headlamp'"
    release_name="headlamp"
    namespace="headlamp"
fi

echo "Adding Helm repo: ${HELM_REPO_NAME}"
helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" 2>/dev/null || true
helm repo update "${HELM_REPO_NAME}"

echo "Ensuring namespace: ${namespace}"
kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "Reconciling Helm release: ${release_name}"
helm upgrade --install "${release_name}" "${CHART_NAME}" \
    --namespace "${namespace}" \
    --values "${values_file}" \
    --wait \
    --timeout 120s

echo ""
echo "=== Headlamp Reconciled Successfully ==="
echo ""
kubectl get pods -n "${namespace}" -l app.kubernetes.io/name=headlamp
echo ""
echo "To access Headlamp locally:"
echo "  ${SCRIPT_DIR}/port-forward.sh"
echo ""
echo "To create an access token:"
echo "  kubectl create token ${release_name} -n ${namespace}"
