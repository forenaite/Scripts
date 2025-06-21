#!/bin/bash

# Wrapper

ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
IMAGE="quay.io/andrerocha_redhat/ai-health-check-tool:1.0.0-${ARCH}"

# Help simples
if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ]; then
    echo "AI Health Check Tool - Wrapper Ultra-Simples"
    echo ""
    echo "USAGE: $0 <comando> [argumentos]"
    echo ""
    echo "EXEMPLOS:"
    echo "    $0 scripts/data_collector.sh --help"
    echo "    $0 scripts/ai_analyser.py --help"
    echo "    $0 scripts/ai_translator.py --help"
    echo ""
    echo "SCRIPTS:"
    [ -d scripts ] && ls scripts/*.py scripts/*.sh 2>/dev/null | sed 's|^|    ./run-ultra |; s|$| --help|'
    exit 0
fi

mkdir -p results analysis final translations logs reports

exec podman run --rm \
    -v $(pwd):/app/workspace \
    -v $(pwd)/reports:/app/reports \
    -v $(pwd)/results:/app/results \
    -v $(pwd)/analysis:/app/analysis \
    -v $(pwd)/final:/app/final \
    -v $(pwd)/translations:/app/translations \
    -v $(pwd)/logs:/app/logs \
    $([ -f .env ] && echo "--env-file .env") \
    $([ -f ai_config.json ] && echo "-v $(pwd)/ai_config.json:/app/ai_config.json") \
    -w /app \
    ${IMAGE} \
    "$@"
