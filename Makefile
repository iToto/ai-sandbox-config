CONTAINER_NAME=claude-sandbox
SERVER_USER ?= $(shell echo $$SANDBOX_USER)
SERVER_IP ?= $(shell echo $$SANDBOX_IP)

.PHONY: install build restart destroy ssh help

help:
	@echo ""
	@echo "Claude Code Sandbox"
	@echo "-------------------"
	@echo "make install    Install Docker and Docker Compose on the server"
	@echo "make build      Build and start the container"
	@echo "make restart    Restart the container"
	@echo "make destroy    Stop and remove the container"
	@echo "make ssh        SSH into the container via Tailscale"
	@echo ""

install:
	@echo "Checking for Docker..."
	@if ! command -v docker &> /dev/null; then \
		echo "Installing Docker..."; \
		curl -fsSL https://get.docker.com | sh; \
		sudo usermod -aG docker $$USER; \
		echo "Docker installed. You may need to log out and back in for group changes to take effect."; \
	else \
		echo "Docker already installed: $$(docker --version)"; \
	fi
	@echo "Checking for Docker Compose..."
	@if ! docker compose version &> /dev/null; then \
		echo "Installing Docker Compose plugin..."; \
		sudo apt-get update && sudo apt-get install -y docker-compose-plugin; \
		echo "Docker Compose installed."; \
	else \
		echo "Docker Compose already installed: $$(docker compose version)"; \
	fi

build:
	@echo "Creating workspace and auth directories..."
	@mkdir -p workspace claude-auth
	@chmod 755 workspace claude-auth
	@echo "Building and starting container..."
	docker compose up -d --build
	@echo "Applying LAN isolation rules..."
	@chmod +x iptables.sh && ./iptables.sh
	@echo ""
	@echo "Container is running. To log in to Claude, run: make ssh"

restart:
	@echo "Restarting container..."
	docker compose restart
	@echo "Container restarted."

destroy:
	@echo "Stopping and removing container..."
	docker compose down
	@echo "Container destroyed. Your workspace and Claude auth are preserved."

ssh:
	@if [ -z "$(SERVER_USER)" ]; then echo "Error: SANDBOX_USER is not set. Add it to your shell profile."; exit 1; fi
	@if [ -z "$(SERVER_IP)" ]; then echo "Error: SANDBOX_IP is not set. Add it to your shell profile."; exit 1; fi
	ssh -t $(SERVER_USER)@$(SERVER_IP) "docker exec -it $(CONTAINER_NAME) tmux attach -t main || docker exec -it $(CONTAINER_NAME) tmux new-session -s main"

.DEFAULT_GOAL := help
