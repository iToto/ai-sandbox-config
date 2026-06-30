#!/bin/bash
# Blocks the sandbox VM from reaching your LAN and Tailscale devices,
# the same isolation the Docker setup applied via DOCKER-USER, but
# applied to the dedicated libvirt bridge instead.
set -euo pipefail

LAN_SUBNET="192.168.1.0/24"
VM_SUBNET="192.168.100.0/24"
BRIDGE="virbr-sandbox"

sudo iptables -I FORWARD -i "$BRIDGE" -s "$VM_SUBNET" -d "$LAN_SUBNET" -j DROP
sudo iptables -I FORWARD -i "$BRIDGE" -s "$VM_SUBNET" -d 10.0.0.0/8 -j DROP
sudo iptables -I FORWARD -i "$BRIDGE" -s "$VM_SUBNET" -d 172.16.0.0/12 -j DROP
sudo iptables -I FORWARD -i "$BRIDGE" -s "$VM_SUBNET" -d 100.64.0.0/10 -j DROP

sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save

echo "LAN/Tailscale isolation rules applied to $BRIDGE."
