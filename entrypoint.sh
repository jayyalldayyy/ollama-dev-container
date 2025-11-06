#!/bin/bash
set -e

echo "🚀 Starting Ollama Dev Container..."

# Start Ollama service
echo "Starting Ollama service..."
ollama serve > /var/log/ollama.log 2>&1 &
sleep 8

# Pull models if not present
MODELS=("deepseek-coder-v2:latest" "mistral:7b" "llama3.3:latest")

for model in "${MODELS[@]}"; do
    model_name=$(echo $model | cut -d: -f1)
    if [ ! -d "/mnt/data/ollama/models/manifests/registry.ollama.ai/library/${model_name}" ]; then
        echo "📦 Pulling ${model}..."
        ollama pull ${model}
    else
        echo "✅ ${model} already downloaded"
    fi
done

# Start Open WebUI
echo "Starting Open WebUI..."
open-webui serve --host 0.0.0.0 --port 8080 > /var/log/open-webui.log 2>&1 &
sleep 5

echo "✅ All services running"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Ollama Dev Container Ready"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Access via SSH tunnel:"
echo "   ssh -L 8080:localhost:8080 -L 11434:localhost:11434 root@YOUR_POD_IP"
echo ""
echo "🌐 Open WebUI: http://localhost:8080"
echo "🤖 Ollama API: http://localhost:11434"
echo ""
echo "📂 Workspace: /mnt/data/workspace"
echo "💾 Persistent data: /mnt/data/"
echo ""
echo "Available models:"
ollama list
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start SSH server (foreground)
echo "Starting SSH server..."
/usr/sbin/sshd -D
