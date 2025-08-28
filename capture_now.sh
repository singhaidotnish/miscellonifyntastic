#!/usr/bin/env bash
# capture_now.sh — grab lists of packages, tools, sources, drivers, and system info.
set -euo pipefail
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$HOME/system-capture-$TS"
mkdir -p "$OUT"

echo "[*] Writing to $OUT"

# APT packages
apt-mark showmanual | sort > "$OUT/apt-manual.txt"
dpkg -l > "$OUT/dpkg-list.txt"
grep -r ^deb /etc/apt/sources.list* /etc/apt/sources.list.d/* 2>/dev/null > "$OUT/apt-sources.txt" || true

# Drivers / GPU
( command -v ubuntu-drivers >/dev/null && ubuntu-drivers devices ) > "$OUT/ubuntu-drivers.txt" 2>/dev/null || true
( command -v nvidia-smi >/dev/null && nvidia-smi ) > "$OUT/nvidia-smi.txt" 2>/dev/null || true
lspci | grep -iE 'vga|3d' > "$OUT/lspci-gpu.txt" || true

# Snaps / Flatpaks
( command -v snap >/dev/null && snap list ) > "$OUT/snap-list.txt" 2>/dev/null || true
( command -v flatpak >/dev/null && flatpak list --app --columns=application,ref,origin ) > "$OUT/flatpak-list.txt" 2>/dev/null || true

# Python (pipx + quick global list)
( command -v pipx >/dev/null && pipx list --include-injected ) > "$OUT/pipx-list.txt" 2>/dev/null || true
( command -v pip3 >/dev/null && pip3 list --user ) > "$OUT/pip3-user-list.txt" 2>/dev/null || true

# Node (global)
( command -v npm >/dev/null && npm -g list --depth=0 ) > "$OUT/npm-global.txt" 2>/dev/null || true

# Docker inventory
( command -v docker >/dev/null && docker images ) > "$OUT/docker-images.txt" 2>/dev/null || true
( command -v docker >/dev/null && docker ps -a ) > "$OUT/docker-containers.txt" 2>/dev/null || true
( command -v docker-compose >/dev/null && docker-compose version ) > "$OUT/docker-compose-version.txt" 2>/dev/null || true
( command -v docker >/dev/null && docker compose version ) > "$OUT/docker-compose-v2-version.txt" 2>/dev/null || true

# Schedulers / Timeshift
crontab -l > "$OUT/crontab.txt" 2>/dev/null || true
( command -v timeshift >/dev/null && sudo timeshift list ) > "$OUT/timeshift-list.txt" 2>/dev/null || true

# System info
uname -a > "$OUT/uname.txt"
( command -v lsb_release >/dev/null && lsb_release -a ) > "$OUT/lsb_release.txt" 2>/dev/null || true
lscpu > "$OUT/lscpu.txt"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT > "$OUT/lsblk.txt"
df -h > "$OUT/df-h.txt"

echo "[*] Creating a tarball…"
tar czf "$OUT.tar.gz" -C "$HOME" "$(basename "$OUT")"
echo "[*] Done: $OUT.tar.gz  (copy this to your external drive/USB)"
