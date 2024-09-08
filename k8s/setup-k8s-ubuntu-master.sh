#!/bin/bash

set -e

# Check if an argument for advertise address IP is provided
# note the IP should be the actual IP address of the machine's network interface
if [ -z "$1" ]; then
  echo "Usage: $0 <advertise-address-ip>"
  exit 1
fi

ADVERTISE_ADDRESS="$1"

# Validate the provided IP address
if ! [[ $ADVERTISE_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid IP address format: $ADVERTISE_ADDRESS"
  exit 1
fi

# Initialize the Kubernetes control plane with kubeadm
echo "[INFO] Initializing Kubernetes control plane..."
sudo kubeadm init \
  --apiserver-advertise-address="$ADVERTISE_ADDRESS" \
  --pod-network-cidr=192.168.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock

# Setup kubeconfig for the current user
echo "[INFO] Setting up kubeconfig for the current user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install a network plugin (Flannel as an example)
echo "[INFO] Installing Flannel network plugin..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "[INFO] Kubernetes master node setup completed with containerd and pod network CIDR 192.168.0.0/16"
echo "[INFO] You can now join worker nodes using the kubeadm join command printed above."