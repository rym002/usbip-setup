# USB/IP over Network

Share USB devices over a network using a Raspberry Pi as the host and any Linux machine (including Proxmox) as the client. Remote clients attach devices as if they were locally connected.

## Overview

```
[USB Devices]
      │
      ▼
[Raspberry Pi]
  usbipd daemon
  usbip-bind@<busid>
      │
   TCP 3240
      │
      ▼
[Client Machine]
  usbip-discover@<host>:<port>
  usbip-client@<host>:<port>_<busid>
      │
      ▼
[Device appears local]
```

## Repository Structure

```
├── README.md
├── host/                           ← Raspberry Pi setup
│   ├── README.md
│   ├── install.sh
│   └── etc/
│       ├── default/
│       │   └── usbipd
│       ├── modules-load.d/
│       │   └── usbip
│       ├── systemd/system/
│       │   ├── usbipd.service
│       │   └── usbip-bind@.service
│       └── udev/rules.d/
│           ├── 89-usbip-devices.rules
│           └── 90-usbip-autobind.rules
└── client/                         ← Client machine setup
    ├── README.md
    ├── install.sh
    └── etc/
        ├── modules-load.d/
        │   └── usbip-client
        └── systemd/system/
            ├── usbip-discover@.service
            └── usbip-client@.service
```

## Quick Start

### 1. Set Up the Host (Raspberry Pi)

```bash
cd host/
chmod +x install.sh
sudo ./install.sh
```

Exclude any devices you don't want to share in:
```
/etc/udev/rules.d/89-usbip-devices.rules
```

### 2. Set Up the Client

```bash
cd client/
chmod +x install.sh
sudo ./install.sh
```

### 3. Connect

```bash
# On the client — add the Pi as a host
systemctl enable --now usbip-discover@<pi-ip>:3240

# Verify devices are attached
usbip port
```

## How It Works

### Host

| Component | Role |
|---|---|
| `usbipd.service` | daemon that serves USB devices over TCP 3240 |
| `usbip-bind@.service` | binds a single device for export |
| `90-usbip-autobind.rules` | triggers bind service when device is plugged in |
| `89-usbip-devices.rules` | tags devices to exclude from sharing |

### Client

| Component | Role |
|---|---|
| `usbip-discover@.service` | queries host and starts a client unit per device |
| `usbip-client@.service` | attaches and detaches a single remote device |

## Instance Naming

| Unit | Format | Example |
|---|---|---|
| Host bind | `usbip-bind@<busid>` | `usbip-bind@1-1.5` |
| Client discover | `usbip-discover@<host>:<port>` | `usbip-discover@192.168.1.100:3240` |
| Client device | `usbip-client@<host>:<port>_<busid>` | `usbip-client@192.168.1.100:3240_1-1.5` |

## Configuration

### Host — `/etc/default/usbipd`

```bash
# IP version: V4 | V6 | BOTH (default: BOTH)
# IP_VERSION=BOTH

# Port (default: 3240)
# PORT=3240
```

### Host — Excluding Devices

```bash
# /etc/udev/rules.d/89-usbip-devices.rules
ACTION=="add", SUBSYSTEM=="usb", \
    ATTR{idVendor}=="xxxx", ATTR{idProduct}=="xxxx", \
    TAG+="usbip_exclude"
```

Find vendor and product IDs with `lsusb`.

## Monitoring

### Host

```bash
# Daemon status
systemctl status usbipd

# Bound devices
systemctl list-units 'usbip-bind@*'

# Active client connections
ss -tnp | grep 3240

# Logs
journalctl -u usbipd -u 'usbip-bind@*' -f
```

### Client

```bash
# Discovery status
systemctl list-units 'usbip-discover@*'

# Attached devices
systemctl list-units 'usbip-client@*'

# Attached devices (kernel view)
usbip port

# Logs
journalctl -u 'usbip-discover@*' -u 'usbip-client@*' -f
```

## Troubleshooting

### Host unreachable from client

```bash
# Check daemon is running on Pi
systemctl status usbipd

# Check firewall
ufw status
ufw allow 3240/tcp

# Check from client
usbip list -r <pi-ip>
```

### Device not exported

```bash
# Check device is bound
usbip list -l

# Check udev fired
journalctl -u 'usbip-bind@*' -n 20

# Retrigger udev
udevadm trigger --subsystem-match=usb --action=add

# Check device is not excluded
udevadm test /sys/bus/usb/devices/<busid> 2>&1 | grep usbip
```

### Device not attaching on client

```bash
# Check vhci module is loaded
lsmod | grep vhci

# Check discovery ran
journalctl -u 'usbip-discover@*' -n 20

# Check client unit state
systemctl status 'usbip-client@*'

# Reset failed units
systemctl reset-failed 'usbip-client@*'
systemctl reset-failed 'usbip-discover@*'
```

### Kernel modules missing

```bash
# Host
modprobe usbip_core
modprobe usbip_host

# Client
modprobe vhci-hcd
```

## Requirements

### Host (Raspberry Pi)
- Raspberry Pi OS Lite or DietPi (Debian based)
- `usbip` and `usbutils` packages

### Client
- Debian/Ubuntu based OS
- `usbip` and `usbutils` packages
- `vhci-hcd` kernel module
- Network access to host on TCP 3240
