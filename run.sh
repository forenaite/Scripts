#!/bin/bash

# Wrapper Script
# Andre Rocha

# License
# This project is licensed under the [GNU General Public License v3 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html).
# See the `LICENSE` file for full details.

ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
IMAGE="quay.io/andrerocha_redhat/ai-health-check-tool:1.0.0-${ARCH}"

# Function to detect and report SELinux status
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

check_pdf_generator_usage() {
    # Verifica se o comando envolve geração de PDF
    local command_string="$*"

    # Verifica especificamente se é generate_pdf.py (deve rodar no host)
    if echo "$command_string" | grep -q "generate_pdf\.py"; then
        echo "DETECTADO: Tentativa de usar gerador de PDF (Python)"
        echo ""
        echo " RECOMENDAÇÃO: Geradores de PDF devem rodar NO HOST"
        echo "   Problema: Container → Podman → Pandoc (containers aninhados)"
        echo "   Solução: Extrair script e executar localmente"
        echo ""
        echo "INSTRUÇÕES PARA EXTRAIR O GERADOR DE PDF:"
        echo ""

        # Verifica se Podman está disponível
        if command -v podman >/dev/null 2>&1; then
            container_runtime="podman"
        elif command -v docker >/dev/null 2>&1; then
            container_runtime="docker"
        else
            container_runtime="podman"
        fi

        echo "# 1. EXTRAÇÃO AUTOMÁTICA (recomendado):"
        echo "#    Execute este comando no HOST:"
        echo ""
        echo "$container_runtime run --rm \\"
        echo "    -v \$(pwd):/host-output \\"
        echo "    ${IMAGE} \\"
        echo "    cp /app/scripts/generate_pdf.py /host-output/"
        echo ""
        echo "# 2. EXTRAÇÃO MANUAL:"
        echo "#    Descubra o container e copie:"
        echo "$container_runtime ps"
        echo "$container_runtime cp CONTAINER_ID:/app/scripts/generate_pdf.py ./"
        echo ""
        echo "# 3. DEPENDÊNCIAS NO HOST:"
        echo "pip install PyYAML"
        echo "# + $container_runtime instalado"
        echo ""
        echo "# 4. USO NO HOST:"
        echo "python generate_pdf.py -a \"Seu Nome\" -c \"Sua Empresa\" relatorio.md"
        echo ""
        echo "VANTAGENS DE RODAR NO HOST:"
        echo "   Sem problemas de containers aninhados"
        echo "   Melhor performance"
        echo "   Acesso direto aos arquivos"
        echo "   Menos overhead"
        echo ""

        # Oferece extração automática
        echo "EXTRAÇÃO AUTOMÁTICA DISPONÍVEL:"
        echo ""
        read -p "Deseja extrair o gerador de PDF automaticamente? [y/N]: " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Extraindo gerador de PDF..."

            # Remove arquivo existente se houver
            rm -f generate_pdf.py 2>/dev/null

            # Método 1: Tenta com mapeamento de usuário
            echo "Tentativa 1: Extração com mapeamento de usuário..."
            $container_runtime run --rm \
                --user "$(id -u):$(id -g)" \
                -v "$(pwd):/host-output" \
                "${IMAGE}" \
                sh -c "cp /app/scripts/generate_pdf.py /host-output/ 2>/dev/null" >/dev/null 2>&1

            # Verifica se método 1 funcionou
            extracted_file=""
            if [ -f "generate_pdf.py" ] && [ -s "generate_pdf.py" ] && head -1 "generate_pdf.py" | grep -q "#!/usr/bin/env python3\|#!/usr/bin/python3\|# Script\|import"; then
                extracted_file="generate_pdf.py"
                echo "Método 1 bem-sucedido!"
            else
                echo "Falha ao extrair. Verifique o SELinux."
            fi

            # Método 2: Redirecionamento se método 1 falhou
            if [ -z "$extracted_file" ]; then
                echo "Tentativa 2: Extração via redirecionamento..."

                # Verifica se o arquivo existe no container
                if $container_runtime run --rm "${IMAGE}" test -f /app/scripts/generate_pdf.py >/dev/null 2>&1; then
                    $container_runtime run --rm "${IMAGE}" \
                        cat /app/scripts/generate_pdf.py > generate_pdf.py 2>/dev/null

                    # Verifica se redirecionamento funcionou
                    if [ -f "generate_pdf.py" ] && [ -s "generate_pdf.py" ] && head -1 generate_pdf.py | grep -q "#!/usr/bin/env python3\|#!/usr/bin/python3\|# Script\|import"; then
                        extracted_file="generate_pdf.py"
                        echo "Método 2 bem-sucedido!"
                    fi
                else
                    echo "Arquivo /app/scripts/generate_pdf.py não encontrado no container"
                fi
            fi

            # Método 3: SELinux workaround se métodos anteriores falharam
            if [ -z "$extracted_file" ]; then
                echo "Tentativa 3: Workaround para SELinux..."

                # Verifica se SELinux pode estar causando problemas
                if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
                    echo " SELinux detectado em modo Enforcing - pode estar bloqueando"
                fi

                # Tenta criar em diretório temporário e mover
                temp_dir=$(mktemp -d)
                $container_runtime run --rm \
                    -v "$temp_dir:/temp-output" \
                    "${IMAGE}" \
                    sh -c "cp /app/scripts/generate_pdf.py /temp-output/ 2>/dev/null" >/dev/null 2>&1

                # Move para diretório atual
                if [ -f "$temp_dir/generate_pdf.py" ] && [ -s "$temp_dir/generate_pdf.py" ]; then
                    cp "$temp_dir/generate_pdf.py" "./generate_pdf.py" 2>/dev/null
                    extracted_file="generate_pdf.py"
                    echo "Método 3 bem-sucedido!"
                fi

                rm -rf "$temp_dir"
            fi

            # Verificação final robusta
            if [ -n "$extracted_file" ] && [ -f "$extracted_file" ] && [ -s "$extracted_file" ]; then
                # Verifica se é realmente um script Python válido
                if head -5 "$extracted_file" | grep -q "import\|def\|class\|python"; then
                    file_size=$(stat -f%z "$extracted_file" 2>/dev/null || stat -c%s "$extracted_file" 2>/dev/null || echo "0")

                    if [ "$file_size" -gt 1000 ]; then  # Script deve ter pelo menos 1KB
                        echo ""
                        echo "Gerador de PDF extraído com sucesso!"
                        echo "Arquivo: $extracted_file ($file_size bytes)"
                        echo ""

                        # Verifica se tem dependências problemáticas
                        if grep -q "weasyprint\|WeasyPrint" "$extracted_file" 2>/dev/null; then
                            echo " AVISO: Arquivo extraído usa WeasyPrint (pode precisar libs sistema)"
                            echo "  Alternativa: sudo apt install libpango-1.0-0 libharfbuzz0b"
                            echo "  OU: Use método de redirecionamento para obter versão container"
                        elif grep -q "container_cmd\|podman\|docker" "$extracted_file" 2>/dev/null; then
                            echo "Versão correta detectada (usa containers)"
                        fi

                        echo ""
                        echo "PRÓXIMOS PASSOS:"
                        echo "1. Instale as dependências:"
                        echo "   pip install PyYAML"
                        echo ""
                        echo "2. Teste o gerador:"
                        echo "   python3 $extracted_file --help"
                        echo ""
                        echo "3. Use o gerador:"
                        echo "   python3 $extracted_file -a \"Seu Nome\" -c \"Empresa\" arquivo.md"
                        echo ""
                        echo "O gerador agora roda diretamente no HOST!"

                        exit 0
                    else
                        echo "Arquivo extraído está vazio ou muito pequeno ($file_size bytes)"
                    fi
                else
                    echo "Arquivo extraído não parece ser um script Python válido"
                fi
            fi

            # Se chegou até aqui, a extração falhou
            echo ""
            echo "TODAS as tentativas de extração automática falharam"
            echo ""
            echo "DIAGNÓSTICO POSSÍVEL:"
            if command -v getenforce >/dev/null 2>&1; then
                selinux_status=$(getenforce 2>/dev/null)
                echo "   SELinux: $selinux_status"
                if [ "$selinux_status" = "Enforcing" ]; then
                    echo "    SELinux pode estar bloqueando escrita de arquivos"
                fi
            fi

            echo "   Permissões diretório: $(ls -ld . | awk '{print $1, $3, $4}')"
            echo ""
            echo "SOLUÇÕES MANUAIS:"
            echo ""
            echo "# Método A: Redirecionamento puro (evita SELinux)"
            echo "$container_runtime run --rm ${IMAGE} cat /app/scripts/generate_pdf.py > generate_pdf.py"
            echo ""
            echo "# Método B: Com privilégios sudo"
            echo "sudo $container_runtime run --rm -v \$(pwd):/host-output ${IMAGE} \\"
            echo "    cp /app/scripts/generate_pdf.py /host-output/"
            echo "sudo chown \$(whoami):\$(whoami) generate_pdf.py"
            echo ""
            echo "# Método C: Desabilitar SELinux temporariamente"
            echo "sudo setenforce 0  # Temporário"
            echo "# Execute extração novamente"
            echo "sudo setenforce 1  # Reabilita"
            echo ""

            return 1
        else
            echo " Extração cancelada pelo usuário"
            echo " Use os comandos manuais mostrados acima quando precisar"
            echo ""
        fi

        # Pergunta se quer continuar mesmo assim
        echo " OPÇÕES:"
        echo "   [c] Continuar execução no container (pode falhar)"
        echo "   [x] Cancelar operação"
        echo ""
        read -p "Sua escolha [c/x]: " -n 1 -r
        echo ""

        case $REPLY in
            [Cc])
                echo "Continuando no container (containers aninhados podem falhar)..."
                echo ""
                ;;
            *)
                echo "Operação cancelada pelo usuário"
                echo "Execute o gerador de PDF no HOST para melhor compatibilidade"
                exit 0
                ;;
        esac
    fi
}

# Function to generate ai_config.json from .env or create with placeholders
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

# Function to validate configuration
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

# Simple help
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
    echo "PDF GENERATION:"
    echo "    generate_pdf.py   # Recomenda extração para HOST (containers aninhados)"
    echo "    generate_pdf.sh   # Executa no HOST extraindo do container"
    echo ""
    echo "EXAMPLES:"
    echo "    $0 oc login -u admin -p pass https://api.cluster.com:6443"
    echo "    $0 scripts/data_collector.sh --help"
    echo "    $0 scripts/ai_analyser_dynamic.py"
    echo "    $0 scripts/generate_pdf.sh -a \"Andre\" -c \"Company\" file.md"
    echo ""
    exit 0
fi

# Show status and generate config only for non-help commands
if [ "$1" != "help" ] && [ "$1" != "--help" ]; then
    # Check for PDF generator usage before proceeding
    check_pdf_generator_usage "$@"
    check_selinux_status
    check_config_status
    generate_ai_config
fi

mkdir -p results analysis final translations logs reports oc-config

# Build volume mounts for config files
CONFIG_MOUNTS=""
if [ -f .env ]; then
    CONFIG_MOUNTS="$CONFIG_MOUNTS --env-file .env"
fi
if [ -f ai_config.json ]; then
    CONFIG_MOUNTS="$CONFIG_MOUNTS -v $(pwd)/ai_config.json:/app/ai_config.json"
fi

# Special handling for PDF generation - execute on host instead of container
if [[ "$1" == "scripts/generate_pdf.sh" ]]; then
    echo "INFO: Detectado generate_pdf.sh - executando no host para evitar container-in-container..."
    echo ""

    # Check if podman/docker is available on host (script will use containers)
    if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
        echo "ERRO: Nem podman nem docker encontrados no PATH do host"
        exit 1
    fi

    # Ensure required files are available on host
    # Check and copy metadata.yaml if it doesn't exist
    if [[ ! -f "metadata.yaml" ]]; then
        echo "INFO: metadata.yaml não encontrado localmente, copiando do container..."

        # Use volume mount to copy file - more reliable than podman cp
        podman run --rm \
            --security-opt label=disable \
            -v "$(pwd)":/tmp/host \
            "${IMAGE}" \
            cp /app/metadata.yaml /tmp/host/metadata.yaml

        if [[ -f "metadata.yaml" ]]; then
            echo "INFO: metadata.yaml copiado com sucesso!"
        else
            echo "ERRO: Falha ao copiar metadata.yaml"
            exit 1
        fi
    fi

    # Extract and execute the script from container on the host
    # The script will run on host but still use containers for pandoc
    # This avoids container-in-container issues
    echo "INFO: Extraindo e executando script do container no host..."
    podman run --rm \
        --security-opt label=disable \
        -v "$(pwd)":/app/workspace \
        $CONFIG_MOUNTS \
        "${IMAGE}" cat /app/scripts/generate_pdf.sh | \
        bash -s -- "${@:2}"

    exit $?
fi

# Normal container execution for all other commands
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
