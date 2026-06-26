# Claude Code Sandbox

A sandboxed Docker environment for running Claude Code on a remote Ubuntu server, accessible via Tailscale SSH and TMUX.

## Files

| File | Description |
|---|---|
| `Dockerfile` | Builds the sandbox image |
| `docker-compose.yml` | Defines the container, volumes, and network |
| `.tmux.conf` | TMUX quality-of-life config |
| `iptables-setup.sh` | Blocks container from reaching your LAN (run once on host) |

## First Time Setup

### 1. Set file permissions
```bash
chmod 644 Dockerfile docker-compose.yml .tmux.conf
chmod 744 iptables-setup.sh
chmod 755 workspace/ claude-auth/
```

### 2. Build and start the container
```bash
docker compose up -d --build
```

### 3. Apply LAN isolation rules (once)
First, check your LAN subnet:
```bash
ip route
```

Edit `iptables-setup.sh` if your subnet differs from `192.168.1.0/24`, then run:
```bash
./iptables-setup.sh
```

### 4. Log in to Claude
```bash
docker exec -it claude-sandbox tmux attach -t main
```

Then inside the container:
```bash
claude
```

Follow the browser login flow. Your credentials are saved to `./claude-auth` on the
host and will persist across container rebuilds.

## Daily Use

Attach to the running sandbox from your server:
```bash
docker exec -it claude-sandbox tmux attach -t main
```

Or add this alias on your laptop to jump straight in over Tailscale:
```bash
alias claude-sandbox='ssh -t user@your-server-tailscale-ip "docker exec -it claude-sandbox tmux attach -t main"'
```

## Network Isolation

| |
