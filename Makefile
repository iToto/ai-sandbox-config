CONTAINER_NAME=claude-sandbox
SERVER_USER ?= $(shell echo $$SANDBOX_USER)
SERVER_IP ?= $(shell echo $$SANDBOX_IP)

.PHONY: install build restart destroy clean ssh help

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
		sudo apt-get update; \
		sudo apt-get install -y ca-certificates curl gnupg; \
		sudo install -m 0755 -d /etc/apt/keyrings; \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
		sudo chmod a+r /etc/apt/keyrings/docker.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
		sudo apt-get update; \
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
		sudo usermod -aG docker $$USER; \
		echo "Docker and Docker Compose installed. Log out and back in for group changes to take effect."; \
	else \
		echo "Docker already installed: $$(docker --version)"; \
		echo "Checking for Docker Compose..."; \
		if ! docker compose version &> /dev/null; then \
			echo "Installing Docker Compose plugin..."; \
			sudo apt-get update && sudo apt-get install -y docker-compose-plugin; \
			echo "Docker Compose installed: $$(docker compose version)"; \
		else \
			echo "Docker Compose already installed: $$(docker compose version)"; \
		fi; \
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

clean:
	@echo "Stopping and removing all containers, images, and volumes..."
	-docker compose down --volumes --rmi all 2>/dev/null || true
	@echo "Removing local workspace and auth directories..."
	rm -rf workspace claude-auth
	@echo "Uninstalling Docker..."
	sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
	sudo apt-get autoremove -y
	sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
	sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
	sudo groupdel docker 2>/dev/null || true
	@echo "Removing iptables isolation rules..."
	-sudo iptables -D DOCKER-USER -s 172.18.0.0/16 -d 192.168.1.0/24 -j DROP 2>/dev/null || true
	-sudo iptables -D DOCKER-USER -s 172.18.0.0/16 -d 10.0.0.0/8 -j DROP 2>/dev/null || true
	-sudo iptables -D DOCKER-USER -s 172.18.0.0/16 -d 172.16.0.0/12 -j DROP 2>/dev/null || true
	-sudo iptables -D DOCKER-USER -s 172.18.0.0/16 -d 100.64.0.0/10 -j DROP 2>/dev/null || true
	-sudo netfilter-persistent save 2>/dev/null || true
	@echo "Done. System is clean."

ssh:
	@if [ -z "$(SERVER_USER)" ]; then echo "Error: SANDBOX_USER is not set. Add it to your shell profile."; exit 1; fi
	@if [ -z "$(SERVER_IP)" ]; then echo "Error: SANDBOX_IP is not set. Add it to your shell profile."; exit 1; fi
	ssh -t $(SERVER_USER)@$(SERVER_IP) "docker exec -it $(CONTAINER_NAME) tmux attach -t main 2>/dev/null || docker exec -it $(CONTAINER_NAME) tmux new-session -s main"

.DEFAULT_GOAL := help
