#!/bin/bash

# Wrapper Script
# Andre Rocha

ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
IMAGE="quay.io/andrerocha_redhat/ai-health-check-tool:1.0.0-${ARCH}"

if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ]; then
    echo "AI Health Check Tool - Wrapper Script"
    echo ""
    echo "USAGE: $0 <comando> [argumentos]"
    echo ""
    echo "EXEMPLOS:"
    echo "    $0 oc login -u admin -p pass https://api.cluster.com:6443"
    echo "    $0 scripts/data_collector.sh --help"
    echo ""
    exit 0
fi

mkdir -p results analysis final translations logs reports oc-config

exec podman run --rm \
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
