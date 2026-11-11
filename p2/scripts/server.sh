#!/bin/bash

echo "Installation de K3s en mode server..."
curl -sfL https://get.k3s.io |  INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=eth1 --write-kubeconfig-mode=644" sh  -