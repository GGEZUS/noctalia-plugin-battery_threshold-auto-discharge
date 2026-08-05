# noctalia-plugin-battery_threshold-auto-discharge

[![Noctalia](https://img.shields.io/badge/Noctalia-Shell-blue)](https://noctalia.dev/)
[![Arch Linux](https://img.shields.io/badge/Arch-Linux-blue)](https://archlinux.org/)

Automatic battery discharge helper for Linux laptops. Works with the [Noctalia Battery Threshold plugin](https://noctalia.dev/plugins/community/battery-threshold) to actively discharge your battery when it's above the set threshold while connected to AC power.

## About the Plugin

This helper is designed to work with the **Battery Threshold** plugin for Noctalia Shell by [Damian D'Souza](https://github.com/noctalia-dev/community-plugins/tree/main/battery-threshold) (plugin ID: `damian-ds7/battery-threshold`).

**Plugin page:** https://noctalia.dev/plugins/community/battery-threshold
**Plugin source:** https://github.com/noctalia-dev/community-plugins/tree/main/battery-threshold

> ℹ️ **Heads-up — plugin changed.** Earlier versions of this helper targeted a different battery-threshold plugin by Wilfred Mallawa. The current Noctalia plugin page ships `damian-ds7/battery-threshold` v1.0.1+, written in Luau. The helper still works with it (both read/write the same `charge_control_end_threshold` sysfs file), but the installation steps below have been updated for the new plugin's permission model.

**Plugin Features:**
- Bar widget showing current battery threshold
- Panel with slider to adjust threshold (40-100%)
- Persistent settings (`threshold.txt` in the plugin data dir) across reboots
- IPC control: `noctalia msg plugin damian-ds7/battery-threshold:service all set 80`

### What This Helper Adds

While the plugin controls the threshold, it doesn't actively discharge an already-full battery to reach that threshold. This helper fills that gap by automatically forcing discharge when:

- Your battery is above the set threshold (e.g., 100% vs 65% target)
- AC power is connected

## Features

- **Auto-discharge to threshold**: When AC is connected and battery is above threshold, actively discharges to the target level
- **Plugin integration**: Reads directly from `charge_control_end_threshold` — works seamlessly with Noctalia plugin
- **Set and forget**: Runs in background via systemd, automatically adapts to your plugin settings
- **Safe operation**: Returns to auto mode when on battery power or threshold is reached

## Why?

Many modern laptops support battery charge thresholds to prolong battery life. However, when you set a threshold (e.g., 65%) while your battery is at 100%, it stays at 100% until you manually discharge it by using the laptop on battery.

This helper solves that by automatically discharging to your target threshold when on AC power.

## Requirements

### Hardware
- **Laptop with battery charge control** (`charge_control_end_threshold` support)
- **Battery charge behaviour control** (`force-discharge` mode support)

Tested on laptops with:
- **Lenovo ThinkPad T480** (Arch Linux + Niri + Noctalia)
- `/sys/class/power_supply/BAT1/charge_control_end_threshold`
- `/sys/class/power_supply/BAT1/charge_behaviour` with `force-discharge` option

> ⚠️ **Important — battery device path.** The Noctalia plugin defaults to `/sys/class/power_supply/BAT0`. Many ThinkPads (and other laptops) expose the battery as **BAT1**. After installing the plugin, open its settings and point `battery_device` at your real path (e.g. `/sys/class/power_supply/BAT1`), otherwise the plugin's widget will report "unavailable" while the helper continues to work via its own `BAT1` sysfs reads.

### Software
- **Noctalia Shell** (any recent version that ships Plugin API v3)
- **Battery Threshold** plugin by Damian D'Souza (`damian-ds7/battery-threshold`)
- Linux distribution with systemd support

## Installation

### Prerequisites

First, install and set up the [Battery Threshold plugin](https://noctalia.dev/plugins/community/battery-threshold):

1. Install the plugin from [noctalia.dev](https://noctalia.dev/plugins/community/battery-threshold).
2. Run the plugin's `setup_rules.sh` (via the panel's "Setup" button, or directly). This creates the `battery_ctl` group, adds your user to it, and installs `/etc/udev/rules.d/99-battery-threshold.rules` — granting write access to `charge_control_end_threshold`.
3. **Reboot / re-login** so the new group membership takes effect.
4. In the plugin settings, set `battery_device` to your actual battery path (e.g. `/sys/class/power_supply/BAT1` on ThinkPads — the default is BAT0).

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/GGEZUS/noctalia-plugin-battery_threshold-auto-discharge/main/install.sh | bash
```

### Manual Install

1. **Clone the repo:**
   ```bash
   git clone https://github.com/GGEZUS/noctalia-plugin-battery_threshold-auto-discharge.git
   cd noctalia-plugin-battery_threshold-auto-discharge
   ```

2. **Run the installer:**
   ```bash
   ./install.sh
   ```

The installer will:
- Migrate any legacy helper udev rule that previously occupied `99-battery-threshold.rules` (the filename now owned by the plugin), offering to remove it.
- Install the helper's own udev rule as `99-battery-auto-discharge.rules` — it only grants write access to `charge_behaviour`, which the plugin's rule does not cover.
- Install the monitoring script.
- Install and enable the systemd service.
- Create the log directory.

The helper's rule and the plugin's rule now coexist under different filenames, so running the plugin's `setup_rules.sh` no longer clobbers the helper's `charge_behaviour` access.

## Usage

1. **Set your battery threshold** using the Noctalia plugin (e.g., set to 65%)
2. **Connect AC power**
3. **Done!** The helper will automatically discharge to your threshold

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Plugin threshold: 65%                                      │
│  Current battery: 100%                                      │
│  AC: Connected                                              │
├─────────────────────────────────────────────────────────────┤
│  → Force discharge until battery reaches 65%                │
│  → Switch to auto mode at 65%                               │
│  → Maintain 65% while on AC                                 │
└─────────────────────────────────────────────────────────────┘
```

### Monitor Progress

```bash
# Check service status
sudo systemctl status battery-auto-discharge

# View logs
tail -f ~/.local/share/battery-auto-discharge/log

# Check current battery percentage
cat /sys/class/power_supply/BAT1/capacity

# Check current charge behaviour
cat /sys/class/power_supply/BAT1/charge_behaviour
```

## Uninstallation

```bash
./uninstall.sh
```

Or manually:
```bash
sudo systemctl disable --now battery-auto-discharge
sudo rm /etc/systemd/system/battery-auto-discharge.service
sudo rm /usr/local/bin/battery-auto-discharge
sudo rm /etc/udev/rules.d/99-battery-auto-discharge.rules
# Only remove 99-battery-threshold.rules if it still contains our legacy
# charge_behaviour signature; otherwise it belongs to the plugin.
sudo udevadm control --reload-rules
rm -rf ~/.local/share/battery-auto-discharge
```

## Troubleshooting

### Service not running

```bash
sudo systemctl status battery-auto-discharge
sudo journalctl -u battery-auto-discharge -n 50
```

### Permissions denied

Make sure udev rules are loaded:
```bash
ls -l /sys/class/power_supply/BAT1/charge_behaviour
# Should show -rw-rw-rw-
```

If not, reload:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply
```

### Battery not discharging

Check if your laptop supports `force-discharge`:
```bash
cat /sys/class/power_supply/BAT1/charge_behaviour
```

Should show: `[auto] inhibit-charge force-discharge`

If `force-discharge` is missing, your laptop may not support this feature.

### Service rapidly switching modes

If you see rapid switching between force-discharge and auto modes in logs:
```bash
tail -f ~/.local/share/battery-auto-discharge/log
```

**Solution:** Ensure your AC adapter is detected:
```bash
ls /sys/class/power_supply/ | grep -i ac
cat /sys/class/power_supply/AC/online
# Should return 1 when AC is connected
```

The script requires the AC adapter to be at `/sys/class/power_supply/AC` to properly detect when it's safe to force discharge. If your system uses a different path, you'll need to update the `AC_PATH` variable in the script.

### Plugin not working

See the [plugin's page](https://noctalia.dev/plugins/community/battery-threshold):
- Ensure the udev rule is installed (run the plugin's Setup)
- Check you're in the `battery_ctl` group (`groups | grep battery_ctl`) — re-login if missing
- Verify your laptop supports charge threshold control
- Make sure `battery_device` in plugin settings points to your real battery
  (e.g. `/sys/class/power_supply/BAT1` — the default `BAT0` won't match
  systems that expose BAT1)

## Configuration

Default settings work for most users. The script checks every 10 seconds:

- **Battery path:** `/sys/class/power_supply/BAT1`
- **AC adapter path:** `/sys/class/power_supply/AC`
- **Check interval:** 10 seconds
- **Log location:** `~/.local/share/battery-auto-discharge/log`

To customize, edit `/usr/local/bin/battery-auto-discharge` and restart the service.

## Credits

- **Plugin:** [Battery Threshold](https://noctalia.dev/plugins/community/battery-threshold) by [Damian D'Souza](https://github.com/noctalia-dev/community-plugins/tree/main/battery-threshold) (`damian-ds7/battery-threshold`)
- **Noctalia Shell:** [noctalia.dev](https://noctalia.dev/)

## Contributing

Contributions welcome! Feel free to open issues or PRs.

## License

MIT License - feel free to use and modify as needed.

## Acknowledgments

- Works with the [Noctalia Battery Threshold plugin](https://noctalia.dev/plugins/community/battery-threshold) by Damian D'Souza
- Inspired by the need for better battery management on Linux laptops
