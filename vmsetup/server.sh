#!/bin/bash
# Atelier IoT : VM Ubuntu qui heberge tout le projet.
# P1/P2 tournent ici via Vagrant + libvirt (KVM) : VirtualBox dans VirtualBox est instable.

set -e
echo "Configuration de la VM IoT..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

echo "Installation de KVM / libvirt..."
# qemu-system-x86 : l'emulateur/hyperviseur (utilise KVM = VT-x imbrique)
# libvirt-daemon-system : le service qui gere les VMs (Vagrant lui parle)
# libvirt-dev + build-essential + pkg-config : pour compiler le plugin vagrant-libvirt
# nfs-kernel-server : dossier /vagrant PARTAGE en direct (P1 : le worker lit le token du server)
apt-get install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
    libvirt-dev build-essential pkg-config nfs-kernel-server

echo "Installation de Vagrant..."
wget -O - https://apt.releases.hashicorp.com/gpg | gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install -y vagrant

echo "Installation de Git..."
apt-get install -y git

# droits : l'utilisateur vagrant peut piloter libvirt/KVM sans sudo
usermod -aG libvirt,kvm vagrant

echo "Installation du plugin vagrant-libvirt..."
# les plugins Vagrant sont propres a chaque utilisateur -> on l'installe EN TANT QUE vagrant
sudo -u vagrant -H vagrant plugin install vagrant-libvirt

# libvirt devient le provider par defaut dans cette VM -> plus besoin de --provider=libvirt
grep -q VAGRANT_DEFAULT_PROVIDER /home/vagrant/.bashrc || \
    echo 'export VAGRANT_DEFAULT_PROVIDER=libvirt' >> /home/vagrant/.bashrc

echo "VM IoT prete. Verif : virsh -c qemu:///system list --all && vagrant plugin list"
