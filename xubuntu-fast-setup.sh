#!/usr/bin/env bash
# How to use !!!
# chmod +x xubuntu-fast-setup.sh
# ./xubuntu-fast-setup.sh --all
# xubuntu-fast-setup.sh
# One-shot bootstrap for a fresh Xubuntu install (22.04/24.04) on GTX 1060.
# Installs NVIDIA driver, common desktop tools, AV editors, and dev stacks.
# Usage examples:
#   bash xubuntu-fast-setup.sh --all
#   bash xubuntu-fast-setup.sh --base --nvidia --av --node --python --docker
#   bash xubuntu-fast-setup.sh --av --resolve-deps
#
# Flags:
#   --base           Essentials, repos, updates
#   --nvidia         NVIDIA 535 driver + utils (Pascal/GTX 1060)
#   --av             VLC, Kdenlive, Audacity, OBS
#   --resolve-deps   Extra libraries often needed by DaVinci Resolve
#   --node           nvm + latest LTS Node.js
#   --python         python3-venv, pip, pipx
#   --docker         docker.io + compose v2, + group add
#   --timeshift      Timeshift (for ongoing snapshots after reinstall)
#   --extras         Quality-of-life tools (git, unzip, htop, etc.)
#   --all            Do everything above
#
# Safe re-runs: OK. Uses apt idempotently.
set -euo pipefail

say() { printf "\n\033[1;32m[SETUP]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }

want_base=false
want_nvidia=false
want_av=false
want_resolve_deps=false
want_node=false
want_python=false
want_docker=false
want_timeshift=false
want_extras=false

if [[ $# -eq 0 ]]; then
  warn "No flags provided. Defaulting to --base --nvidia --av --node --python --extras"
  want_base=true
  want_nvidia=true
  want_av=true
  want_node=true
  want_python=true
  want_extras=true
else
  for arg in "$@"; do
    case "$arg" in
      --base) want_base=true ;;
      --nvidia) want_nvidia=true ;;
      --av) want_av=true ;;
      --resolve-deps) want_resolve_deps=true ;;
      --node) want_node=true ;;
      --python) want_python=true ;;
      --docker) want_docker=true ;;
      --timeshift) want_timeshift=true ;;
      --extras) want_extras=true ;;
      --all) want_base=true; want_nvidia=true; want_av=true; want_resolve_deps=true; want_node=true; want_python=true; want_docker=true; want_timeshift=true; want_extras=true ;;
      *) warn "Unknown flag: $arg" ;;
    esac
  done
fi

UBU_VER="$(. /etc/os-release && echo "${VERSION_ID}")"
say "Detected Ubuntu/Xubuntu ${UBU_VER}"

if $want_base; then
  say "Updating apt and enabling multiverse"
  sudo apt update -y || sudo apt update
  sudo add-apt-repository -y multiverse || true
  sudo apt update
fi

if $want_extras; then
  say "Installing essential CLI tools"
  sudo apt install -y \
    build-essential curl wget git ca-certificates gnupg lsb-release \
    unzip p7zip-full htop neofetch ripgrep fd-find jq tree
fi

if $want_nvidia; then
  say "Installing NVIDIA driver 535 and utilities for GTX 1060 (Pascal)"
  if apt-cache policy nvidia-driver-535 | grep -q Candidate; then
    sudo apt install -y nvidia-driver-535 nvidia-utils-535
  else
    warn "nvidia-driver-535 not available; installing recommended driver"
    sudo ubuntu-drivers autoinstall || true
  fi
  say "NVIDIA install queued. A reboot is recommended after this script."
fi

if $want_av; then
  say "Installing VLC, Kdenlive, Audacity, OBS Studio"
  sudo apt install -y vlc kdenlive audacity obs-studio
fi

if $want_resolve_deps; then
  say "Installing common DaVinci Resolve dependencies (runtime libs, OpenCL)"
  sudo apt install -y ocl-icd-opencl-dev clinfo libssl3 || true
  if apt-cache policy libssl1.1 | grep -q Candidate; then
    sudo apt install -y libssl1.1 || true
  else
    warn "libssl1.1 not in this release. If Resolve fails, consider manual install."
  fi
  sudo apt install -y fakeroot xorriso libfuse2 || true
  say "Resolve note: Install from Blackmagic .run installer after reboot."
fi

if $want_node; then
  say "Installing nvm + Node.js LTS"
  if [[ ! -d "$HOME/.nvm" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  fi
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
fi

if $want_python; then
  say "Installing Python dev basics (venv, pip, pipx)"
  sudo apt install -y python3-venv python3-pip pipx
  pipx ensurepath || true
fi

if $want_docker; then
  say "Installing Docker Engine + Compose v2"
  sudo apt install -y docker.io docker-compose-v2
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true
  warn "You must log out/in (or reboot) for docker group changes to apply."
fi

if $want_timeshift; then
  say "Installing Timeshift"
  sudo apt install -y timeshift
fi

say "All requested tasks done."
warn "Recommended: Reboot now (especially for NVIDIA). Then run: nvidia-smi"
