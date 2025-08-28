#!/usr/bin/env bash
# restore_all.sh
# One script to:
#  - (optionally) pull latest capture + package list from GitHub (repo files or Releases)
#  - extract the capture tarball
#  - reinstall APT packages from my-packages.txt (if provided)
#  - restore snaps, flatpaks, pipx, npm globals (best-effort)

set -euo pipefail

# -------- Config (override via env or flags) --------
GITHUB_REPO="${GITHUB_REPO:-owner/repo}"       # e.g., singhaidotnish/backup
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"         # branch to pull if using repo files
GITHUB_SUBDIR="${GITHUB_SUBDIR:-Backups/Xubuntu}" # path in repo where backups live
GITHUB_TOKEN="${GITHUB_TOKEN:-}"               # set if repo is private or using Releases

LISTFILE_DEFAULT="${LISTFILE_DEFAULT:-$HOME/my-packages.txt}"

# -------- Flags --------
FROM_GITHUB=0
USE_RELEASES=0
TARBALL=""
LISTFILE="$LISTFILE_DEFAULT"

say(){ printf "\n\033[1;32m[RESTORE]\033[0m %s\n" "$*"; }
warn(){ printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
usage() {
  cat <<EOF
Usage:
  $0 [--from-github] [--releases] [--repo owner/repo] [--branch main]
     [--subdir Backups/Xubuntu] [--tar /path/capture.tar.gz] [--list /path/my-packages.txt]

Examples:
  # Use local files already in ~/
  $0 --tar ~/system-capture-YYYYMMDD-HHMMSS.tar.gz --list ~/my-packages.txt

  # Pull newest from GitHub repo files:
  GITHUB_REPO=owner/repo $0 --from-github

  # Pull newest from GitHub Releases instead:
  GITHUB_REPO=owner/repo GITHUB_TOKEN=... $0 --from-github --releases

Options:
  --from-github      Clone/download from GitHub first
  --releases         Fetch from GitHub Releases (default is repo files)
  --repo <owner/repo>
  --branch <name>    (for repo files)
  --subdir <path>    (folder in repo containing backups)
  --tar <file>       Use this capture tarball directly
  --list <file>      Use this APT package list (default: $LISTFILE_DEFAULT)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-github) FROM_GITHUB=1; shift ;;
    --releases) USE_RELEASES=1; shift ;;
    --repo) GITHUB_REPO="${2:-}"; shift 2 ;;
    --branch) GITHUB_BRANCH="${2:-}"; shift 2 ;;
    --subdir) GITHUB_SUBDIR="${2:-}"; shift 2 ;;
    --tar) TARBALL="${2:-}"; shift 2 ;;
    --list) LISTFILE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

fetch_from_github_repo_files() {
  say "Fetching from GitHub repo files: $GITHUB_REPO@$GITHUB_BRANCH in $GITHUB_SUBDIR"
  sudo apt update && sudo apt install -y git
  WORKDIR="$HOME/gh-backup-$(date +%s)"
  mkdir -p "$WORKDIR"
  # Prefer HTTPS clone; if private and you use SSH, replace with git@ URL
  REPO_URL="https://github.com/${GITHUB_REPO}.git"
  if [[ -n "$GITHUB_TOKEN" ]]; then
    REPO_URL="https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${GITHUB_REPO}.git"
  fi
  git clone --depth 1 -b "$GITHUB_BRANCH" "$REPO_URL" "$WORKDIR/repo"
  if [[ -d "$WORKDIR/repo/$GITHUB_SUBDIR" ]]; then
    # pick newest capture tarball and my-packages.txt if present
    local tgz
    tgz="$(ls -1t "$WORKDIR/repo/$GITHUB_SUBDIR"/system-capture-*.tar.gz 2>/dev/null | head -n1 || true)"
    if [[ -n "$tgz" ]]; then
      cp "$tgz" "$HOME/"
      TARBALL="$HOME/$(basename "$tgz")"
      say "Found capture: $TARBALL"
    else
      warn "No system-capture-*.tar.gz found under $GITHUB_SUBDIR"
    fi
    if [[ -f "$WORKDIR/repo/$GITHUB_SUBDIR/my-packages.txt" ]]; then
      cp "$WORKDIR/repo/$GITHUB_SUBDIR/my-packages.txt" "$HOME/"
      LISTFILE="$HOME/my-packages.txt"
      say "Found package list: $LISTFILE"
    fi
  else
    warn "Subdir not found: $WORKDIR/repo/$GITHUB_SUBDIR"
  fi
}

fetch_from_github_releases() {
  say "Fetching from GitHub Releases: $GITHUB_REPO (latest)"
  sudo apt update && sudo apt install -y curl jq
  AUTH=()
  [[ -n "$GITHUB_TOKEN" ]] && AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")

  JSON="$(curl -sSL "${AUTH[@]}" "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")"
  # capture tarball asset
  TGZ_URL="$(printf "%s" "$JSON" | jq -r '.assets[]?.browser_download_url | select(test("system-capture-.*\\.tar\\.gz$"))' | head -n1)"
  if [[ -n "$TGZ_URL" && "$TGZ_URL" != "null" ]]; then
    F="$HOME/$(basename "$TGZ_URL")"
    say "Downloading $TGZ_URL -> $F"
    curl -L "${AUTH[@]}" -o "$F" "$TGZ_URL"
    TARBALL="$F"
  else
    warn "No release asset matching system-capture-*.tar.gz"
  fi
  # my-packages.txt asset (optional)
  PKG_URL="$(printf "%s" "$JSON" | jq -r '.assets[]?.browser_download_url | select(endswith("my-packages.txt"))' | head -n1)"
  if [[ -n "$PKG_URL" && "$PKG_URL" != "null" ]]; then
    F2="$HOME/my-packages.txt"
    say "Downloading $PKG_URL -> $F2"
    curl -L "${AUTH[@]}" -o "$F2" "$PKG_URL"
    LISTFILE="$F2"
  fi
}

# ---- Optional GitHub fetch ----
if [[ "$FROM_GITHUB" -eq 1 ]]; then
  [[ "$GITHUB_REPO" == */* ]] || { warn "--repo must be owner/repo"; exit 1; }
  if [[ "$USE_RELEASES" -eq 1 ]]; then
    fetch_from_github_releases
  else
    fetch_from_github_repo_files
  fi
fi

# ---- Locate tarball if not provided ----
if [[ -z "${TARBALL:-}" ]]; then
  CANDIDATE="$(ls -1t "$HOME"/system-capture-*.tar.gz 2>/dev/null | head -n1 || true)"
  if [[ -n "$CANDIDATE" ]]; then
    TARBALL="$CANDIDATE"
    say "Using newest local capture: $TARBALL"
  else
    warn "No capture tarball found. You can still restore packages if you have a list."
  fi
fi

# ---- Extract capture ----
CAP_DIR=""
if [[ -n "${TARBALL:-}" && -f "$TARBALL" ]]; then
  say "Extracting capture: $TARBALL"
  tar xzf "$TARBALL" -C "$HOME"
  BASENAME="$(basename "$TARBALL" .tar.gz)"
  CAP_DIR="$HOME/$BASENAME"
  [[ -d "$CAP_DIR" ]] || CAP_DIR="$(find "$HOME" -maxdepth 1 -type d -name 'system-capture-*' -newer "$TARBALL" -print -quit || true)"
  say "Capture folder: ${CAP_DIR:-<not found>}"
fi

# ---- Reinstall APT packages ----
if [[ -f "$LISTFILE" ]]; then
  say "Reinstalling APT packages from $LISTFILE"
  sudo apt update
  xargs -r -a <(grep -Ev '^\s*#|^\s*$' "$LISTFILE") sudo apt install -y
else
  warn "Package list not found: $LISTFILE (skip APT reinstall)"
fi

# ---- Restore snaps ----
if [[ -n "${CAP_DIR:-}" && -f "$CAP_DIR/snap-list.txt" ]]; then
  say "Restoring snaps (best-effort)"
  sudo apt install -y snapd || true
  awk 'NR>1 {print $1}' "$CAP_DIR/snap-list.txt" | while read -r s; do
    [[ -n "$s" ]] || continue
    echo "  -> snap install $s"
    sudo snap install "$s" || true
  done
  warn "Some snaps (e.g., code) may need --classic; reinstall manually if needed."
fi

# ---- Restore flatpaks ----
if [[ -n "${CAP_DIR:-}" && -f "$CAP_DIR/flatpak-list.txt" ]]; then
  say "Restoring flatpaks"
  sudo apt install -y flatpak || true
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  awk -F'\t' 'NF>=3 {print $2 "|" $3}' "$CAP_DIR/flatpak-list.txt" \
    | while IFS='|' read -r ref origin; do
        [[ -n "$ref" && -n "$origin" ]] || continue
        echo "  -> flatpak install -y $origin $ref"
        flatpak install -y "$origin" "$ref" || true
      done
fi

# ---- Restore pipx ----
if [[ -n "${CAP_DIR:-}" && -f "$CAP_DIR/pipx-list.txt" ]]; then
  say "Restoring pipx packages"
  sudo apt install -y pipx || true
  awk '/^package / {print $2}' "$CAP_DIR/pipx-list.txt" | while read -r pkg; do
    [[ -n "$pkg" ]] || continue
    echo "  -> pipx install $pkg"
    pipx install "$pkg" || true
  done
fi

# ---- Restore npm globals ----
if [[ -n "${CAP_DIR:-}" && -f "$CAP_DIR/npm-global.txt" && "$(command -v npm || true)" ]]; then
  say "Restoring global npm packages"
  grep -E '├──|└──' "$CAP_DIR/npm-global.txt" \
    | sed -E 's/.* (.+)@.*/\1/' \
    | while read -r mod; do
        [[ -n "$mod" ]] || continue
        echo "  -> npm -g install $mod"
        npm -g install "$mod" || true
      done
else
  warn "npm not found or npm-global.txt missing; skip npm globals"
fi

say "Restore complete. Reboot recommended if you reinstall GPU drivers next (then run: nvidia-smi)."
