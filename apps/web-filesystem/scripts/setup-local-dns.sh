#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_FILE="/etc/hosts"
DOMAIN="web-filesystem.local"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

action="${1:-setup}"

setup_dns() {
    echo "=== Setting up local DNS for ${DOMAIN} ==="
    echo ""

    if grep -q "${DOMAIN}" "${HOSTS_FILE}" 2>/dev/null; then
        echo -e "${YELLOW}Warning: ${DOMAIN} already exists in ${HOSTS_FILE}${NC}"
        grep "${DOMAIN}" "${HOSTS_FILE}"
        echo ""
        read -p "Replace existing entry? (y/N): " confirm
        if [[ "${confirm}" =~ ^[Yy]$ ]]; then
            sudo sed -i.bak "/${DOMAIN}/d" "${HOSTS_FILE}"
        else
            echo "Skipping hosts file update"
            return
        fi
    fi

    echo "Adding ${DOMAIN} to ${HOSTS_FILE}..."
    echo "127.0.0.1 ${DOMAIN}" | sudo tee -a "${HOSTS_FILE}" > /dev/null
    echo -e "${GREEN}Successfully added ${DOMAIN} to ${HOSTS_FILE}${NC}"
    echo ""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Flushing macOS DNS cache..."
        sudo dscacheutil -flushcache 2>/dev/null || true
        sudo killall -HUP mDNSResponder 2>/dev/null || true
    fi

    echo "Hosts file entry:"
    grep "${DOMAIN}" "${HOSTS_FILE}"
}

cleanup_dns() {
    echo "=== Cleaning up local DNS for ${DOMAIN} ==="
    echo ""

    if grep -q "${DOMAIN}" "${HOSTS_FILE}" 2>/dev/null; then
        sudo sed -i.bak "/${DOMAIN}/d" "${HOSTS_FILE}"
        echo -e "${GREEN}Removed ${DOMAIN} from ${HOSTS_FILE}${NC}"
    else
        echo "No entry found for ${DOMAIN} in ${HOSTS_FILE}"
    fi
}

case "${action}" in
    setup|install)
        setup_dns
        ;;
    cleanup|remove|uninstall)
        cleanup_dns
        ;;
    *)
        echo "Usage: $0 [setup|cleanup]"
        echo ""
        echo "Commands:"
        echo "  setup   - Add ${DOMAIN} to /etc/hosts"
        echo "  cleanup - Remove ${DOMAIN} from /etc/hosts"
        exit 1
        ;;
esac
