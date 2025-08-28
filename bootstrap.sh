#!/usr/bin/env bash
# bootstrap.sh
# Capture current package list, reinstall from it, and set up extra tools/dev environment.
# Usage:
#   ./bootstrap.sh capture my-packages.txt     # save current package list
#   ./bootstrap.sh reinstall my-packages.txt  # reinstall packages from a list
#   ./bootstrap.sh extras [--no-gpu]          # install opinionated extras (GPU/AV/dev/tools)
#   ./bootstrap.sh all                        # run everything in sequence

set -euo pipefail

say(){ printf "\n\033[1;32m[BOOTSTRAP]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }

ACTION="${1:-help}"
LISTFILE="${2:-my-packages.txt}"

capture_packages() {
  say "Exporting manually-installed packages..."
  apt-mark showmanual | sort > /tmp/manual-all.txt
  EXCLUDE_REGEX="(^adduser$|^apt$|^base-files$|^bash$|^bsdutils$|^coreutils$|^dash$|^debconf$|^debianutils$|^dpkg$|^e2fsprogs$|^findutils$|^gcc-\\d+|^gnupg$|^grep$|^gzip$|^hostname$|^init$|^login$|^mount$|^passwd$|^sed$|^systemd|^tar$|^tzdata$|^ubuntu-minimal$|^ubuntu-standard$|^xubuntu-desktop$)"
  grep -Ev "$EXCLUDE_REGEX" /tmp/manual-all.txt > "$LISTFILE" || true
  say "Package list written to $LISTFILE"
}

reinstall_packages() {
  [[ -f "$LISTFILE" ]] || { warn "List file not found: $LISTFILE"; exit 1; }
  say "Updating apt..."
  sudo apt update
  say "Reinstalling packages from $LISTFILE..."
  xargs -r -a <(grep -Ev '^\s*#|^\s*$' "$LISTFILE") sudo apt install -y
  say "Reinstall complete."
}

install_extras() {
  WANT_GPU=1
  for a in "$@"; do
    case "$a" in
      --no-gpu) WANT_GPU=0 ;;
    esac
  done

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

  say "Extras install complete."
}

case "$ACTION" in
  capture) capture_packages ;;
  reinstall) reinstall_packages ;;
  extras) shift; install_extras "$@" ;;
  all)
    capture_packages
    reinstall_packages
    install_extras
    ;;
  *) 
    echo "Usage:"
    echo "  $0 capture [outfile]         # export package list"
    echo "  $0 reinstall [infile]        # reinstall packages from list"
    echo "  $0 extras [--no-gpu]         # install extras (GPU/AV/dev)"
    echo "  $0 all                       # do everything in sequence"
    ;;
esac
