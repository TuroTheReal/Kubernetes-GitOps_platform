#!/bin/bash
# p1/scripts/worker.sh
# Install K3s en mode agent, join le server via IP + token.
# A ecrire toi-meme : voir guide-p1.md (section 3).
# TODO
echo "Installation de K3s en mode agent..."
# curl -sfL https://get.k3s.io | K3S_URL=https://myserver:6443 K3S_TOKEN=mynodetoken sh -