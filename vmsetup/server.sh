#!/bin/bash
# VM IoT : la machine de travail pour P3 et le bonus.
# Volontairement minimale : Docker, k3d et kubectl sont installes par
# p3/scripts/install.sh (le sujet exige de les installer pendant la soutenance).
# P1/P2 tournent sur le PC avec VirtualBox (VMs imbriquees instables sur les postes 42).

set -e
export DEBIAN_FRONTEND=noninteractive

echo "Configuration de la VM IoT..."
apt-get update
apt-get install -y git curl ca-certificates

echo "VM IoT prete. Connexion : ssh IoT"
