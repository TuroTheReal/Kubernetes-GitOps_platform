#!/bin/bash

echo "Configuration de la VM IoT..."

export DEBIAN_FRONTEND=noninteractive 

apt-get update

echo "Installation de VirtualBox..."
# headers du noyau QUI TOURNE : le module vboxdrv est compile pour lui -> utilisable sans reboot
apt-get install -y linux-headers-$(uname -r)
apt-get install -y virtualbox

echo "Installation de Vagrant..."
wget -O - https://apt.releases.hashicorp.com/gpg | gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update && apt install -y vagrant

echo "Installation de Git..."
apt-get install -y git

usermod -aG vboxusers vagrant
