#!/usr/bin/env bash
set -e

echo "🗑️  Noctalia Battery Plugin Threshold Auto-Discharge - Uninstaller"
echo "================================================================="
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ Please don't run this script as root. It will use sudo when needed."
    exit 1
fi

echo "This will remove:"
echo "  - Systemd service: battery-auto-discharge"
echo "  - Monitoring script: /usr/local/bin/battery-auto-discharge"
echo "  - Helper udev rule:  /etc/udev/rules.d/99-battery-auto-discharge.rules"
echo "  - Legacy helper rule (if present): /etc/udev/rules.d/99-battery-threshold.rules"
echo "  - Log directory: ~/.local/share/battery-auto-discharge"
echo
echo "Note: the plugin's own udev rule (if it owns 99-battery-threshold.rules)"
echo "      will NOT be touched."
echo

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Stop and disable service
echo "🛑 Stopping and disabling service..."
sudo systemctl disable --now battery-auto-discharge.service 2>/dev/null || true
echo "✅ Service stopped"

# Remove service file
echo "🗑️  Removing service file..."
sudo rm -f /etc/systemd/system/battery-auto-discharge.service
sudo systemctl daemon-reload
echo "✅ Service removed"

# Remove script
echo "🗑️  Removing monitoring script..."
sudo rm -f /usr/local/bin/battery-auto-discharge
echo "✅ Script removed"

# Remove udev rules
echo "🗑️  Removing helper udev rule..."
sudo rm -f /etc/udev/rules.d/99-battery-auto-discharge.rules

# Also remove the legacy-named helper rule ONLY if it still contains our
# charge_behaviour signature. We must NOT delete it if the Noctalia
# battery-threshold plugin now owns that slot (its rule does not mention
# charge_behaviour).
LEGACY_UDEV="/etc/udev/rules.d/99-battery-threshold.rules"
if [[ -f "$LEGACY_UDEV" ]] && grep -q "charge_behaviour" "$LEGACY_UDEV"; then
    echo "🗑️  Removing legacy helper rule at $LEGACY_UDEV..."
    sudo rm -f "$LEGACY_UDEV"
fi

sudo udevadm control --reload-rules
echo "✅ Udev rules removed"

# Remove log directory
echo "🗑️  Removing log directory..."
rm -rf "$HOME/.local/share/battery-auto-discharge"
echo "✅ Logs removed"

echo
echo "🎉 Uninstallation complete!"
echo "Thank you for using noctalia-plugin-battery_threshold-auto-discharge!"
