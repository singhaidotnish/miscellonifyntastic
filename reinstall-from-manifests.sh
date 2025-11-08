#!/usr/bin/env bash
set -euo pipefail

MANIFEST_DIR="./manifests"
DRY_RUN=1

usage() {
  cat <<EOF
Usage: $0 [--apply]
 --apply   actually perform installations (default is dry-run)
 --help    show this help
EOF
}

if [ "${1-}" = "--apply" ]; then
  DRY_RUN=0
fi

_log() { echo "[installer] $*"; }

confirm() {
  if [ "$DRY_RUN" -eq 1 ]; then
    _log "DRY RUN: $*"
  else
    read -p "$* (y/N): " ans
    case "$ans" in
      y|Y) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

_run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    _log "DRY RUN: $*"
  else
    _log "RUN: $*"
    eval "$@"
  fi
}

if [ ! -d "$MANIFEST_DIR" ]; then
  echo "Manifests not found in $MANIFEST_DIR. Please put manifests here."
  exit 1
fi

# A) distro detection
detect_pkg_mgr() {
  if command -v apt >/dev/null 2>&1; then echo "apt"; return; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
  if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
  if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
  echo "unknown"
}
PKG_MGR=$(detect_pkg_mgr)
_log "Detected package manager: $PKG_MGR"

# 1) apt
if [ -f "$MANIFEST_DIR/apt-packages.txt" ] && [ "$PKG_MGR" = "apt" ]; then
  _log "Installing apt packages (count: $(wc -l < "$MANIFEST_DIR/apt-packages.txt"))"
  confirm "About to install apt packages from $MANIFEST_DIR/apt-packages.txt?" || true
  if [ "$DRY_RUN" -eq 0 ]; then
    sudo apt-get update
    xargs -a "$MANIFEST_DIR/apt-packages.txt" -r sudo apt-get install -y
  fi
fi

# 2) dnf
if [ -f "$MANIFEST_DIR/dnf-packages.txt" ] && [ "$PKG_MGR" = "dnf" ]; then
  _log "Installing dnf packages"
  confirm "Install dnf packages?" || true
  if [ "$DRY_RUN" -eq 0 ]; then
    xargs -a "$MANIFEST_DIR/dnf-packages.txt" -r sudo dnf install -y
  fi
fi

# 3) pacman
if [ -f "$MANIFEST_DIR/pacman-packages.txt" ] && [ "$PKG_MGR" = "pacman" ]; then
  _log "Installing pacman packages"
  confirm "Install pacman packages?" || true
  if [ "$DRY_RUN" -eq 0 ]; then
    sudo pacman -Syu --noconfirm $(cat "$MANIFEST_DIR/pacman-packages.txt")
  fi
fi

# 4) snap
if [ -f "$MANIFEST_DIR/snap-packages.txt" ] && command -v snap >/dev/null 2>&1; then
  _log "Installing snap packages"
  while read -r s; do
    [ -z "$s" ] && continue
    confirm "snap install $s ?" || true
    if [ "$DRY_RUN" -eq 0 ]; then
      sudo snap install "$s" || echo "snap install failed for $s"
    fi
  done < "$MANIFEST_DIR/snap-packages.txt"
fi

# 5) flatpak
if [ -f "$MANIFEST_DIR/flatpak-apps.txt" ] && command -v flatpak >/dev/null 2>&1; then
  _log "Installing flatpak apps"
  while read -r f; do
    [ -z "$f" ] && continue
    confirm "flatpak install flathub $f ?" || true
    if [ "$DRY_RUN" -eq 0 ]; then
      flatpak install -y flathub "$f" || echo "flatpak install failed for $f"
    fi
  done < "$MANIFEST_DIR/flatpak-apps.txt"
fi

# 6) pip
if [ -f "$MANIFEST_DIR/pip-packages.txt" ] && command -v pip3 >/dev/null 2>&1; then
  _log "Installing pip packages"
  confirm "pip3 install -r $MANIFEST_DIR/pip-packages.txt ?" || true
  if [ "$DRY_RUN" -eq 0 ]; then
    sudo -H pip3 install -r "$MANIFEST_DIR/pip-packages.txt"
  fi
fi

# 7) npm global
if [ -f "$MANIFEST_DIR/npm-global-packages.txt" ] && command -v npm >/dev/null 2>&1; then
  _log "Installing npm global packages"
  if [ "$DRY_RUN" -eq 1 ]; then
    _log "DRY RUN: npm install -g $(tr '\\n' ' ' < \"$MANIFEST_DIR/npm-global-packages.txt\")"
  else
    xargs -a "$MANIFEST_DIR/npm-global-packages.txt" -r npm install -g
  fi
fi

# 8) cargo
if [ -f "$MANIFEST_DIR/cargo-packages.txt" ] && command -v cargo >/dev/null 2>&1; then
  _log "Installing cargo packages"
  while read -r c; do
    [ -z "$c" ] && continue
    confirm "cargo install $c ?" || true
    if [ "$DRY_RUN" -eq 0 ]; then
      cargo install "$c" || echo "cargo install failed for $c"
    fi
  done < "$MANIFEST_DIR/cargo-packages.txt"
fi

# 9) brew (mac) - only warn
if [ -f "$MANIFEST_DIR/brew-packages.txt" ]; then
  _log "brew manifest found. If this is macOS, run: brew install \$(cat $MANIFEST_DIR/brew-packages.txt)"
fi

# 10) manual apps: AppImages, /opt, .desktop
if [ -f "$MANIFEST_DIR/appimages.txt" ]; then
  _log "AppImages found in manifest. You may need to move them to ~/bin or /opt and chmod +x them."
  cat "$MANIFEST_DIR/appimages.txt"
fi

if [ -f "$MANIFEST_DIR/desktop-apps.txt" ]; then
  _log "Desktop apps listed (menu names) — installer cannot directly reconstruct some of these; consider installing corresponding packages manually."
  head -n 50 "$MANIFEST_DIR/desktop-apps.txt" || true
fi

# 11) custom manage-packages output (if any)
if [ -f "$MANIFEST_DIR/custom-manage-packages.txt" ]; then
  _log "Custom package list found at $MANIFEST_DIR/custom-manage-packages.txt"
  echo "Review this file and run commands inside it as desired."
fi

_log "Done. If DRY RUN, re-run with --apply to perform installations."
