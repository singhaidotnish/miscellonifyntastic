#!/usr/bin/env bash
# manage_packages.sh
# Reproducible apt package list manager with distro "flavor" presets.
# Commands:
#   capture   <LISTFILE>
#   reinstall <LISTFILE>
#   diff      <LISTFILE>
#   add       <LISTFILE> pkgs...
#   remove    <LISTFILE> pkgs...
#   list      <LISTFILE>
#   dedupe    <LISTFILE>
#   verify    <LISTFILE>
#
# Global options (must appear before the command):
#   --flavor {auto|xubuntu|ubuntu|kde|server|minimal|none}
#   --show-flavors
#
# Examples:
#   ./manage_packages.sh --flavor xubuntu capture my.txt
#   ./manage_packages.sh --flavor auto diff my.txt
#   ./manage_packages.sh reinstall my.txt   # (flavor defaults to auto)

set -euo pipefail

# ---------- helpers ----------
die() { echo "Error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

APT=apt; command -v apt >/dev/null 2>&1 || APT=apt-get

normalize_list() { grep -Ev '^\s*#|^\s*$' | sort -u; }
ensure_listfile() { local f=${1:-}; [[ -n "$f" ]] || die "No list file"; [[ -f "$f" ]] || touch "$f"; }

# ---------- flavor presets ----------
show_flavors() {
  cat <<EOF
Available flavors:
  auto     - Detects from installed meta-packages (default)
  xubuntu  - XFCE/Xubuntu workstation (excludes xubuntu-desktop, xfce4-goodies, snapd, etc.)
  ubuntu   - Ubuntu GNOME workstation (excludes ubuntu-desktop, gnome-shell, snapd, etc.)
  kde      - Kubuntu/Plasma workstation (excludes kubuntu-desktop, plasma-desktop, snapd, etc.)
  server   - Headless/server-y base (keeps it lean)
  minimal  - Aggressive base-only exclusion; you curate almost everything
  none     - No exclusions (captures every manual package)
EOF
}

# Base things we almost always exclude
EXC_BASE='(^adduser$|^apt$|^aptitude$|^base-files$|^bash$|^bsdutils$|^coreutils$|^dash$|^debconf$|^debianutils$|^dpkg$|^e2fsprogs$|^findutils$|^gcc-\d+|^gnupg$|^grep$|^gzip$|^hostname$|^init$|^login$|^mount$|^passwd$|^sed$|^systemd|^tar$|^tzdata$)'

preset_regex() {
  case "$1" in
    xubuntu)
      echo "$EXC_BASE|^(ubuntu-minimal|ubuntu-standard|xubuntu-desktop|xubuntu-core|xfce4|xfce4-goodies|lightdm|plymouth|update-manager|update-notifier|whoopsie|apport|snapd)$"
      ;;
    ubuntu)
      echo "$EXC_BASE|^(ubuntu-minimal|ubuntu-standard|ubuntu-desktop|gnome-shell|gdm3|plymouth|update-manager|update-notifier|whoopsie|apport|snapd)$"
      ;;
    kde)
      echo "$EXC_BASE|^(ubuntu-minimal|ubuntu-standard|kubuntu-desktop|plasma-desktop|sddm|plymouth|discover|whoopsie|apport|snapd)$"
      ;;
    server)
      echo "$EXC_BASE|^(ubuntu-minimal|ubuntu-standard|cloud-init|snapd)$"
      ;;
    minimal)
      # very lean; you’ll add what you truly want back in your list
      echo "$EXC_BASE|^(ubuntu-minimal|ubuntu-standard|xubuntu-desktop|xubuntu-core|ubuntu-desktop|kubuntu-desktop|plasma-desktop|xfce4|xfce4-goodies|gnome-shell|gdm3|sddm|lightdm|plymouth|update-manager|update-notifier|whoopsie|apport|snapd|printer-driver-.*|cups|avahi-daemon)$"
      ;;
    none)
      echo "^$"  # match nothing = exclude nothing
      ;;
    *)
      die "Unknown flavor preset: $1"
      ;;
  esac
}

detect_flavor() {
  # dpkg-based quick sniff
  if dpkg -l 2>/dev/null | grep -q '^ii\s\+xubuntu-desktop\s'; then
    echo xubuntu; return
  fi
  if dpkg -l 2>/dev/null | grep -q '^ii\s\+ubuntu-desktop\s'; then
    echo ubuntu; return
  fi
  if dpkg -l 2>/dev/null | grep -Eq '^ii\s+(kubuntu-desktop|plasma-desktop)\s'; then
    echo kde; return
  fi
  # fallback: check desktop env var (best-effort)
  case "${XDG_CURRENT_DESKTOP:-}" in
    *XFCE*) echo xubuntu; return;;
    *GNOME*) echo ubuntu; return;;
    *KDE*|*PLASMA*) echo kde; return;;
  esac
  echo server
}

FLAVOR=auto
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --flavor)
      shift; [[ $# -gt 0 ]] || die "--flavor needs a value"
      FLAVOR="$1"; shift;;
    --show-flavors)
      show_flavors; exit 0;;
    -*)
      die "Unknown global option: $1 (try --show-flavors)";;
    *)
      break;;
  esac
done

[[ "$FLAVOR" == "auto" ]] && FLAVOR="$(detect_flavor)"
EXCLUDE_REGEX="$(preset_regex "$FLAVOR")"

# ---------- commands ----------
cmd_capture() {
  local out="${1:-my-packages.txt}"
  need apt-mark
  echo "[*] Flavor: $FLAVOR"
  echo "[*] Exporting manually-installed packages..."
  local a f; a=$(mktemp); f=$(mktemp)
  apt-mark showmanual | sort > "$a"
  grep -Ev "$EXCLUDE_REGEX" "$a" > "$f" || true
  echo "[*] Writing package list to $out"
  cp "$f" "$out"
  echo "[*] Done. Review and trim $out as needed."
}

cmd_reinstall() {
  local list="${1:-my-packages.txt}"
  [[ -f "$list" ]] || die "List file not found: $list"
  echo "[*] Updating package index..."
  sudo "$APT" update
  echo "[*] Installing packages from $list ..."
  xargs -r -a <(normalize_list < "$list") sudo "$APT" install -y
  echo "[*] Done."
}

cmd_diff() {
  local list="${1:-my-packages.txt}"
  [[ -f "$list" ]] || die "List file not found: $list"
  local a f; a=$(mktemp); f=$(mktemp)
  apt-mark showmanual | sort > "$a"
  grep -Ev "$EXCLUDE_REGEX" "$a" > "$f" || true
  echo "[*] Flavor: $FLAVOR (showing diff: saved vs current manual)"
  diff -u "$list" "$f" || true
}

cmd_add() {
  local list="${1:-my-packages.txt}"; shift || true
  ensure_listfile "$list"
  [[ $# -ge 1 ]] || die "Usage: add LISTFILE pkg1 [pkg2 ...]"
  printf "%s\n" "$@" >> "$list"
  normalize_list < "$list" > "$list.tmp" && mv "$list.tmp" "$list"
  echo "[+] Added: $* → $list"
}

cmd_remove() {
  local list="${1:-my-packages.txt}"; shift || true
  ensure_listfile "$list"
  [[ $# -ge 1 ]] || die "Usage: remove LISTFILE pkg1 [pkg2 ...]"
  local tmp_pkgs tmp_keep tmp_comments
  tmp_pkgs=$(mktemp); tmp_keep=$(mktemp); tmp_comments=$(mktemp)
  grep -E '^\s*#|^\s*$' "$list" > "$tmp_comments" || true
  normalize_list < "$list" > "$tmp_pkgs"
  printf "%s\n" "$@" | sort -u > "$tmp_keep.remove"
  comm -23 "$tmp_pkgs" "$tmp_keep.remove" > "$tmp_keep"
  { cat "$tmp_comments"; cat "$tmp_keep"; } > "$list"
  echo "[-] Removed: $* from $list"
}

cmd_list() {
  local list="${1:-my-packages.txt}"
  [[ -f "$list" ]] || die "List file not found: $list"
  echo "[*] Packages in $list:"
  normalize_list < "$list" | nl -ba
}

cmd_dedupe() {
  local list="${1:-my-packages.txt}"
  [[ -f "$list" ]] || die "List file not found: $list"
  local c p; c=$(mktemp); p=$(mktemp)
  grep -E '^\s*#|^\s*$' "$list" > "$c" || true
  normalize_list < "$list" > "$p"
  { cat "$c"; cat "$p"; } > "$list"
  echo "[*] Deduped and cleaned $list"
}

cmd_verify() {
  local list="${1:-my-packages.txt}"
  [[ -f "$list" ]] || die "List file not found: $list"
  need apt-cache
  local ok=0 fail=0
  while read -r p; do
    [[ -z "$p" ]] && continue
    if apt-cache show "$p" >/dev/null 2>&1; then
      echo "[OK] $p"; ok=$((ok+1))
    else
      echo "[!!] Not found: $p" >&2; fail=$((fail+1))
    fi
  done < <(normalize_list < "$list")
  echo "[*] Verify summary: OK=$ok, Missing=$fail"
  [[ $fail -eq 0 ]]
}

usage() {
  cat <<EOF
Usage: $0 [--flavor {auto|xubuntu|ubuntu|kde|server|minimal|none}] <command> [args...]

Commands:
  capture   <LISTFILE>        Export current manually-installed packages (filtered by flavor) to LISTFILE
  reinstall <LISTFILE>        Install packages from LISTFILE (ignores comments/blanks)
  diff      <LISTFILE>        Show diff between LISTFILE and current manual packages
  add       <LISTFILE> pkgs.. Append packages to LISTFILE and dedupe
  remove    <LISTFILE> pkgs.. Remove packages from LISTFILE (keeps comments)
  list      <LISTFILE>        Show normalized, deduped package names with line numbers
  dedupe    <LISTFILE>        Normalize + dedupe LISTFILE (preserve comments)
  verify    <LISTFILE>        Check if each package in LISTFILE exists in apt cache

Global:
  --flavor auto|xubuntu|ubuntu|kde|server|minimal|none   (default: auto)
  --show-flavors

Tip: Use '--flavor none' if you want to capture literally everything apt-mark considers manual.
EOF
}

main() {
  local cmd="${1:-}"; shift || true
  case "${cmd:-}" in
    capture)   cmd_capture "$@";;
    reinstall) cmd_reinstall "$@";;
    diff)      cmd_diff "$@";;
    add)       cmd_add "$@";;
    remove)    cmd_remove "$@";;
    list)      cmd_list "$@";;
    dedupe)    cmd_dedupe "$@";;
    verify)    cmd_verify "$@";;
    ""|help|-h|--help) usage;;
    *) die "Unknown command: $cmd (try: $0 --show-flavors)";;
  esac
}

main "$@"
