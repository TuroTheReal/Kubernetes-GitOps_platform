#!/bin/bash

set -e

if ! command -v docker > /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

sudo usermod -aG docker $USER