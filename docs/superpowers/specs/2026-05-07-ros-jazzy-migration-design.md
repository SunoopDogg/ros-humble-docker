# ROS Jazzy Docker Migration Design

**Date:** 2026-05-07  
**Target path:** `/home/airo-workstation/projects/ros-jazzy-docker`  
**Source:** `/home/airo-workstation/projects/ros-humble-docker`

---

## Overview

Migrate the ros-humble-docker development environment to ROS 2 Jazzy Jalisco. The new project lives in a separate directory (`ros-jazzy-docker`) rather than modifying the existing humble repo in-place.

Key driver: ROS Jazzy is based on Ubuntu 24.04 (Noble), while Humble uses Ubuntu 22.04 (Jammy). This forces base image changes across all targets.

---

## Architecture

Three build targets, same as Humble:

| Target | Profile | Base Image | ROS Install |
|--------|---------|------------|-------------|
| AMD64 (default) | — | `nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04` | Installed in Dockerfile |
| AMD64 GPU | `gpu` | same, extends AMD64 | Inherited |
| Jetson ARM64 | `jetson` | `dustynv/ros:jazzy-ros-base-r36.2.0` | Pre-installed in base |

**Critical difference from Humble:** The Jetson base image (`dustynv/ros:jazzy-ros-base-r36.2.0`) already ships ROS Jazzy. The Jetson Dockerfile must skip ROS installation entirely to avoid conflicts.

This requires **two separate Dockerfiles**:
- `Dockerfile` — AMD64, installs ROS Jazzy from apt
- `Dockerfile.jetson` — Jetson, skips ROS, adds uv/nvm/system packages only

---

## File Changes

### `Dockerfile` (AMD64)

Changes from Humble:
- `BASE_IMAGE`: `ubuntu22.04` → `ubuntu24.04`
- `ros2-apt-source`: `.jammy_all.deb` → `.noble_all.deb` (sha256 fetched at build time)
- `ROS_DISTRO`: `humble` → `jazzy`
- ROS package: `ros-humble-ros-base=0.10.0-1*` → `ros-jazzy-ros-base` (version pin removed; Jazzy package versioning differs)
- Python context: Ubuntu 24.04 ships Python 3.12

### `Dockerfile.jetson` (new file)

Structure:
```dockerfile
FROM dustynv/ros:jazzy-ros-base-r36.2.0
# ROS Jazzy pre-installed — skip all ROS apt/rosdep setup

ENV DEBIAN_FRONTEND=noninteractive

# System packages (same as AMD64)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git libgl1 libgtk2.0-dev tk \
    && rm -rf /var/lib/apt/lists/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# nvm
ENV NVM_DIR=/root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh"
```

No `ros2-apt-source`, `rosdep init`, `colcon mixin`, or ROS package installation steps.

### `docker-compose.yaml`

| Field | Humble | Jazzy |
|-------|--------|-------|
| Service names | `ros-humble-docker*` | `ros-jazzy-docker*` |
| Container names | `ros-humble-docker*` | `ros-jazzy-docker*` |
| AMD64 image tag | `cuda12.9.1:humble-uv-nvm` | `cuda12.9.1:jazzy-uv-nvm` |
| Jetson image tag | `cudnn8.9-jetson:humble-uv-nvm` | `jazzy-ros-base-jetson:jazzy-uv-nvm` |
| Volume mount path | `/root/ros-humble-docker` | `/root/ros-jazzy-docker` |
| `working_dir` | `/root/ros-humble-docker` | `/root/ros-jazzy-docker` |
| Jetson build | `build: { args: { BASE_IMAGE: ... } }` | `build: { dockerfile: Dockerfile.jetson }` |

### `scripts/link_ros_to_venv.sh`

No changes required. Script uses `$ROS_DISTRO` env var (set in Dockerfile) and detects Python version dynamically.

### `pyproject.toml`

- `name`: `ros-humble-docker` → `ros-jazzy-docker`
- `requires-python`: `>=3.10` → `>=3.12`

### `.python-version`

- `3.10` → `3.12`

---

## Data Flow

```
Host                          Container
────────────────────────────────────────────────────────
$PWD (ros-jazzy-docker/) ──► /root/ros-jazzy-docker/
/tmp/.X11-unix ────────────► /tmp/.X11-unix
~/.Xauthority (jetson) ────► /root/.Xauthority
uv-cache volume ───────────► /root/.cache/uv
```

X11 forwarding and GPU passthrough unchanged from Humble.

---

## Error Handling

- `ros2-apt-source` sha256 mismatch will fail the build fast (existing `--strict --check` pattern retained).
- Jetson `rosdep` is pre-initialized in the dustynv base; no `rosdep init` call in `Dockerfile.jetson`.

---

## Testing

1. `docker compose build` succeeds for AMD64.
2. `docker compose --profile gpu up -d ros-jazzy-docker-gpu` launches with GPU access.
3. `docker compose --profile jetson up -d ros-jazzy-docker-jetson` launches (on Jetson host).
4. Inside AMD64 container: `ros2 topic list` returns without error after `source /opt/ros/jazzy/setup.bash`.
5. Inside container: `uv sync && bash scripts/link_ros_to_venv.sh && python -c "import rclpy"` succeeds.
6. GUI app test: `xhost +local:docker` on host, then `rviz2` inside container renders.

---

## Out of Scope

- ROS package migration (any custom packages in `src/`) — handled separately per package.
- Modifying the existing `ros-humble-docker` repo.
- Jetson JetPack version upgrade (stays at r36.2.0 / JetPack 6.0).
