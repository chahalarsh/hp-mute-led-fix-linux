#!/usr/bin/env bash
# Removes mute-led-sync and hands the LED back to the kernel.
set -uo pipefail

LED_NAME="${LED_NAME:-hda::mute}"

systemctl --user disable --now mute-led-sync.service 2>/dev/null
rm -f "$HOME/.config/systemd/user/mute-led-sync.service"
systemctl --user daemon-reload

# Give the LED back to the kernel's audio-mute trigger
echo audio-mute | sg ledctl -c "tee /sys/class/leds/$LED_NAME/trigger" >/dev/null 2>&1 || true

rm -f "$HOME/.local/bin/mute-led-sync" "${XDG_RUNTIME_DIR:-/tmp}/mute-led-sync.trigger"

sudo rm -f /etc/udev/rules.d/99-mute-led.rules
sudo udevadm control --reload

echo "Removed. The 'ledctl' group was left in place; remove it with:"
echo "  sudo gpasswd -d $USER ledctl && sudo groupdel ledctl"
