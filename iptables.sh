#!/bin/bash
LAN_SUBNET="192.168.1.0/24"
CONTAINER_SUBNET="172.18.0.0/16"

sudo iptables -I DOCKER-USER -s $CONTAINER_SUBNET -d $LAN_SUBNET -j DROP
sudo iptables -I DOCKER-USER -s $CONTAINER_SUBNET -d 10.0.0.0/8 -j DROP
sudo iptables -I DOCKER-USER -s $CONTAINER_SUBNET -d 172.16.0.0/12 -j DROP
sudo iptables -I DOCKER-USER -s $CONTAINER_SUBNET -d 100.64.0.0/10 -j DROP

sudo apt install -y iptables-persistent
sudo netfilter-persistent save

echo "LAN isolation rules applied."
