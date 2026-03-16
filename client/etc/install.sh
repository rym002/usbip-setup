#!/bin/bash
# USB/IP Client Install Script
# Dynamically installs all files matching the repo structure

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG() { echo "[usbip-client-install] $*"; }

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Dynamically install all files from repo to /
LOG "Installing files..."
find "$REPO_DIR/etc" -type f | while read -r src; do
    dst="/${src#$REPO_DIR/}"
    mode="644"

    case "$dst" in
        /usr/local/bin/*) mode="755" ;;
    esac

    if [ -f "$dst" ]; then
        LOG "Backing up $dst -> $dst.bak"
        cp "$dst" "$dst.bak"
    fi

    mkdir -p "$(dirname "$dst")"
    LOG "Installing $dst"
    install -m "$mode" "$src" "$dst"
done

# Reload systemd
LOG "Reloading systemd..."
systemctl daemon-reload
# Dynamically verify all installed units
LOG "Verifying units..."
find "$REPO_DIR/etc/systemd/system" -type f -name "*.service" 2>/dev/null | while read -r unit; do
    name="$(basename "$unit")"
    LOG "Verifying $name..."
    systemd-analyze verify "/etc/systemd/system/$name" || {
        LOG "Verification failed for $name"
        exit 1
    }
done

LOG "Install complete"
LOG "  Add a host: systemctl enable --now usbip-discover@<host>:<port>"
LOG "  List hosts: systemctl list-units usbip-discover@*"
LOG "  List devices: systemctl list-units usbip-client@*"
LOG "  Logs: journalctl -u usbip-discover@* -f"