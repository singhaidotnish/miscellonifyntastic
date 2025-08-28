#!/usr/bin/env bash
# reinstall_from_list.sh
# Reinstall packages from a list created by capture_packages.sh
# Usage: ./reinstall_from_list.sh my-packages.txt

set -euo pipefail
LIST="${1:-my-packages.txt}"
[[ -f "$LIST" ]] || { echo "List file not found: $LIST"; exit 1; }

echo "[*] Updating apt..."
sudo apt update

echo "[*] Installing packages from ${LIST} ..."
# Read list, ignore blanks and comments
xargs -r -a <(grep -Ev '^\s*#|^\s*$' "$LIST") sudo apt install -y

echo "[*] Done."
