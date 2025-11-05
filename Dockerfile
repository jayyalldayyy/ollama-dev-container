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
             /app

# Configure Ollama to use persistent storage
ENV OLLAMA_MODELS=/mnt/data/ollama/models

# Configure SSH - key-only authentication
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'Port 22' >> /etc/ssh/sshd_config

# Copy docker-compose.yml and entrypoint script
COPY docker-compose.yml /app/docker-compose.yml
COPY entrypoint.sh /app/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Set working directory
WORKDIR /mnt/data/workspace

# Expose SSH only
EXPOSE 22

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -x ollama && pgrep -x dockerd && pgrep -x sshd || exit 1

# Start everything
ENTRYPOINT ["/app/entrypoint.sh"]
