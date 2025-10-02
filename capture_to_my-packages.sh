#!/usr/bin/env bash
# capture_packages.sh
# Export the current system's manually-installed apt packages to a reproducible list.
# Usage: ./capture_packages.sh my-packages.txt

set -euo pipefail
OUT="${1:-my-packages.txt}"

echo "[*] Exporting manually-installed packages..."
apt-mark showmanual | sort > /tmp/manual-all.txt

# Filter out some base packages (optional, you can edit if needed)
EXCLUDE_REGEX="(^adduser$|^apt$|^base-files$|^bash$|^bsdutils$|^coreutils$|^dash$|^debconf$|^debianutils$|^dpkg$|^e2fsprogs$|^findutils$|^gcc-\\d+|^gnupg$|^grep$|^gzip$|^hostname$|^init$|^login$|^mount$|^passwd$|^sed$|^systemd|^tar$|^tzdata$|^ubuntu-minimal$|^ubuntu-standard$|^xubuntu-desktop$)"
grep -Ev "$EXCLUDE_REGEX" /tmp/manual-all.txt > "/tmp/manual-filtered.txt" || true

echo "[*] Writing package list to ${OUT}"
cp "/tmp/manual-filtered.txt" "${OUT}"
echo "[*] Done. Review and trim ${OUT} as needed."
