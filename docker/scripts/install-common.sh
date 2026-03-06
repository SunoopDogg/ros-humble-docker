#!/bin/bash
set -e

# Refresh expired ROS2 GPG key
if command -v curl &> /dev/null; then
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
else
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F42ED6FBAB17C654
fi

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
