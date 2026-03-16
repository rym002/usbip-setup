# USB/IP Client

Attaches remote USB devices from a USB/IP host over the network using systemd template units.

## Architecture

```
usbip-discover@<host>:<port>    ← one per remote host
        │
        ├── usbip-client@<host>:<port>_<busid>    ← one per device
        ├── usbip-client@<host>:<port>_<busid>
        └── usbip-client@<host>:<port>_<busid>
```

## Requirements

- Debian/Ubuntu based system
- `usbip` and `usbutils` packages
- `vhci-hcd` kernel module
- A running USB/IP host on the network

## Installation

```bash
chmod +x install.sh
sudo ./install.sh
```

## Usage

### Add a Host

```bash
systemctl enable --now usbip-discover@192.168.6.239:3240
```

### Remove a Host

```bash
systemctl disable --now usbip-discover@192.168.6.239:3240
```

### Rediscover Devices

```bash
systemctl restart usbip-discover@192.168.6.239:3240
```

### Manually Attach a Device

```bash
systemctl start usbip-client@192.168.6.239:3240_1-1.5
```

### Manually Detach a Device

```bash
systemctl stop usbip-client@192.168.6.239:3240_1-1.5
```

## Monitoring

```bash
# List all hosts
systemctl list-units 'usbip-discover@*'

# List all attached devices
systemctl list-units 'usbip-client@*'

# Check a specific host
systemctl status usbip-discover@192.168.6.239:3240

# Check a specific device
systemctl status usbip-client@192.168.6.239:3240_1-1.5

# Follow host logs
journalctl -u 'usbip-discover@*' -f

# Follow device logs
journalctl -u 'usbip-client@*' -f

# Follow all usbip logs
journalctl -u 'usbip-discover@*' -u 'usbip-client@*' -f
```

## Instance Naming

| Unit | Format | Example |
|---|---|---|
| Discovery | `usbip-discover@<host>:<port>` | `usbip-discover@192.168.6.239:3240` |
| Client | `usbip-client@<host>:<port>_<busid>` | `usbip-client@192.168.6.239:3240_1-1.5` |

## Files

| File | Purpose |
|---|---|
| `etc/systemd/system/usbip-discover@.service` | discovers and manages devices per host |
| `etc/systemd/system/usbip-client@.service` | attaches and detaches a single device |
| `etc/modules-load.d/usbip-client` | loads vhci-hcd module on boot |
| `install.sh` | installs files and verifies units |

## Troubleshooting

```bash
# Check for failed units
systemctl list-units 'usbip-*' --state=failed

# Reset failed units
systemctl reset-failed 'usbip-discover@*'
systemctl reset-failed 'usbip-client@*'

# Check host is reachable
usbip list -r <host>

# Check attached devices
usbip port

# Verify unit files
systemd-analyze verify /etc/systemd/system/usbip-discover@.service
systemd-analyze verify /etc/systemd/system/usbip-client@.service
```
