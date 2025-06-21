#!/bin/bash

# Wrapper Script
# Andre Rocha

# License
This project is licensed under the [GNU General Public License v3 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
See the `LICENSE` file for full details.

ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
IMAGE="quay.io/andrerocha_redhat/ai-health-check-tool:1.0.0-${ARCH}"

check_selinux_status() {
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce 2>/dev/null)
        case "$selinux_status" in
            "Enforcing")
                echo "SELinux detected: ACTIVE (Enforcing)"
                echo "INFO: SELinux labels disabled for this container (--security-opt label=disable)"
                echo "INFO: Volumes mounted with appropriate write permissions"
                echo ""
                ;;
            "Permissive")
                echo "SELinux detected: PERMISSIVE (Permissive)"
                echo "INFO: SELinux labels disabled to ensure functionality"
                echo ""
                ;;
            "Disabled")
                echo "SELinux detected: DISABLED"
                echo ""
                ;;
            *)
                echo "SELinux detected but unknown status: $selinux_status"
                echo ""
                ;;
        esac
    else
        echo "SELinux not detected (non-RHEL system)"
        echo ""
    fi
}

if [ "$1" = "debug-selinux" ]; then
    echo "=== DEBUG: Detailed SELinux Status ==="
    echo "getenforce command: $(command -v getenforce || echo 'Not found')"
    if command -v getenforce >/dev/null 2>&1; then
        echo "Status: $(getenforce)"
        echo "Version: $(sestatus 2>/dev/null | grep 'SELinux status' || echo 'sestatus not available')"
        echo "Policy: $(sestatus 2>/dev/null | grep 'Current mode' || echo 'Policy not available')"
    else
        echo "SELinux is not installed on this system"
    fi
    echo "System: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME || uname -s)"
    echo "========================================"
    exit 0
fi

if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ]; then
    echo "AI Health Check Tool - Wrapper Script"
    echo ""
    echo "USAGE: $0 <command> [arguments]"
    echo ""
    echo "DEBUG COMMANDS:"
    echo "    $0 debug-selinux       # Detailed SELinux status"
    echo ""
    echo "EXAMPLES:"
    echo "    $0 oc login -u admin -p pass https://api.cluster.com:6443"
    echo "    $0 scripts/data_collector.sh --help"
    echo ""
    echo "COMPATIBILITY: Works with or without SELinux"
    exit 0
fi

if [ "$1" != "debug-selinux" ] && [ "$1" != "help" ] && [ "$1" != "--help" ]; then
    check_selinux_status
fi

mkdir -p results analysis final translations logs reports oc-config

exec podman run --rm \
    --security-opt label=disable \
    -v $(pwd):/app/workspace \
    -v $(pwd)/reports:/app/reports \
    -v $(pwd)/results:/app/results \
    -v $(pwd)/analysis:/app/analysis \
    -v $(pwd)/final:/app/final \
    -v $(pwd)/translations:/app/translations \
    -v $(pwd)/logs:/app/logs \
    -v $(pwd)/oc-config:/root/.kube \
    $([ -f .env ] && echo "--env-file .env") \
    $([ -f ai_config.json ] && echo "-v $(pwd)/ai_config.json:/app/ai_config.json") \
    -w /app \
    ${IMAGE} \
    "$@"
