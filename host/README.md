# USBIP host setup
This will
* install udev rules to auto bind devices while allow exclusions
* install modules-load to load required modules on startup
* Install/enable a systemd service

## Installation
run `install.sh` to install files and start services.

## Dynamically bind all USB devices unless explicitly excluded
Devices can be excluded by adding the tag `usbip_exclude` via [udev](etc/udev/rules.d/89-usbip-devices.rules).
