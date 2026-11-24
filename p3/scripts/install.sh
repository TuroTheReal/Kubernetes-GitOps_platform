#!/bin/bash

set -e

if ! command -v docker > /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

sudo usermod -aG docker $USER

if ! command -v kubectl > /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

if ! command -v k3d > /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! sg docker -c "k3d cluster get iot" > /dev/null 2>&1; then
    sg docker -c 'k3d cluster create iot -p "8888:8888@loadbalancer"'
fi
