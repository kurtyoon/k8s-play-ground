#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Deploying web-filesystem to Kubernetes ==="
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please ensure your cluster is running and kubectl is configured"
    exit 1
fi

if ! docker image inspect web-filesystem:latest &> /dev/null; then
    echo "Docker image 'web-filesystem:latest' not found. Building..."
    docker build -t web-filesystem:latest "${PROJECT_ROOT}"
fi

OVERLAY="${1:-local}"
KUSTOMIZE_DIR="${PROJECT_ROOT}/k8s/overlays/${OVERLAY}"

if [[ ! -d "${KUSTOMIZE_DIR}" ]]; then
    echo "Error: Overlay '${OVERLAY}' not found at ${KUSTOMIZE_DIR}"
    echo "Available overlays:"
    ls -1 "${PROJECT_ROOT}/k8s/overlays/"
    exit 1
fi

echo "Using overlay: ${OVERLAY}"
echo "Applying manifests..."
kubectl apply -k "${KUSTOMIZE_DIR}"

echo ""
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/web-filesystem -n web-filesystem --timeout=120s

echo ""
echo "=== Deployment Complete ==="
echo ""
kubectl get all -n web-filesystem
echo ""
echo "To set up local DNS access, run:"
echo "  ${SCRIPT_DIR}/setup-local-dns.sh"
