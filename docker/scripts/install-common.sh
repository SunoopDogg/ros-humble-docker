#!/bin/bash
set -e

apt update

# Core utilities
apt install -y --no-install-recommends ca-certificates curl unzip

# Git + Git LFS
apt install -y --no-install-recommends git git-lfs
git lfs install

# GUI / Rendering libraries
apt install -y --no-install-recommends libgl1 libgtk2.0-dev tk

# uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# nvm (Node.js version manager)
export NVM_DIR=/root/.nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
. "$NVM_DIR/nvm.sh"

# Cleanup
apt clean
rm -rf /var/lib/apt/lists/*
