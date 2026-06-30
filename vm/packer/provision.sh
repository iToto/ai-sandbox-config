#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

# --- Same package set as the Dockerfile ---
sudo apt-get update
sudo apt-get install -y \
    curl \
    git \
    tmux \
    python3 \
    python3-pip \
    nodejs \
    npm \
    zsh \
    fontconfig \
    iputils-ping \
    iproute2 \
    nmap
sudo rm -rf /var/lib/apt/lists/*

# --- Oh My Zsh + Powerlevel10k + plugins (installed for the sandbox user, not root) ---
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

# --- Drop in tmux/p10k configs (copied into the image by Packer's file provisioner) ---
cp /tmp/sandbox-files/tmux.conf "$HOME/.tmux.conf"
cp /tmp/sandbox-files/.p10k.zsh "$HOME/.p10k.zsh"
echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> "$HOME/.zshrc"

# --- Claude Code ---
sudo npm install -g @anthropic-ai/claude-code@latest

# --- Default shell + workspace dir ---
sudo chsh -s "$(command -v zsh)" "$USER"
mkdir -p "$HOME/workspace"

# --- tmux auto-attach on login, mirrors the container's CMD ---
cat >> "$HOME/.zshrc" <<'EOF'

# Auto-attach to the sandbox tmux session on interactive SSH login
if [[ -z "$TMUX" && -n "$SSH_CONNECTION" ]]; then
    tmux new-session -A -s main -c "$HOME/workspace"
fi
EOF

# --- Trim image size / clean up cloud-init state so it re-runs cleanly per-clone ---
sudo apt-get clean
sudo cloud-init clean --logs || true
