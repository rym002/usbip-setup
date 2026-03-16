# USB/IP Host

Exports USB devices over the network using a Raspberry Pi as the device host. Remote clients can attach and use the devices as if they were locally connected.

## Architecture

```
[USB Devices] → [Raspberry Pi USB ports]
                        │
                        ▼
                  usbipd (daemon)
                        │
                        ▼
                udev detects device
                        │
                        ▼
              usbip-bind@<busid> (systemd)
                        │
                        ▼
                 device exported
                        │
                  network (TCP 3240)
                        │
                        ▼
                 remote clients
```

## Requirements

- Raspberry Pi (any model)
- Debian/Ubuntu based OS (DietPi or Raspberry Pi OS Lite recommended)
- `usbip` and `usbutils` packages

## Installation

```bash
chmod +x install.sh
sudo ./install.sh
```

## Configuration

### `/etc/default/usbipd`

```bash
# IP version binding: V4 | V6 | BOTH (default: BOTH)
# IP_VERSION=BOTH

# Port (default: 3240)
# PORT=3240
```

### Excluding Devices

Add devices to exclude from sharing in `/etc/udev/rules.d/89-usbip-devices.rules`:

```bash
# Format: ATTR{idVendor}=="xxxx", ATTR{idProduct}=="xxxx"
ACTION=="add", SUBSYSTEM=="usb", \
    ATTR{idVendor}=="0781", ATTR{idProduct}=="5583", \
    TAG+="usbip_exclude"
```

Find vendor and product IDs with:

```bash
lsusb
```

## Usage

### Start the Daemon

```bash
systemctl start usbipd
```

### List Exported Devices

```bash
usbip list -l
```

### Manually Bind a Device

```bash
systemctl start usbip-bind@1-1.5
```

### Manually Unbind a Device

```bash
systemctl stop usbip-bind@1-1.5
```

### Retrigger udev for Connected Devices

```bash
udevadm trigger --subsystem-match=usb --action=add
```

## Monitoring

```bash
# Check daemon status
systemctl status usbipd

# List all bound devices
systemctl list-units 'usbip-bind@*'

# Check a specific device
systemctl status usbip-bind@1-1.5

# Follow daemon logs
journalctl -u usbipd -f

# Follow bind logs
journalctl -u 'usbip-bind@*' -f

# Follow all usbip logs
journalctl -u usbipd -u 'usbip-bind@*' -f

# Check active connections from clients
ss -tnp | grep 3240
```

## Instance Naming

| Unit | Format | Example |
|---|---|---|
| Bind | `usbip-bind@<busid>` | `usbip-bind@1-1.5` |

Bus IDs can be found with:

```bash
usbip list -l
# or
ls /sys/bus/usb/devices/
```

## Files

| File | Purpose |
|---|---|
| `etc/systemd/system/usbipd.service` | USB/IP daemon |
| `etc/systemd/system/usbip-bind@.service` | binds and unbinds a single device |
| `etc/default/usbipd` | daemon configuration |
| `etc/udev/rules.d/89-usbip-devices.rules` | device exclusion tags |
| `etc/udev/rules.d/90-usbip-autobind.rules` | auto-bind rule |
| `etc/modules-load.d/usbip` | loads kernel modules on boot |
| `install.sh` | installs files and starts services |

## Troubleshooting

```bash
# Check daemon is running
systemctl status usbipd

# Check kernel modules are loaded
lsmod | grep usbip

# Check udev rules are loaded
udevadm control --reload-rules
udevadm test /sys/bus/usb/devices/1-1.5

# Check device bind status
cat /sys/bus/usb/drivers/usbip-host/*/usbip_status
# 0 = exported idle
# 1 = exported in use by client
# 2 = not exported

# Check for failed bind units
systemctl list-units 'usbip-bind@*' --state=failed

# Reset failed units
systemctl reset-failed 'usbip-bind@*'

# Check firewall
ufw status
ufw allow 3240/tcp

# Check active client connections
ss -tnp | grep 3240
```

## Notes

- All non-hub USB devices are shared by default
- Hubs (device class 09) are never exported
- Devices tagged `usbip_exclude` in `89-usbip-devices.rules` are skipped
- The daemon must be running before devices can be bound
- Devices are automatically rebound after daemon restart via `ExecStartPost`
