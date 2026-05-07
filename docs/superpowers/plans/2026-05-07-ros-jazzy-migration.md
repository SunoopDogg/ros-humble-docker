# ROS Jazzy Docker Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `/home/airo-workstation/projects/ros-jazzy-docker` as a fully working ROS 2 Jazzy development environment mirroring the structure of `ros-humble-docker`.

**Architecture:** Two separate Dockerfiles — `Dockerfile` for AMD64 (installs ROS Jazzy from apt on CUDA+Ubuntu 24.04) and `Dockerfile.jetson` for Jetson ARM64 (skips ROS install since `dustynv/ros:jazzy-ros-base-r36.2.0` pre-ships it). Three Compose services: default AMD64, GPU-enabled AMD64, and Jetson.

**Tech Stack:** Docker Compose v3, ROS 2 Jazzy Jalisco, Ubuntu 24.04 Noble, Python 3.12, uv, nvm v0.40.1, CUDA 12.9.1 + cuDNN.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `Dockerfile` | Create | AMD64: CUDA Ubuntu 24.04 + ROS Jazzy install |
| `Dockerfile.jetson` | Create | Jetson: dustynv base + uv/nvm only |
| `docker-compose.yaml` | Create | Three services with jazzy names/paths |
| `scripts/link_ros_to_venv.sh` | Create | Link ROS Python pkgs into uv venv |
| `pyproject.toml` | Create | Project metadata, requires-python>=3.12 |
| `.python-version` | Create | Pin Python 3.12 for uv |
| `src/.gitkeep` | Create | Colcon workspace source placeholder |
| `.gitignore` | Create | Python + ROS ignores |
| `CLAUDE.md` | Create | Project guidance for Claude Code |

---

## Task 1: Initialize project directory

**Files:**
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/` (directory)
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/src/.gitkeep`
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/.gitignore`

- [ ] **Step 1: Create directory and git init**

```bash
mkdir -p /home/airo-workstation/projects/ros-jazzy-docker/src
cd /home/airo-workstation/projects/ros-jazzy-docker
git init
touch src/.gitkeep
```

Expected: `Initialized empty Git repository in /home/airo-workstation/projects/ros-jazzy-docker/.git/`

- [ ] **Step 2: Create .gitignore**

Copy from humble (identical content is appropriate — same Python/ROS ignores apply):

```bash
cp /home/airo-workstation/projects/ros-humble-docker/.gitignore \
   /home/airo-workstation/projects/ros-jazzy-docker/.gitignore
```

- [ ] **Step 3: Initial commit**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git add .gitignore src/.gitkeep
git commit -m "chore: Initialize ros-jazzy-docker repository"
```

---

## Task 2: Write AMD64 Dockerfile

**Files:**
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/Dockerfile`

- [ ] **Step 1: Fetch ros2-apt-source Noble deb sha256**

The hash must be computed from the actual file — do not guess it.

```bash
curl -fsSL -o /tmp/ros2-apt-source-noble.deb \
  https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.1.0/ros2-apt-source_1.1.0.noble_all.deb \
  && sha256sum /tmp/ros2-apt-source-noble.deb
```

Expected output format: `<64-hex-chars>  /tmp/ros2-apt-source-noble.deb`

Copy the 64-character hex hash — it is used in Step 2.

- [ ] **Step 2: Write Dockerfile**

Replace `<NOBLE_SHA256>` with the hash from Step 1.

```dockerfile
ARG BASE_IMAGE=nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Setup ROS Apt sources
RUN curl -L -s -o /tmp/ros2-apt-source.deb https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.1.0/ros2-apt-source_1.1.0.noble_all.deb \
    && echo "<NOBLE_SHA256> /tmp/ros2-apt-source.deb" | sha256sum --strict --check \
    && apt-get update \
    && apt-get install /tmp/ros2-apt-source.deb \
    && rm -f /tmp/ros2-apt-source.deb \
    && rm -rf /var/lib/apt/lists/*

# Setup environment
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ROS_DISTRO=jazzy

# Install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    build-essential \
    git \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# bootstrap rosdep
RUN rosdep init && \
  rosdep update --rosdistro $ROS_DISTRO

# Setup colcon mixin and metadata
RUN colcon mixin add default \
      https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon mixin update && \
    colcon metadata add default \
      https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update

# Install ros2 packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-jazzy-ros-base \
    && rm -rf /var/lib/apt/lists/*

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        git \
        libgl1 \
        libgtk2.0-dev \
        tk \
    && rm -rf /var/lib/apt/lists/*

# uv installation
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# nvm installation
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh"
```

Save to `/home/airo-workstation/projects/ros-jazzy-docker/Dockerfile`.

- [ ] **Step 3: Verify Dockerfile syntax (dry run)**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
docker compose build --no-cache --dry-run ros-jazzy-docker 2>&1 | head -20
```

If docker-compose.yaml doesn't exist yet, skip this step and return after Task 4.

- [ ] **Step 4: Commit**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git add Dockerfile
git commit -m "feat: Add AMD64 Dockerfile for ROS Jazzy on CUDA Ubuntu 24.04"
```

---

## Task 3: Write Dockerfile.jetson

**Files:**
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/Dockerfile.jetson`

- [ ] **Step 1: Write Dockerfile.jetson**

```dockerfile
FROM dustynv/ros:jazzy-ros-base-r36.2.0

ENV DEBIAN_FRONTEND=noninteractive

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        git \
        libgl1 \
        libgtk2.0-dev \
        tk \
    && rm -rf /var/lib/apt/lists/*

# uv installation
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# nvm installation
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh"
```

Save to `/home/airo-workstation/projects/ros-jazzy-docker/Dockerfile.jetson`.

Note: `ROS_DISTRO=jazzy` is already set by the dustynv base image. No `rosdep init` — also pre-done in base. No ROS apt setup.

- [ ] **Step 2: Commit**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git add Dockerfile.jetson
git commit -m "feat: Add Jetson Dockerfile for ROS Jazzy (dustynv base)"
```

---

## Task 4: Write docker-compose.yaml

**Files:**
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/docker-compose.yaml`

- [ ] **Step 1: Write docker-compose.yaml**

```yaml
services:
  # ===== AMD64 =====
  ros-jazzy-docker:
    image: cuda12.9.1:jazzy-uv-nvm
    build: .
    container_name: ros-jazzy-docker
    volumes:
      - .:/root/ros-jazzy-docker
      - /tmp/.X11-unix:/tmp/.X11-unix
      - uv-cache:/root/.cache/uv
    environment:
      - DISPLAY=${DISPLAY:-host.docker.internal:0}
      - QT_X11_NO_MITSHM=1
    network_mode: host
    working_dir: /root/ros-jazzy-docker
    ipc: host
    privileged: true
    tty: true

  ros-jazzy-docker-gpu:
    container_name: ros-jazzy-docker-gpu
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu, utility, compute, graphics]
    extends:
      service: ros-jazzy-docker
    profiles:
      - gpu

  # ===== Jetson ARM64 =====
  ros-jazzy-docker-jetson:
    image: jazzy-ros-base-jetson:jazzy-uv-nvm
    build:
      dockerfile: Dockerfile.jetson
    container_name: ros-jazzy-docker-jetson
    volumes:
      - .:/root/ros-jazzy-docker
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /tmp/argus_socket:/tmp/argus_socket
      - ~/.Xauthority:/root/.Xauthority
      - uv-cache:/root/.cache/uv
    environment:
      - DISPLAY=${DISPLAY}
      - QT_X11_NO_MITSHM=1
      - XAUTHORITY=/root/.Xauthority
    network_mode: host
    working_dir: /root/ros-jazzy-docker
    ipc: host
    privileged: true
    profiles:
      - jetson
    runtime: nvidia
    tty: true

volumes:
  uv-cache:
```

Save to `/home/airo-workstation/projects/ros-jazzy-docker/docker-compose.yaml`.

- [ ] **Step 2: Validate compose file**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
docker compose config --quiet
```

Expected: no output (success), exit code 0.

- [ ] **Step 3: Commit**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git add docker-compose.yaml
git commit -m "feat: Add docker-compose.yaml for ROS Jazzy (AMD64 + GPU + Jetson)"
```

---

## Task 5: Write project config files

**Files:**
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/scripts/link_ros_to_venv.sh`
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/pyproject.toml`
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/.python-version`

- [ ] **Step 1: Create scripts directory and link_ros_to_venv.sh**

Content is identical to humble — script uses `$ROS_DISTRO` and detects Python version dynamically, so no jazzy-specific changes needed.

```bash
mkdir -p /home/airo-workstation/projects/ros-jazzy-docker/scripts
cp /home/airo-workstation/projects/ros-humble-docker/scripts/link_ros_to_venv.sh \
   /home/airo-workstation/projects/ros-jazzy-docker/scripts/link_ros_to_venv.sh
chmod +x /home/airo-workstation/projects/ros-jazzy-docker/scripts/link_ros_to_venv.sh
```

- [ ] **Step 2: Create pyproject.toml**

```toml
[project]
name = "ros-jazzy-docker"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
requires-python = ">=3.12"
dependencies = []
```

Save to `/home/airo-workstation/projects/ros-jazzy-docker/pyproject.toml`.

- [ ] **Step 3: Create .python-version**

```
3.12
```

Save to `/home/airo-workstation/projects/ros-jazzy-docker/.python-version`.

- [ ] **Step 4: Generate uv.lock**

`uv lock` must be run on the host (requires Python 3.12 available via uv).

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
uv lock
```

Expected: creates `uv.lock` with no dependencies (empty project). If `uv` is not on PATH, use `~/.local/bin/uv lock`.

- [ ] **Step 5: Commit**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git add scripts/link_ros_to_venv.sh pyproject.toml .python-version uv.lock
git commit -m "feat: Add project config files (pyproject.toml, .python-version, link script)"
```

---

## Task 6: Write CLAUDE.md

**Files:**
- Create: `/home/airo-workstation/projects/ros-jazzy-docker/CLAUDE.md`

- [ ] **Step 1: Write CLAUDE.md**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Docker-based ROS 2 Jazzy development environment with three targets:
- **AMD64** (default): CUDA 12.9.1 + cuDNN on Ubuntu 24.04
- **AMD64 GPU**: same base, NVIDIA runtime enabled (profile: `gpu`)
- **Jetson ARM64**: `dustynv/ros:jazzy-ros-base-r36.2.0` base (profile: `jetson`) — ROS Jazzy pre-installed

The host repo root is bind-mounted into the container at `/root/ros-jazzy-docker`.

## Docker commands

```bash
# Build image
docker compose build

# Start default CPU container (detached)
docker compose up -d ros-jazzy-docker

# Start GPU container
docker compose --profile gpu up -d ros-jazzy-docker-gpu

# Start Jetson container
docker compose --profile jetson up -d ros-jazzy-docker-jetson

# Open a shell in a running container
docker compose exec ros-jazzy-docker bash

# One-shot interactive shell (auto-removes container)
docker compose run --rm ros-jazzy-docker bash
```

## Python / uv setup (inside container)

Python 3.12, managed by `uv`. The venv is `.venv/` at the repo root (inside container).

```bash
# Install dependencies and create venv
uv sync

# Link ROS 2 Python packages into the venv via a .pth file
bash scripts/link_ros_to_venv.sh

# Activate venv
source .venv/bin/activate
```

`scripts/link_ros_to_venv.sh` writes `/opt/ros/jazzy` site-packages paths into `.venv/lib/python3.12/site-packages/ros2.pth`, allowing `import rclpy` etc. from the uv venv.

## ROS 2 workspace

`src/` is the colcon workspace source directory. Add ROS 2 packages there.

```bash
# Source ROS base (required before colcon or ros2 CLI)
source /opt/ros/jazzy/setup.bash

# Build all packages in src/
colcon build --symlink-install

# Source the workspace overlay
source install/setup.bash
```

## Architecture notes

- **Base image override**: Pass `--build-arg BASE_IMAGE=<image>` to `docker compose build` (or set in compose `args`) to swap the AMD64 base, e.g. for a different CUDA version.
- **Jetson note**: The Jetson service uses `Dockerfile.jetson` which does NOT install ROS — it is already present in the `dustynv/ros:jazzy-ros-base-r36.2.0` base image. Only uv, nvm, and system packages are added.
- **X11 forwarding**: All services mount `/tmp/.X11-unix` and set `DISPLAY`; the Jetson variant also mounts `~/.Xauthority` and sets `XAUTHORITY`. On the host, run `xhost +local:docker` before launching GUI apps.
- **GPU access**: The `ros-jazzy-docker-gpu` service uses `deploy.resources.reservations.devices` (Compose v3 GPU syntax) and is only activated with `--profile gpu`. The Jetson service uses `runtime: nvidia` instead.
- **uv cache**: Persisted across container restarts via the named volume `uv-cache` at `/root/.cache/uv`.
- **nvm**: Installed at `/root/.nvm`; source `$NVM_DIR/nvm.sh` inside a shell to use `nvm`/`node`.
```

Save to `/home/airo-workstation/projects/ros-jazzy-docker/CLAUDE.md`.

- [ ] **Step 2: Commit**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git add CLAUDE.md
git commit -m "docs: Add CLAUDE.md project guidance"
```

---

## Task 7: Verify AMD64 build

Run this task on the AMD64 host (not Jetson). Jetson build can only be verified on Jetson hardware.

- [ ] **Step 1: Build AMD64 image**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
docker compose build ros-jazzy-docker
```

Expected: build completes without error. Final line: `=> exporting to image` or similar success message.

If `libgtk2.0-dev` is not found on Ubuntu 24.04 Noble, replace it with `libgtk-3-dev` in `Dockerfile` and rebuild.

- [ ] **Step 2: Verify ROS Jazzy inside container**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
docker compose run --rm ros-jazzy-docker bash -c "source /opt/ros/jazzy/setup.bash && ros2 --version"
```

Expected output: `ros2 1.x.x` (Jazzy version number).

- [ ] **Step 3: Verify uv inside container**

```bash
docker compose run --rm ros-jazzy-docker bash -c \
  "source /root/.cargo/env 2>/dev/null || true; /root/.local/bin/uv --version"
```

Expected: `uv x.x.x`

- [ ] **Step 4: Verify link_ros_to_venv.sh**

```bash
docker compose run --rm ros-jazzy-docker bash -c \
  "/root/.local/bin/uv sync && bash scripts/link_ros_to_venv.sh && source .venv/bin/activate && python -c 'import rclpy; print(rclpy.__file__)'"
```

Expected: prints path like `/opt/ros/jazzy/lib/python3.12/site-packages/rclpy/__init__.py`

- [ ] **Step 5: Commit verification result**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git commit --allow-empty -m "chore: Verify AMD64 ROS Jazzy build passes"
```

---

## Task 8: Final state commit

- [ ] **Step 1: Verify all files present**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
find . -not -path './.git/*' -type f | sort
```

Expected files:
```
./.gitignore
./.python-version
./CLAUDE.md
./Dockerfile
./Dockerfile.jetson
./docker-compose.yaml
./pyproject.toml
./scripts/link_ros_to_venv.sh
./src/.gitkeep
./uv.lock
```

- [ ] **Step 2: Verify git log**

```bash
cd /home/airo-workstation/projects/ros-jazzy-docker
git log --oneline
```

Expected (5–7 commits):
```
<hash> chore: Verify AMD64 ROS Jazzy build passes
<hash> docs: Add CLAUDE.md project guidance
<hash> feat: Add project config files (pyproject.toml, .python-version, link script)
<hash> feat: Add docker-compose.yaml for ROS Jazzy (AMD64 + GPU + Jetson)
<hash> feat: Add Jetson Dockerfile for ROS Jazzy (dustynv base)
<hash> feat: Add AMD64 Dockerfile for ROS Jazzy on CUDA Ubuntu 24.04
<hash> chore: Initialize ros-jazzy-docker repository
```

Migration complete. Jetson build verification requires Jetson hardware with Docker and the `nvidia` runtime.
