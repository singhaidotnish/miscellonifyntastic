#!/usr/bin/env bash
set -euo pipefail

OUTDIR="./manifests"
mkdir -p "$OUTDIR"

echo "Export started: $(date)"

# 1) distro / package manager detection
detect_pkg_mgr() {
  if command -v apt >/dev/null 2>&1; then echo "apt"; return; fi
  if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
  if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
  if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
  echo "unknown"
}
PKG_MGR=$(detect_pkg_mgr)
echo "Detected package manager: $PKG_MGR" > "$OUTDIR/distro-info.txt"
lsb_release -a 2>/dev/null >> "$OUTDIR/distro-info.txt" || true
uname -a >> "$OUTDIR/distro-info.txt"

# 2) APT / dpkg packages (Ubuntu/Debian)
if [ "$PKG_MGR" = "apt" ]; then
  echo "Exporting dpkg package list..."
  # only package names
  dpkg-query -f '${binary:Package}\n' -W | sort -u > "$OUTDIR/apt-packages.txt"
fi

# 3) DNF (Fedora) / dnf list --installed
if [ "$PKG_MGR" = "dnf" ]; then
  echo "Exporting dnf package list..."
  dnf repoquery --installed --qf '%{name}' | sort -u > "$OUTDIR/dnf-packages.txt"
fi

# 4) pacman (Arch)
if [ "$PKG_MGR" = "pacman" ]; then
  echo "Exporting pacman package list..."
  pacman -Qq > "$OUTDIR/pacman-packages.txt"
fi

# 5) snap
if command -v snap >/dev/null 2>&1; then
  echo "Exporting snap list..."
  # skip header
  snap list | awk 'NR>1 {print $1}' | sort -u > "$OUTDIR/snap-packages.txt"
fi

# 6) flatpak
if command -v flatpak >/dev/null 2>&1; then
  echo "Exporting flatpak apps..."
  flatpak list --app --columns=application 2>/dev/null | sort -u > "$OUTDIR/flatpak-apps.txt"
fi

# 7) pip (user and system)
if command -v pip3 >/dev/null 2>&1; then
  echo "Exporting pip3 packages..."
  pip3 freeze --all > "$OUTDIR/pip-packages.txt" || pip3 freeze > "$OUTDIR/pip-packages.txt"
fi

# 8) npm global
if command -v npm >/dev/null 2>&1; then
  echo "Exporting npm global packages..."
  # simpler parse (will list package@version)
  npm -g ls --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -n1 basename | sed 's/@.*$//' | sort -u > "$OUTDIR/npm-global-packages.txt" || true
fi

# 9) cargo (Rust) global tools
if command -v cargo >/dev/null 2>&1; then
  echo "Exporting cargo installed bins..."
  cargo install --list 2>/dev/null | awk '/^ /{print $1}' | sed 's/://g' | sort -u > "$OUTDIR/cargo-packages.txt" || true
fi

# 10) brew (macOS Homebrew)
if command -v brew >/dev/null 2>&1; then
  echo "Exporting brew and brew cask..."
  brew list > "$OUTDIR/brew-packages.txt" || true
  brew list --cask > "$OUTDIR/brew-cask-packages.txt" || true
fi

# 11) GUI .desktop files (apps shown in menus)
echo "Exporting GUI .desktop entries (Name and Exec) ... "
DESKTOP_DIRS=("/usr/share/applications" "$HOME/.local/share/applications")
> "$OUTDIR/desktop-apps.txt"
for d in "${DESKTOP_DIRS[@]}"; do
  if [ -d "$d" ]; then
    grep -HRn "^Name=" "$d" 2>/dev/null | sed 's/.*Name=//' >> "$OUTDIR/desktop-apps.txt" || true
  fi
done
sort -u "$OUTDIR/desktop-apps.txt" -o "$OUTDIR/desktop-apps.txt" || true

# 12) /opt and /usr/local installs (manual installs)
echo "Listing /opt and /usr/local contents..."
ls -1 /opt 2>/dev/null | sort -u > "$OUTDIR/opt-list.txt" || true
ls -1 /usr/local 2>/dev/null | sort -u > "$OUTDIR/usr-local-list.txt" || true

# 13) AppImages (search common folders)
echo "Searching for AppImages in ~/Downloads and /opt .."
find "$HOME/Downloads" /opt -maxdepth 2 -type f -iname '*.AppImage' -print 2>/dev/null | sort -u > "$OUTDIR/appimages.txt" || true

# 14) System snaps & flatpaks metadata (versions)
if [ -f "$OUTDIR/snap-packages.txt" ]; then
  while read -r s; do
    snap info "$s" 2>/dev/null | awk -v pkg="$s" '/installed:/{print pkg" " $0; exit}'
  done < "$OUTDIR/snap-packages.txt" > "$OUTDIR/snap-packages-with-versions.txt" || true
fi

# 15) Add a small README for the manifests
cat > "$OUTDIR/README" <<EOF
Manifests exported on: $(date)
Files:
 - apt-packages.txt        (apt/dpkg package names)           (if present)
 - dnf-packages.txt        (dnf package names)               (if present)
 - pacman-packages.txt     (pacman package names)            (if present)
 - snap-packages.txt       (snap names)
 - flatpak-apps.txt        (flatpak app ids)
 - pip-packages.txt        (pip freeze output)
 - npm-global-packages.txt (npm global packages)
 - cargo-packages.txt      (cargo installed bins)
 - brew-packages.txt       (homebrew packages - mac)
 - desktop-apps.txt        (GUI apps names from .desktop files)
 - opt-list.txt            (contents of /opt)
 - usr-local-list.txt      (contents of /usr/local)
 - appimages.txt           (found AppImages)
Review these files before using the installer script.
EOF

# 16) OPTIONALLY: call user's manage-packages.sh (if you want to integrate it)
# If the user provided a manage-packages.sh in the same dir, source or call it and append output
if [ -x "./manage-packages.sh" ]; then
  echo "Calling local ./manage-packages.sh to collect custom package list..."
  # expected: manage-packages.sh prints package list lines or writes to stdout one-per-line
  ./manage-packages.sh > "$OUTDIR/custom-manage-packages.txt" || true
fi

echo "Export finished. Manifests saved to $OUTDIR"
