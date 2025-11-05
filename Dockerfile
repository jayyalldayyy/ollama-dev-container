# Ollama + Open WebUI Dev Container
# Base: Ubuntu 22.04
# Purpose: GPU-accelerated coding environment with persistent storage
# Author: Jatori Ross (Luxe Property Rescue)

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    jq \
    htop \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    openssh-server \
    sudo \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Install Docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh && \
    rm get-docker.sh

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Install Node.js 20 LTS + npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Create directory structure
RUN mkdir -p /mnt/data/ollama/models \
             /mnt/data/open-webui \
             /mnt/data/workspace \
             /app/scripts

# Configure Ollama to use persistent storage
ENV OLLAMA_MODELS=/mnt/data/ollama/models

# Configure SSH - key-only authentication
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'Port 22' >> /etc/ssh/sshd_config

# Create docker-compose.yml for Open WebUI
RUN cat > /app/docker-compose.yml << 'EOF'
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_AUTH=false
    volumes:
      - /mnt/data/open-webui:/app/backend/data
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF

# Create entrypoint script
RUN cat > /app/scripts/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Ollama Dev Container..."

# Start Docker daemon
echo "Starting Docker daemon..."
dockerd > /var/log/dockerd.log 2>&1 &
sleep 8

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
cd /app
docker-compose up -d

# Wait for Open WebUI to be ready
echo "Waiting for Open WebUI to initialize..."
sleep 10

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
EOF

RUN chmod +x /app/scripts/entrypoint.sh

# Set working directory
WORKDIR /mnt/data/workspace

# Expose SSH only
EXPOSE 22

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -x ollama && pgrep -x dockerd && pgrep -x sshd || exit 1

# Start everything
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
