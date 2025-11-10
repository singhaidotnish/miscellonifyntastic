#!/usr/bin/env python3
"""
Smart Package Installer - Automatically installs apps with dependencies
Usage: sudo python3 smart_installer.py [config_file]
"""

import subprocess
import sys
import os
import json
from pathlib import Path

class SmartInstaller:
    def __init__(self):
        self.installed = []
        self.failed = []
        self.skipped = []
        
        # Define how to install popular apps
        self.app_recipes = {
            "docker": {
                "name": "Docker",
                "commands": [
                    "apt-get update",
                    "apt-get install -y ca-certificates curl gnupg",
                    "install -m 0755 -d /etc/apt/keyrings",
                    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
                    "chmod a+r /etc/apt/keyrings/docker.gpg",
                    'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null',
                    "apt-get update",
                    "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
                ]
            },
            "chrome": {
                "name": "Google Chrome",
                "commands": [
                    "wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
                    "apt-get install -y /tmp/google-chrome.deb",
                    "rm /tmp/google-chrome.deb"
                ]
            },
            "vscode": {
                "name": "Visual Studio Code",
                "commands": [
                    "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg",
                    "install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg",
                    'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null',
                    "apt-get update",
                    "apt-get install -y code"
                ]
            },
            "brave": {
                "name": "Brave Browser",
                "commands": [
                    "apt-get install -y curl",
                    "curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg",
                    'echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list',
                    "apt-get update",
                    "apt-get install -y brave-browser"
                ]
            },
            "nodejs": {
                "name": "Node.js (LTS)",
                "commands": [
                    "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -",
                    "apt-get install -y nodejs"
                ]
            },
            "github-cli": {
                "name": "GitHub CLI",
                "commands": [
                    "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg",
                    'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null',
                    "apt-get update",
                    "apt-get install -y gh"
                ]
            },
            "github-desktop": {
                "name": "GitHub Desktop",
                "commands": [
                    "wget -qO /tmp/github-desktop.deb https://github.com/shiftkey/desktop/releases/download/release-3.4.3-linux1/GitHubDesktop-linux-amd64-3.4.3-linux1.deb",
                    "apt-get install -y /tmp/github-desktop.deb",
                    "rm /tmp/github-desktop.deb"
                ]
            },
            # Standard apt packages - simplified format
            "git": {"name": "Git", "apt": "git"},
            "python3-pip": {"name": "Python3 Pip", "apt": "python3-pip"},
            "build-essential": {"name": "Build Essential", "apt": "build-essential"},
            "curl": {"name": "cURL", "apt": "curl"},
            "wget": {"name": "Wget", "apt": "wget"},
            "vim": {"name": "Vim", "apt": "vim"},
            "htop": {"name": "Htop", "apt": "htop"},
            "neofetch": {"name": "Neofetch", "apt": "neofetch"},
            "tree": {"name": "Tree", "apt": "tree"},
            "tmux": {"name": "Tmux", "apt": "tmux"},
            "vlc": {"name": "VLC Media Player", "apt": "vlc"},
            "gimp": {"name": "GIMP", "apt": "gimp"},
            "inkscape": {"name": "Inkscape", "apt": "inkscape"},
            "obs-studio": {"name": "OBS Studio", "apt": "obs-studio"},
            "ffmpeg": {"name": "FFmpeg", "apt": "ffmpeg"},
            "discord": {"name": "Discord", "apt": "discord"},
            "telegram": {"name": "Telegram", "apt": "telegram-desktop"},
            "slack": {"name": "Slack", "apt": "slack-desktop"},
            "spotify": {"name": "Spotify", "apt": "spotify-client"},
            "firefox": {"name": "Firefox Browser", "apt": "firefox"},
            "kolourpaint": {"name": "KolourPaint", "apt": "kolourpaint"},
            "krita": {"name": "Krita", "apt": "krita"},
            "blender": {"name": "Blender 3D", "apt": "blender"},
            "audacity": {"name": "Audacity", "apt": "audacity"},
            "kdenlive": {"name": "Kdenlive Video Editor", "apt": "kdenlive"},
            "flameshot": {"name": "Flameshot Screenshot", "apt": "flameshot"},
            "gparted": {"name": "GParted", "apt": "gparted"},
            "synaptic": {"name": "Synaptic Package Manager", "apt": "synaptic"},
            "dconf-editor": {"name": "Dconf Editor", "apt": "dconf-editor"},
            "gnome-tweaks": {"name": "GNOME Tweaks", "apt": "gnome-tweaks"},
            "timeshift": {"name": "Timeshift Backup", "apt": "timeshift"},
            "bleachbit": {"name": "BleachBit Cleaner", "apt": "bleachbit"},
            "net-tools": {"name": "Network Tools", "apt": "net-tools"},
            "nmap": {"name": "Nmap", "apt": "nmap"},
            "openssh-server": {"name": "OpenSSH Server", "apt": "openssh-server"},
            "ufw": {"name": "UFW Firewall", "apt": "ufw"},
            "gnupg": {"name": "GnuPG", "apt": "gnupg"},
            "keepassxc": {"name": "KeePassXC", "apt": "keepassxc"},
            "7zip": {"name": "7-Zip", "apt": "p7zip-full"},
            "unrar": {"name": "Unrar", "apt": "unrar"},
            "ncdu": {"name": "NCurses Disk Usage", "apt": "ncdu"},
            "bat": {"name": "Bat (better cat)", "apt": "batcat"},
            "fzf": {"name": "Fuzzy Finder", "apt": "fzf"},
            "ripgrep": {"name": "Ripgrep", "apt": "ripgrep"},
            "fd": {"name": "fd (better find)", "apt": "fd-find"},
            "zsh": {"name": "Zsh Shell", "apt": "zsh"},
            "fonts-firacode": {"name": "Fira Code Font", "apt": "fonts-firacode"},
            "fonts-noto": {"name": "Noto Fonts", "apt": "fonts-noto"},
            "davinci-resolve": {
                "name": "DaVinci Resolve (Docker)",
                "commands": [
                    "echo '⚠️  DaVinci Resolve Docker setup requires manual configuration'",
                    "echo '   1. Ensure Docker is installed first'",
                    "echo '   2. DaVinci Resolve requires specific GPU setup'",
                    "echo '   3. Recommended: Use https://github.com/fat-tire/resolve-docker'",
                    "echo '   4. Or install native .deb from BlackmagicDesign website'",
                    "echo ''",
                    "echo '   Skipping automated Docker pull - requires GPU passthrough setup'",
                ]
            },
        }

    def run_command(self, cmd):
        """Execute shell command and return success status"""
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            return True, result.stdout
        except subprocess.CalledProcessError as e:
            return False, e.stderr

    def check_root(self):
        """Check if running as root"""
        if os.geteuid() != 0:
            print("❌ This script must be run as root (use sudo)")
            sys.exit(1)

    def is_installed(self, package_name):
        """Check if package is already installed"""
        cmd = f"dpkg -l | grep -q '^ii.*{package_name}'"
        success, _ = self.run_command(cmd)
        return success

    def install_app(self, app_key):
        """Install an app based on its recipe"""
        if app_key not in self.app_recipes:
            print(f"⚠️  Unknown app: {app_key}")
            self.failed.append(app_key)
            return False

        recipe = self.app_recipes[app_key]
        app_name = recipe["name"]
        
        print(f"\n📦 Installing {app_name}...")

        # Simple apt package
        if "apt" in recipe:
            pkg = recipe["apt"]
            if self.is_installed(pkg):
                print(f"✓ {app_name} already installed")
                self.skipped.append(app_name)
                return True
            
            success, output = self.run_command(f"apt-get install -y {pkg}")
            if success:
                print(f"✓ {app_name} installed successfully")
                self.installed.append(app_name)
                return True
            else:
                print(f"✗ Failed to install {app_name}")
                print(f"  Error: {output}")
                self.failed.append(app_name)
                return False

        # Complex installation with multiple commands
        if "commands" in recipe:
            for i, cmd in enumerate(recipe["commands"], 1):
                print(f"  Step {i}/{len(recipe['commands'])}: {cmd[:60]}...")
                success, output = self.run_command(cmd)
                if not success:
                    print(f"✗ Failed at step {i}")
                    print(f"  Error: {output}")
                    self.failed.append(app_name)
                    return False
            
            print(f"✓ {app_name} installed successfully")
            self.installed.append(app_name)
            return True

        return False

    def load_config(self, config_file):
        """Load apps list from config file"""
        try:
            with open(config_file, 'r') as f:
                # Support both JSON and simple text format
                content = f.read().strip()
                
                # Try JSON first
                try:
                    data = json.loads(content)
                    if isinstance(data, dict) and "apps" in data:
                        return data["apps"]
                    elif isinstance(data, list):
                        return data
                except json.JSONDecodeError:
                    pass
                
                # Fallback to simple text format (one app per line)
                apps = []
                for line in content.split('\n'):
                    line = line.strip()
                    if line and not line.startswith('#'):
                        apps.append(line)
                return apps
        except FileNotFoundError:
            print(f"❌ Config file not found: {config_file}")
            sys.exit(1)

    def update_system(self):
        """Update package lists"""
        print("🔄 Updating package lists...")
        success, _ = self.run_command("apt-get update")
        if not success:
            print("⚠️  Failed to update package lists")
        else:
            print("✓ Package lists updated")

    def print_summary(self):
        """Print installation summary"""
        print("\n" + "="*60)
        print("📊 INSTALLATION SUMMARY")
        print("="*60)
        
        if self.installed:
            print(f"\n✓ Successfully installed ({len(self.installed)}):")
            for app in self.installed:
                print(f"  • {app}")
        
        if self.skipped:
            print(f"\n⊙ Already installed ({len(self.skipped)}):")
            for app in self.skipped:
                print(f"  • {app}")
        
        if self.failed:
            print(f"\n✗ Failed to install ({len(self.failed)}):")
            for app in self.failed:
                print(f"  • {app}")
        
        print("\n" + "="*60)

def create_sample_config():
    """Create a sample config file"""
    sample_config = """# Smart Installer Configuration
# List one app per line. Lines starting with # are ignored.

# Development Tools
git
python3-pip
build-essential
vscode
docker
nodejs
github-cli

# Browsers
chrome
brave

# Media & Graphics
vlc
gimp
ffmpeg

# Utilities
htop
neofetch
tree
tmux
"""
    
    config_file = "apps.txt"
    if not os.path.exists(config_file):
        with open(config_file, 'w') as f:
            f.write(sample_config)
        print(f"✓ Created sample config: {config_file}")
        print(f"  Edit this file and run: sudo python3 {sys.argv[0]} {config_file}")
        return True
    return False

def main():
    installer = SmartInstaller()
    
    # Check for root
    installer.check_root()
    
    # Get config file
    if len(sys.argv) < 2:
        if create_sample_config():
            sys.exit(0)
        config_file = "apps.txt"
    else:
        config_file = sys.argv[1]
    
    print("🚀 Smart Package Installer")
    print(f"📄 Loading config from: {config_file}\n")
    
    # Load apps list
    apps = installer.load_config(config_file)
    print(f"Found {len(apps)} apps to install\n")
    
    # Update system
    installer.update_system()
    
    # Install each app
    for app in apps:
        installer.install_app(app.strip())
    
    # Print summary
    installer.print_summary()

if __name__ == "__main__":
    main()
