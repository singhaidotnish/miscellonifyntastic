#!/usr/bin/env bash
# nishith-extras-setup.sh
# Opinionated extras based on your chat history: GPU, audio/video tools, dev stacks, archive tools, QoL.
# Usage: ./nishith-extras-setup.sh
# Optional: ./nishith-extras-setup.sh --no-gpu  (skip NVIDIA bits)

set -euo pipefail
WANT_GPU=1
for a in "$@"; do
  case "$a" in
    --no-gpu) WANT_GPU=0 ;;
  esac
done

say(){ printf "\n\033[1;32m[SETUP]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }

say "Updating apt and enabling multiverse"
sudo apt update -y || sudo apt update
sudo add-apt-repository -y multiverse || true
sudo apt update

say "Core CLI & QoL"
sudo apt install -y build-essential curl wget git ca-certificates gnupg lsb-release \
  unzip p7zip-full p7zip-rar xarchiver thunar-archive-plugin \
  htop neofetch ripgrep fd-find jq tree xclip ffmpeg

if [[ "$WANT_GPU" -eq 1 ]]; then
  say "NVIDIA driver for GTX 1060 (Pascal)"
  if apt-cache policy nvidia-driver-535 | grep -q Candidate; then
    sudo apt install -y nvidia-driver-535 nvidia-utils-535
  else
    warn "nvidia-driver-535 not available; using ubuntu-drivers autoinstall"
    sudo ubuntu-drivers autoinstall || true
  fi
  warn "Reboot recommended after this script, then run: nvidia-smi"
fi

say "Audio/Video apps"
sudo apt install -y vlc kdenlive audacity obs-studio qjackctl pavucontrol

say "Timeshift (system snapshots)"
sudo apt install -y timeshift

say "Python toolchain"
sudo apt install -y python3-venv python3-pip pipx
pipx ensurepath || true

say "Node.js via nvm (LTS)"
if [[ ! -d "$HOME/.nvm" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'

say "Docker Engine + Compose v2"
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true
warn "Log out/in (or reboot) so docker group applies."

say "Done. Reboot recommended."
