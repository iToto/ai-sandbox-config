# Usage

1. Clone / copy these files to your server
1. Fill in your API key in .env
1. Build and start
    `docker compose up -d --build`

1. Run LAN isolation (once)
    `chmod +x iptables-setup.sh && ./iptables-setup.sh`

1. Attach to the sandbox from anywhere on Tailscale
    `docker exec -it claude-sandbox tmux attach -t main`
