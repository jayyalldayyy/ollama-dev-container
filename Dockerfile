# Ollama + Open WebUI Dev Container
# Base: Ubuntu 22.04
# Purpose: GPU-accelerated coding environment with persistent storage
# Author: Jatori Ross (Luxe Property Rescue)


# ---------- Stage 1: Base Builder ----------
FROM ubuntu:22.04 AS base

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

# Add deadsnakes PPA for Python 3.11
RUN add-apt-repository ppa:deadsnakes/ppa -y

# Update again and install Python 3.11
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-distutils \
    python3.11-dev \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Install pip for Python 3.11
RUN curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.11 get-pip.py && \
    rm get-pip.py

# Create symlinks for pip
RUN ln -sf /usr/local/bin/pip3.11 /usr/local/bin/pip3 && \
    ln -sf /usr/local/bin/pip3.11 /usr/local/bin/pip

# Verify installations
RUN python3 --version && pip3 --version

# Install Node.js 20 LTS + npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Clean up Node and apt caches to reduce image size
RUN npm cache clean --force && rm -rf /root/.cache


# ---------- Stage 2: App Builder ----------
FROM base AS builder

# Install Python deps (Open WebUI) — heavy build step
RUN pip3 install --no-cache-dir open-webui

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# (debug) show Python install locations before copying to runtime
RUN which python3.11 && ls -l /usr/bin/python3.11 /usr/local/bin/python3* || true

# Remove temporary build files and apt cache
RUN rm -rf /root/.cache /tmp/* /var/lib/apt/lists/*


# ---------- Stage 3: Runtime ----------
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# only what’s needed to *run* apps
RUN apt-get update && apt-get install -y \
    python3.11 python3.11-distutils \
    curl wget git ca-certificates openssh-server sudo rsync \
    && rm -rf /var/lib/apt/lists/*

# copy minimal runtime binaries
COPY --from=builder /usr/bin/python3.11 /usr/bin/python3.11
COPY --from=builder /usr/local/bin/pip3 /usr/local/bin/pip3
COPY --from=builder /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=builder /usr/local/bin/ollama /usr/local/bin/ollama
COPY --from=builder /usr/bin/node /usr/bin/node
COPY --from=builder /usr/lib/node_modules /usr/lib/node_modules
COPY --from=builder /usr/bin/npm /usr/bin/npm

# Strip unnecessary Python bytecode to save space
RUN find /usr/local/lib/python3.11 -type f -name "*.pyc" -delete

# Create directory structure
RUN mkdir -p /mnt/data/ollama/models \
             /mnt/data/open-webui \
             /mnt/data/workspace \
             /app

# Configure Ollama + Open WebUI to use persistent storage
ENV OLLAMA_MODELS=/mnt/data/ollama/models
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
