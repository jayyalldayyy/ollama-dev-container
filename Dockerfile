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
    ca-certificates \
    lsb-release \
    software-properties-common \
    build-essential \
    openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv to PATH
ENV PATH="/root/.cargo/bin:$PATH"

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# ---------- Stage 2: App Builder ----------
FROM base AS builder

# Install Python 3.11
RUN apt-get update && apt-get install -y \
    python3 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Node.js 20 LTS + npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Open WebUI using uv (handles Python + dependencies automatically)
RUN uv pip install --system open-webui

# Verify installation
RUN python3 -c "import open_webui; print('✅ Open WebUI installed via uv')"

# Remove temporary build files and apt cache
RUN rm -rf /root/.cache /tmp/* /var/lib/apt/lists/*


# ---------- Stage 3: Runtime ----------
FROM ubuntu:22.04 AS final

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# only what’s needed to *run* apps
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    openssh-server \
    python3 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# copy minimal runtime binaries and dependencies
COPY --from=builder /usr/local/bin/ollama /usr/local/bin/ollama
COPY --from=builder /usr/bin/node /usr/bin/node
COPY --from=builder /usr/lib/node_modules /usr/lib/node_modules
COPY --from=builder /usr/bin/npm /usr/bin/npm

# Copy Open WebUI and ALL Python packages from builder
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin/open-webui /usr/local/bin/open-webui

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
    echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config && \
    echo 'Port 22' >> /etc/ssh/sshd_config && \
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOSS+laAugPxcOvgCYNy8NU9ed2TqN5ZEjckxhL5lIm7 ssh@jatoriross.com' >> /root/.shh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

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
