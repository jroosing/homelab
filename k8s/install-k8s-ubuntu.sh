#!/bin/bash

set -e

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Disable Swap (Kubernetes requires swap to be disabled)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install necessary packages
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker GPG key and Kubernetes repository
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package index
sudo apt-get update

# Install containerd
sudo apt-get install -y containerd.io

# Configure containerd and set it up with systemd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable kubelet

# Setup sysctl for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Initialize Kubernetes (only on the control plane node)
# sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/containerd/containerd.sock

# Set up kubeconfig for the default user (if this is the control plane node)
# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install a network plugin (such as Calico or Flannel) after the kubeadm init step
# Example for Flannel:
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "Kubernetes with containerd installed. You can now run 'kubeadm init' to set up the cluster."
