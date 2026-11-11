#!/bin/bash
# p1/scripts/server.sh
# Install K3s en mode server, bind sur 192.168.56.110, expose le node-token.
# A ecrire toi-meme : voir guide-p1.md (section 2).
# TODO
echo "Installation de K3s en mode server..."
curl -sfL https://get.k3s.io |  INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=eth1 --write-kubeconfig-mode=644" sh  -

echo "Génération du token..."

mkdir -p /vagrant/secrets
cp /var/lib/rancher/k3s/server/node-token /vagrant/secrets/node-token