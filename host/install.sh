#!/bin/bash
# USB/IP Host Install Script
# Dynamically installs all files matching the /etc structure in the repo

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG() { echo "[usbip-install] $*"; }

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Install dependencies
LOG "Installing dependencies..."
apt update -qq
apt install -y usbip usbutils

# Dynamically install all files from repo etc/ to /etc/
LOG "Installing files..."
find "$REPO_DIR/etc" -type f | while read -r src; do
    # Derive destination path by stripping repo prefix
    dst="/${src#$REPO_DIR/}"
    mode="644"

    # Executable files
    case "$dst" in
        /usr/local/bin/*) mode="755" ;;
    esac

    # Backup existing
    if [ -f "$dst" ]; then
        LOG "Backing up $dst -> $dst.bak"
        cp "$dst" "$dst.bak"
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$dst")"

    LOG "Installing $dst"
    install -m "$mode" "$src" "$dst"
done

# Reload udev rules
LOG "Reloading udev rules..."
udevadm control --reload-rules

# Enable and start any installed systemd units
LOG "Enabling systemd units..."
systemctl daemon-reload
find "$REPO_DIR/etc/systemd/system" -type f -name "*.service" 2>/dev/null | while read -r unit; do
    name="$(basename "$unit")"
    # Skip template units - enable manually per instance
    if [[ "$name" == *@* ]]; then
        LOG "Skipping template unit $name (enable manually per instance)"
        continue
    fi
    LOG "Enabling $name..."
    systemctl enable "$name"
    systemctl restart "$name"
done

# Verify services
LOG "Verifying services..."
find "$REPO_DIR/etc/systemd/system" -type f -name "*.service" 2>/dev/null | while read -r unit; do
    name="$(basename "$unit")"
    [[ "$name" == *@* ]] && continue
    if systemctl is-active --quiet "$name"; then
        LOG "$name is running ✓"
    else
        LOG "$name failed to start ✗"
        journalctl -u "$name" -n 20
        exit 1
    fi
done

# Show bound devices
LOG "Bound devices:"
usbip list -l

LOG "Install complete"
LOG "  Edit /etc/udev/rules.d/89-usbip-devices.rules to add devices"
LOG "  Edit /etc/default/usbipd to configure port and IP version"
LOG "  Run: journalctl -u usbipd -f to monitor"
