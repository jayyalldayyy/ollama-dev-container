# Ollama Dev Container

GPU-accelerated development environment with Ollama + Open WebUI.

## What's Inside

- **Ollama** with deepseek-coder-v2, mistral:7b, llama3.3
- **Open WebUI** (localhost only, SSH tunnel access)
- **Dev Tools**: Node 20, npm, Docker, git, vim, jq
- **Security**: SSH-only access, no public APIs

## Quick Start

### 1. Deploy on RunPod/Quickpod

**Container Image**: `ghcr.io/jayyalldayyy/ollama-dev-container:latest`

**Volume**: Mount encrypted volume to `/mnt/data`

**Ports**: Expose port `22` (SSH)

**SSH Key**: Add your public key during setup

### 2. Connect from Local Machine
```bash
# SSH with tunnels
ssh -L 8080:localhost:8080 -L 11434:localhost:11434 root@POD_IP

# Access services
# Open WebUI: http://localhost:8080
# Ollama API: http://localhost:11434
```

### 3. VS Code Remote SSH

Add to `~/.ssh/config`:
```ssh
Host gpu-pod
    HostName YOUR_POD_IP
    User root
    IdentityFile ~/.ssh/id_rsa
    LocalForward 8080 localhost:8080
    LocalForward 11434 localhost:11434
```

Connect via VS Code: `Remote-SSH: Connect to Host` → `gpu-pod`

### 4. Start Coding
```bash
cd /mnt/data/workspace
git clone YOUR_REPO
# Install Continue.dev or Cline in VS Code
# Point to http://localhost:11434
```

## Persistent Data

All data stored in `/mnt/data/`:
- `/mnt/data/ollama/` - Models
- `/mnt/data/open-webui/` - Chats, system prompts, uploads
- `/mnt/data/workspace/` - Your code repos

## Migrate Open WebUI Data
```bash
# From existing server
cd /path/to/open-webui/data
tar -czf backup.tar.gz .
scp backup.tar.gz root@POD_IP:/tmp/

# On GPU pod
cd /app && docker-compose down
cd /mnt/data/open-webui
tar -xzf /tmp/backup.tar.gz
cd /app && docker-compose up -d
```

## Available Models

- `deepseek-coder-v2:latest` - Best for coding
- `mistral:7b` - Fast, general purpose
- `llama3.3:latest` - Instruction following

Check models: `ollama list`

Pull more: `ollama pull MODEL_NAME`

## Troubleshooting

Check logs:
```bash
# Ollama logs
tail -f /var/log/ollama.log

# Docker logs
tail -f /var/log/dockerd.log

# Open WebUI logs
docker-compose logs -f open-webui
```

Restart services:
```bash
cd /app
docker-compose restart
```

## License

MIT
