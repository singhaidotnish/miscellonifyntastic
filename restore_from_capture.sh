#!/usr/bin/env bash
# restore_from_capture.sh
# Reinstall snaps, flatpaks, pipx packages, and npm globals from your capture folder.
# Usage:
#   ./restore_from_capture.sh ~/system-capture-YYYYMMDD-HHMMSS

set -euo pipefail
CAPTURE_DIR="${1:-}"
[[ -d "$CAPTURE_DIR" ]] || { echo "Usage: $0 <path-to-capture-folder>"; exit 1; }

say(){ printf "\n\033[1;32m[RESTORE]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }

# 0) Basic tools that help the rest succeed
say "Installing helpers (snapd, flatpak, pipx) if missing"
sudo apt update
sudo apt install -y snapd flatpak pipx || true

# 1) Snaps
if [[ -f "$CAPTURE_DIR/snap-list.txt" ]]; then
  say "Restoring Snaps (best-effort)"
  # grab the first column (package names), skip the header line
  awk 'NR>1 {print $1}' "$CAPTURE_DIR/snap-list.txt" | while read -r s; do
    [[ -n "$s" ]] || continue
    echo "  -> snap install $s"
    sudo snap install "$s" || true
  done
  warn "If some snaps (e.g., code) need --classic, reinstall them manually: sudo snap install code --classic"
else
  warn "snap-list.txt not found; skipping snaps"
fi

# 2) Flatpaks
if [[ -f "$CAPTURE_DIR/flatpak-list.txt" ]]; then
  say "Restoring Flatpaks"
  # ensure flathub remote exists
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  # file has columns: application,ref,origin
  # prefer installing by ref+origin when available
  awk -F'\t' 'NF>=3 {print $2 "|" $3}' "$CAPTURE_DIR/flatpak-list.txt" | while IFS='|' read -r ref origin; do
    [[ -n "$ref" && -n "$origin" ]] || continue
    echo "  -> flatpak install -y $origin $ref"
    flatpak install -y "$origin" "$ref" || true
  done
else
  warn "flatpak-list.txt not found; skipping flatpaks"
fi

# 3) pipx packages
if [[ -f "$CAPTURE_DIR/pipx-list.txt" ]]; then
  say "Restoring pipx packages (best-effort)"
  # Lines look like: "package black 23.7.0, installed using Python ..."
  awk '/^package / {print $2}' "$CAPTURE_DIR/pipx-list.txt" | while read -r pkg; do
    [[ -n "$pkg" ]] || continue
    echo "  -> pipx install $pkg"
    pipx install "$pkg" || true
  done
else
  warn "pipx-list.txt not found; skipping pipx"
fi

# 4) Global npm packages (requires Node/npm installed—via nvm or apt)
if [[ -f "$CAPTURE_DIR/npm-global.txt" ]]; then
  if command -v npm >/dev/null 2>&1; then
    say "Restoring global npm packages (best-effort)"
    # Parse tree lines like "├── pkg@1.2.3" or "└── pkg@1.2.3"
    grep -E '├──|└──' "$CAPTURE_DIR/npm-global.txt" \
      | sed -E 's/.* (.+)@.*/\1/' \
      | while read -r mod; do
          [[ -n "$mod" ]] || continue
          echo "  -> npm -g install $mod"
          npm -g install "$mod" || true
        done
  else
    warn "npm not found; install Node first (e.g., via nvm) then re-run this section."
  fi
else
  warn "npm-global.txt not found; skipping npm globals"
fi

# 5) Timeshift info (reminder)
if [[ -f "$CAPTURE_DIR/timeshift-list.txt" ]]; then
  warn "Timeshift snapshot list found. To restore system snapshots:"
  echo "  sudo apt install -y timeshift && sudo timeshift-gtk"
fi

say "Done. Review any warnings above and reinstall special cases manually if needed."
