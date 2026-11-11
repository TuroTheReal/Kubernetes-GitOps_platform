#!/bin/bash
# p1/scripts/worker.sh
# Install K3s en mode agent, join le server via IP + token.
# A ecrire toi-meme : voir guide-p1.md (section 3).
# TODO
echo "Installation de K3s en mode agent..."

echo "Waiting for the server to be ready..."
while [ ! -f /vagrant/secrets/node-token ]; do
  sleep 5
done

curl -sfL https://get.k3s.io |  K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$(cat /vagrant/secrets/node-token) INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=eth1" sh  -
