#!/usr/bin/env bash
set -e

echo "🔋 Noctalia Battery Plugin Threshold Auto-Discharge - Installer"
echo "==============================================================="
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ Please don't run this script as root. It will use sudo when needed."
    exit 1
fi

# Check if required files exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES=("battery-auto-discharge" "battery-auto-discharge.service" "99-battery-auto-discharge.rules")

for file in "${FILES[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
        echo "❌ Missing file: $file"
        exit 1
    fi
done

echo "✅ All required files found"
echo

# Check battery support
echo "🔍 Checking battery support..."
if [[ ! -f /sys/class/power_supply/BAT1/charge_control_end_threshold ]]; then
    echo "❌ Your battery doesn't support charge control"
    exit 1
fi

if [[ ! -f /sys/class/power_supply/BAT1/charge_behaviour ]]; then
    echo "❌ Your battery doesn't support charge behaviour control"
    exit 1
fi

if ! grep -q "force-discharge" /sys/class/power_supply/BAT1/charge_behaviour; then
    echo "❌ Your battery doesn't support force-discharge mode"
    exit 1
fi

echo "✅ Battery supports required features"
echo

# Migrate legacy udev rule if present.
#
# Older versions of this helper installed to the same filename the Noctalia
# battery-threshold plugin now uses (99-battery-threshold.rules). The plugin's
# rule only grants access to charge_control_end_threshold, so leaving our old
# file in place would (a) collide with the plugin's setup and (b) eventually
# lose charge_behaviour access once the plugin overwrites it. Detect our legacy
# signature and offer to remove it.
LEGACY_UDEV="/etc/udev/rules.d/99-battery-threshold.rules"
LEGACY_SIGNATURE="charge_behaviour"
if [[ -f "$LEGACY_UDEV" ]] && grep -q "$LEGACY_SIGNATURE" "$LEGACY_UDEV"; then
    echo "⚠️  Detected legacy helper udev rule at $LEGACY_UDEV"
    echo "    (This filename is now used by the Noctalia battery-threshold plugin,"
    echo "     which does not grant access to charge_behaviour.)"
    echo
    read -p "Remove the legacy file so the plugin can use that slot? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo rm -f "$LEGACY_UDEV"
        echo "🗑️  Legacy rule removed"
        # Reload will happen below after the new rule is installed.
    else
        echo "⏭️  Legacy rule left in place (charge_behaviour access will still work,"
        echo "    but may break if the plugin later overwrites that file)."
    fi
    echo
fi

# Check if our udev rule already exists
INSTALL_UDEV=true
if [[ -f /etc/udev/rules.d/99-battery-auto-discharge.rules ]]; then
    echo "ℹ️  Helper udev rule already installed at /etc/udev/rules.d/99-battery-auto-discharge.rules"
    echo
    read -p "Reinstall helper udev rule? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_UDEV=false
        echo "⏭️  Skipping udev rules installation"
    fi
    echo
fi

# Install udev rules (optional)
if [[ "$INSTALL_UDEV" == true ]]; then
    echo "📦 Installing helper udev rule..."
    sudo cp "$SCRIPT_DIR/99-battery-auto-discharge.rules" /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=power_supply
    echo "✅ Udev rule installed (coexists with the plugin's own rule)"
    echo
fi

# Install script
echo "📦 Installing monitoring script..."
sudo cp "$SCRIPT_DIR/battery-auto-discharge" /usr/local/bin/
sudo chmod +x /usr/local/bin/battery-auto-discharge
echo "✅ Script installed"
echo

# Get current username
USER=$(whoami)

# Create systemd service with correct user
echo "📦 Installing systemd service..."
sed "s/YOUR_USERNAME/$USER/g" "$SCRIPT_DIR/battery-auto-discharge.service" | \
    sudo tee /etc/systemd/system/battery-auto-discharge.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable battery-auto-discharge.service
sudo systemctl restart battery-auto-discharge.service
echo "✅ Service installed and started"
echo

# Check service status
sleep 2
if sudo systemctl is-active --quiet battery-auto-discharge.service; then
    echo "✅ Service is running"
else
    echo "⚠️  Service may not be running. Check with: sudo systemctl status battery-auto-discharge"
fi

echo
echo "🎉 Installation complete!"
echo
echo "Next steps:"
echo "  1. Make sure the Noctalia battery-threshold plugin is configured to use"
echo "     the correct battery (e.g. /sys/class/power_supply/BAT1) — its default"
echo "     is BAT0, which won't match systems with BAT1."
echo "  2. Set your battery threshold using the plugin (e.g. 65%)."
echo "  3. Connect AC power."
echo "  4. Monitor progress: tail -f ~/.local/share/battery-auto-discharge/log"
echo
echo "Note: The helper's udev rule (99-battery-auto-discharge.rules) only grants"
echo "      write access to charge_behaviour. The plugin's own setup_rules.sh"
echo "      handles charge_control_end_threshold via the battery_ctl group, and"
echo "      the two no longer collide."
echo
echo "For troubleshooting, see README.md"
