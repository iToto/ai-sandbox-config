VM_NAME=claude-sandbox
IMAGE=packer/output/claude-sandbox/claude-sandbox.qcow2
DISK=/var/lib/libvirt/images/$(VM_NAME).qcow2
SERVER_USER ?= $(shell echo $$SANDBOX_USER)
SERVER_IP ?= $(shell echo $$SANDBOX_IP)

.PHONY: install image network launch start stop destroy ssh status help

help:
	@echo ""
	@echo "Claude Code VM Sandbox"
	@echo "-----------------------"
	@echo "make install   Install KVM/libvirt/Packer on the server"
	@echo "make image     Build the VM image with Packer (run once, or to rebuild)"
	@echo "make network   Create the isolated libvirt network + iptables rules (run once)"
	@echo "make launch    Define and start the VM from the built image"
	@echo "make start     Start an existing (stopped) VM"
	@echo "make stop      Gracefully shut down the VM"
	@echo "make destroy   Undefine and delete the VM (image on disk is preserved)"
	@echo "make ssh       SSH into the VM via Tailscale"
	@echo "make status    Show VM state and IP"
	@echo ""

install:
	@echo "Installing KVM/libvirt and Packer..."
	sudo apt-get update
	sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils
	sudo usermod -aG libvirt,kvm $$USER
	@if ! command -v packer &> /dev/null; then \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg; \
		echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list; \
		sudo apt-get update && sudo apt-get install -y packer; \
	fi
	@echo "Done. Log out and back in for the libvirt/kvm group changes to take effect."

image:
	cd packer && packer init sandbox.pkr.hcl && packer build sandbox.pkr.hcl

network:
	@if ! sudo virsh net-info sandbox-net &> /dev/null; then \
		sudo virsh net-define libvirt-network.xml; \
		sudo virsh net-autostart sandbox-net; \
		sudo virsh net-start sandbox-net; \
	else \
		echo "sandbox-net already defined."; \
	fi
	@chmod +x network-isolation.sh && ./network-isolation.sh

launch:
	sudo mkdir -p /var/lib/libvirt/images
	sudo cp $(IMAGE) $(DISK)
	sudo virt-install \
		--name $(VM_NAME) \
		--memory 4096 \
		--vcpus 2 \
		--disk path=$(DISK),format=qcow2 \
		--import \
		--os-variant ubuntu24.04 \
		--network network=sandbox-net,model=virtio \
		--graphics none \
		--noautoconsole
	@echo "VM launched. Run 'make status' to find its IP, or 'make ssh' once Tailscale is set up inside it."

start:
	sudo virsh start $(VM_NAME)

stop:
	sudo virsh shutdown $(VM_NAME)

destroy:
	-sudo virsh destroy $(VM_NAME)
	sudo virsh undefine $(VM_NAME)
	@echo "VM removed. Disk image at $(DISK) was left in place; delete manually if you want a clean rebuild."

status:
	sudo virsh dominfo $(VM_NAME)
	sudo virsh domifaddr $(VM_NAME)

ssh:
	@if [ -z "$(SERVER_USER)" ]; then echo "Error: SANDBOX_USER is not set."; exit 1; fi
	@if [ -z "$(SERVER_IP)" ]; then echo "Error: SANDBOX_IP is not set."; exit 1; fi
	ssh -t $(SERVER_USER)@$(SERVER_IP) "true"
	@echo "Now SSH directly into the VM's Tailscale IP/hostname (see README)."

.DEFAULT_GOAL := help
