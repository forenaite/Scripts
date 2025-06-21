#!/bin/bash

# Wrapper Script
# Andre Rocha

# License
# This project is licensed under the [GNU General Public License v3 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
# See the `LICENSE` file for full details.

ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
IMAGE="quay.io/andrerocha_redhat/ai-health-check-tool:1.0.0-${ARCH}"

check_selinux_status() {
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce 2>/dev/null)
        case "$selinux_status" in
            "Enforcing")
                echo "SELinux detected: ACTIVE (Enforcing)"
                echo "INFO: SELinux labels disabled for this container"
                echo ""
                ;;
            "Permissive")
                echo "SELinux detected: PERMISSIVE"
                echo "INFO: SELinux labels disabled to ensure functionality"
                echo ""
                ;;
            "Disabled")
                echo "SELinux detected: DISABLED"
                echo ""
                ;;
        esac
    else
        echo "SELinux not detected (non-RHEL system)"
        echo ""
    fi
}

generate_ai_config() {
    if [ ! -f ai_config.json ]; then
        if [ -f .env ]; then
            echo "INFO: ai_config.json not found, generating from .env variables"

            # Source .env file to get variables
            set -a  # Automatically export all variables
            source .env
            set +a  # Turn off automatic export

            # Generate ai_config.json with values from .env
            cat > ai_config.json << EOF
{
  "ai_providers": [
    {
      "name": "gemini",
      "enabled": true,
      "api_key": "${GEMINI_API_KEY:-your_gemini_api_key_here}",
      "model": "gemini-2.5-pro-preview-03-25",
      "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    },
    {
      "name": "claude",
      "enabled": true,
      "api_key": "${CLAUDE_API_KEY:-your_claude_api_key_here}",
      "model": "claude-sonnet-4-20250514",
      "endpoint": "https://api.anthropic.com/v1/messages"
    },
    {
      "name": "openai",
      "enabled": false,
      "api_key": "${OPENAI_API_KEY:-your_openai_api_key_here}",
      "model": "gpt-4.1",
      "endpoint": "https://api.openai.com/v1/chat/completions"
    }
  ],
  "analysis_settings": {
    "max_retries": ${MAX_RETRIES:-15},
    "timeout": ${API_TIMEOUT:-60},
    "delay_between_analyses": ${DELAY_BETWEEN_ANALYSES:-10}
  }
}
EOF
            echo "INFO: ai_config.json generated successfully from .env"
        else
            echo "WARNING: Neither ai_config.json nor .env found, creating template ai_config.json"

            # Create ai_config.json with placeholders
            cat > ai_config.json << 'EOF'
{
  "ai_providers": [
    {
      "name": "gemini",
      "enabled": true,
      "api_key": "your_gemini_api_key_here",
      "model": "gemini-2.5-pro-preview-03-25",
      "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    },
    {
      "name": "claude",
      "enabled": true,
      "api_key": "your_claude_api_key_here",
      "model": "claude-sonnet-4-20250514",
      "endpoint": "https://api.anthropic.com/v1/messages"
    },
    {
      "name": "openai",
      "enabled": false,
      "api_key": "your_openai_api_key_here",
      "model": "gpt-4.1",
      "endpoint": "https://api.openai.com/v1/chat/completions"
    }
  ],
  "analysis_settings": {
    "max_retries": 15,
    "timeout": 60,
    "delay_between_analyses": 10
  }
}
EOF
            echo "WARNING: Please edit ai_config.json and add your API keys"
            echo "WARNING: Or create a .env file with GEMINI_API_KEY, CLAUDE_API_KEY, OPENAI_API_KEY"
        fi
        echo ""
    fi
}

check_config_status() {
    local has_env=false
    local has_ai_config=false
    local has_valid_keys=false

    if [ -f .env ]; then
        has_env=true
    fi

    if [ -f ai_config.json ]; then
        has_ai_config=true
        # Check if ai_config.json has real API keys (not placeholders)
        if ! grep -q "your_.*_api_key_here" ai_config.json; then
            has_valid_keys=true
        fi
    fi

    if [ "$has_env" = true ] && [ "$has_ai_config" = true ] && [ "$has_valid_keys" = true ]; then
        echo "INFO: Configuration files ready (.env and ai_config.json with API keys)"
    elif [ "$has_ai_config" = true ] && [ "$has_valid_keys" = false ]; then
        echo "WARNING: ai_config.json contains placeholder values - please add your API keys"
    elif [ "$has_env" = false ] && [ "$has_ai_config" = false ]; then
        echo "WARNING: No configuration files found - template will be created"
    fi
    echo ""
}

if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ]; then
    echo "AI Health Check Tool - Ultra-Simple Wrapper"
    echo ""
    echo "USAGE: $0 <command> [arguments]"
    echo ""
    echo "CONFIGURATION FILES:"
    echo "    .env              # Environment variables (API keys, timeouts, etc)"
    echo "    ai_config.json    # AI provider configuration (auto-generated from .env)"
    echo ""
    echo "SETUP:"
    echo "    1. Create .env file with your API keys:"
    echo "       GEMINI_API_KEY=your_key_here"
    echo "       CLAUDE_API_KEY=your_key_here"
    echo "       OPENAI_API_KEY=your_key_here"
    echo "    2. Run any command - ai_config.json will be auto-generated"
    echo ""
    echo "EXAMPLES:"
    echo "    $0 oc login -u admin -p pass https://api.cluster.com:6443"
    echo "    $0 scripts/data_collector.sh --help"
    echo "    $0 scripts/ai_analyser_dynamic.py"
    echo ""
    exit 0
fi

if [ "$1" != "help" ] && [ "$1" != "--help" ]; then
    check_selinux_status
    check_config_status
    generate_ai_config
fi

mkdir -p results analysis final translations logs reports oc-config

CONFIG_MOUNTS=""
if [ -f .env ]; then
    CONFIG_MOUNTS="$CONFIG_MOUNTS --env-file .env"
fi
if [ -f ai_config.json ]; then
    CONFIG_MOUNTS="$CONFIG_MOUNTS -v $(pwd)/ai_config.json:/app/ai_config.json"
fi

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
    $CONFIG_MOUNTS \
    -w /app \
    ${IMAGE} \
    "$@"
