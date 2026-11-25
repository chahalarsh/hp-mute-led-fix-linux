#!/usr/bin/env bash
# Installer for mute-led-sync: drives the keyboard mute LED from the
# default PipeWire sink's mute state, as a systemd user service.
set -euo pipefail

LED_NAME="${LED_NAME:-hda::mute}"
GROUP="ledctl"
BIN="$HOME/.local/bin/mute-led-sync"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/mute-led-sync.service"
RULE="/etc/udev/rules.d/99-mute-led.rules"

if [ "$(id -u)" -eq 0 ]; then
  echo "Run as your normal user (it uses sudo where needed), not as root." >&2
  exit 1
fi

for cmd in sudo pactl systemctl udevadm sg; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

if [ ! -d "/sys/class/leds/$LED_NAME" ]; then
  echo "LED '$LED_NAME' not found. Available LEDs:" >&2
  ls /sys/class/leds/ >&2
  echo "Re-run with e.g.: LED_NAME=platform::mute ./install.sh" >&2
  exit 1
fi

echo "==> Creating group '$GROUP' and adding $USER"
sudo groupadd -f "$GROUP"
sudo usermod -aG "$GROUP" "$USER"

echo "==> Installing udev rule ($RULE)"
sudo tee "$RULE" >/dev/null <<EOF
SUBSYSTEM=="leds", KERNEL=="$LED_NAME", ACTION=="add|change", RUN+="/bin/sh -c 'chgrp $GROUP /sys%p/brightness /sys%p/trigger && chmod g+w /sys%p/brightness /sys%p/trigger'"
EOF
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=leds --action=add
sudo udevadm settle
ls -l "/sys/class/leds/$LED_NAME/brightness" "/sys/class/leds/$LED_NAME/trigger"

echo "==> Installing $BIN"
mkdir -p "$(dirname "$BIN")"
cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
# Drive the keyboard mute LED from the default PipeWire sink's mute state.
LED_NAME="${LED_NAME:-hda::mute}"
LED="/sys/class/leds/$LED_NAME"
STATE="${XDG_RUNTIME_DIR:-/tmp}/mute-led-sync.trigger"

restore() {
  local t=audio-mute
  [ -r "$STATE" ] && t=$(cat "$STATE")
  echo "$t" > "$LED/trigger" 2>/dev/null
}

if [ "$1" = restore ]; then restore; exit 0; fi

if [ ! -w "$LED/brightness" ] || [ ! -w "$LED/trigger" ]; then
  echo "cannot write $LED (udev rule applied? in group ledctl?)" >&2
  exit 1
fi

# Remember the kernel's trigger so we can hand the LED back on exit.
cur=$(sed -n 's/.*\[\(.*\)\].*/\1/p' "$LED/trigger")
if [ -n "$cur" ] && [ "$cur" != none ]; then echo "$cur" > "$STATE"; fi
echo none > "$LED/trigger"

trap restore EXIT
trap 'exit 0' INT TERM

update() {
  local m
  m=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
  if [ "$m" = yes ]; then echo 1 > "$LED/brightness"; else echo 0 > "$LED/brightness"; fi
}

while true; do
  update
  pactl subscribe | grep --line-buffered -E "on (sink #|server)" | while read -r _; do update; done
  sleep 2   # PipeWire restarted or went away; reconnect
done
EOF
chmod +x "$BIN"

echo "==> Installing systemd user service"
mkdir -p "$UNIT_DIR"
# Launched via 'sg' so it works immediately: the running systemd --user
# manager doesn't know about the new group until your next login.
cat > "$UNIT" <<EOF
[Unit]
Description=Sync mute LED with default PipeWire sink
After=pipewire-pulse.service wireplumber.service

[Service]
Environment=LED_NAME=$LED_NAME
ExecStart=/usr/bin/sg $GROUP -c "%h/.local/bin/mute-led-sync"
ExecStopPost=/usr/bin/sg $GROUP -c "%h/.local/bin/mute-led-sync restore"
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now mute-led-sync.service
sleep 1
systemctl --user --no-pager status mute-led-sync.service || true

echo
echo "Done. Toggle mute (e.g. 'pactl set-sink-mute @DEFAULT_SINK@ toggle') to test."
