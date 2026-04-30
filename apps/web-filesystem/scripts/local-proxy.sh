#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="web-filesystem-local-proxy"
DOMAIN="web-filesystem.local"

echo "=== web-filesystem Local Access Proxy ==="
echo ""

action="${1:-start}"

get_k8s_dns() {
    kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true
}

start_proxy() {
    local k8s_dns
    k8s_dns=$(get_k8s_dns)

    if [[ -z "${k8s_dns}" ]]; then
        echo "Error: Could not detect Kubernetes DNS server"
        echo "Please ensure the cluster is running and kubectl is configured"
        exit 1
    fi

    echo "Kubernetes DNS: ${k8s_dns}"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Removing existing proxy container..."
        docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1
    fi

    echo "Starting nginx proxy container on port 80..."
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        -p 80:80 \
        --dns="${k8s_dns}" \
        --add-host="host.docker.internal:host-gateway" \
        nginx:alpine \
        sh -c '
            echo "server {
                listen 80;
                server_name web-filesystem.local;
                location / {
                    proxy_pass http://web-filesystem.web-filesystem.svc.cluster.local;
                    proxy_set_header Host \$host;
                    proxy_set_header X-Real-IP \$remote_addr;
                    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto \$scheme;
                }
            }" > /etc/nginx/conf.d/default.conf
            nginx -g "daemon off;"
        '

    echo ""
    echo "Proxy container started: ${CONTAINER_NAME}"
    echo ""
    echo "You can now access the application at:"
    echo "  http://${DOMAIN}"
    echo ""
    echo "To verify:"
    echo "  curl http://${DOMAIN}/api/files?path="
    echo ""
    echo "To stop the proxy:"
    echo "  $0 stop"
}

stop_proxy() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Stopping proxy container..."
        docker rm -f "${CONTAINER_NAME}" > /dev/null 2>&1
        echo "Proxy stopped"
    else
        echo "Proxy container is not running"
    fi
}

status_proxy() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Proxy is running"
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "Proxy is not running"
    fi
}

case "${action}" in
    start|up)
        start_proxy
        ;;
    stop|down)
        stop_proxy
        ;;
    status)
        status_proxy
        ;;
    restart)
        stop_proxy
        start_proxy
        ;;
    *)
        echo "Usage: $0 [start|stop|status|restart]"
        echo ""
        echo "Commands:"
        echo "  start   - Start the local proxy container"
        echo "  stop    - Stop the local proxy container"
        echo "  status  - Check proxy status"
        echo "  restart - Restart the proxy"
        exit 1
        ;;
esac
