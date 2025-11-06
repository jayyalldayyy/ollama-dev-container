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
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y python3.11 python3.11-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1

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

# Install Open WebUI via pip
RUN pip3 install open-webui

# Create directory structure
RUN mkdir -p /mnt/data/ollama/models \
             /mnt/data/open-webui \
             /mnt/data/workspace \
             /app

# Configure Ollama to use persistent storage
ENV OLLAMA_MODELS=/mnt/data/ollama/models

# Configure Open WebUI to use persistent storage
ENV DATA_DIR=/mnt/data/open-webui
ENV OLLAMA_BASE_URL=http://localhost:11434
ENV WEBUI_AUTH=false

# Configure SSH - key-only authentication
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'Port 22' >> /etc/ssh/sshd_config

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Set working directory
WORKDIR /mnt/data/workspace

# Expose SSH only
EXPOSE 22

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -x ollama && pgrep -x "open-webui" && pgrep -x sshd || exit 1

# Start everything
ENTRYPOINT ["/app/entrypoint.sh"]
