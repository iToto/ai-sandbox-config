# Claude Code Sandbox

A sandboxed Docker environment for running Claude Code on a remote Ubuntu server,
accessible via Tailscale SSH and TMUX.

## Files

| File | Description |
|---|---|
| `Dockerfile` | Builds the sandbox image |
| `docker-compose.yml` | Defines the container, volumes, and network |
| `.tmux.conf` | TMUX quality-of-life config |
| `.p10k.zsh` | Powerlevel10k prompt config |
| `iptables-setup.sh` | Blocks container from reaching your LAN and Tailscale devices (run once on host) |

## Prerequisites

- Ubuntu server with Tailscale installed and running
- Docker and Docker Compose (see `make install`)
- [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) font installed on your local machine
- Ghostty (or any terminal emulator) configured to use MesloLGS NF

## First Time Setup

### 0. Set environment variables (on your laptop)

Add the following to your `~/.zshrc` or `~/.bashrc`:

```bash
export SANDBOX_USER=your-server-username
export SANDBOX_IP=your-server-tailscale-ip
```

Then reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 1. Install Docker and Docker Compose (on the server)

```bash
make install
```

Log out and back in after this step for Docker group changes to take effect.

### 2. Set file permissions (on the server)

```bash
chmod 644 Dockerfile docker-compose.yml .tmux.conf .p10k.zsh
chmod 744 iptables-setup.sh
chmod 755 workspace/ claude-auth/
```

### 3. Build and start the container

```bash
make build
```

### 4. Apply LAN and Tailscale isolation rules (once)

First check your LAN subnet:
```bash
ip route | grep default
```

Edit `iptables-setup.sh` if your subnet differs from `192.168.1.0/24`, then:
```bash
./iptables-setup.sh
```

### 5. Log in to Claude

```bash
make ssh
```

Then inside the container:
```bash
claude
```

Follow the browser login flow. Your credentials are saved to `./claude-auth` on the
host and will persist across container rebuilds.

## Daily Use

SSH into the container from your laptop via Tailscale:
```bash
make ssh
```

Or from the server directly:
```bash
docker exec -it claude-sandbox tmux attach -t main
```

Or use the server alias:
```bash
# Add to ~/.bashrc or ~/.zshrc on the server
alias sandbox='docker exec -it claude-sandbox tmux attach -t main'
```

## Network Isolation

| | Server | Container |
|---|---|---|
| Internet | ✅ | ✅ |
| Regular DNS | ✅ | ✅ (`1.1.1.1`, `8.8.8.8`) |
| LAN (`192.168.x.x`, `10.x.x.x`, `172.16.x.x`) | ✅ | ❌ Blocked by iptables |
| Tailscale devices (`100.64.0.0/10`) | ✅ | ❌ Blocked by iptables |
| Tailscale MagicDNS | ✅ | ❌ No access (uses public DNS only) |

## Makefile Targets

| Target | Description |
|---|---|
| `make install` | Install Docker and Docker Compose on the server |
| `make build` | Build and start the container |
| `make restart` | Restart the container |
| `make destroy` | Stop and remove the container |
| `make ssh` | SSH into the container via Tailscale |

## Volumes

| Host | Container | Description |
|---|---|---|
| `./workspace` | `/workspace` | Your working directory — persists across rebuilds |
| `./claude-auth` | `/root/.claude` | Claude login credentials — persists across rebuilds |

## Rebuilding the Container

```bash
make destroy
make build
```

Your workspace and Claude login are preserved via the mounted volumes.

## Verifying Network Isolation

Run these from inside the container to verify isolation is working:

```bash
# Should fail - LAN
ping -c 3 192.168.1.1

# Should fail - Tailscale devices
ping -c 3 100.x.x.x

# Should fail - MagicDNS
nslookup your-tailscale-node-name

# Should succeed - internet
ping -c 3 google.com
nslookup google.com
```

If any LAN or Tailscale pings succeed, re-run `./iptables-setup.sh`.
