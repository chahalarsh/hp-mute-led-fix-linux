# Hp mute led fix for linux
Make the keyboard **mute LED** follow the mute state of your default PipeWire sink on Linux.

On many laptops (HP, some Lenovo/Dell models) the mute key LED (`hda::mute`) is driven by the kernel's `audio-mute` trigger, which can fall out of sync with PipeWire/WirePlumber, e.g. when muting from a desktop applet, `pactl`, or a Bluetooth sink. This small service takes over the LED and sets it from `pactl` events instead.

Although this is hp specific, it should work on all given that you follow proper instructions

Check your LED name:

```bash
ls /sys/class/leds/
```

Look for something like `hda::mute`, `platform::mute`, or `*::mute`.

## Quick install (one-liner)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chahalarsh/hp-mute-led-fix-linux/main/install.sh)
```

With a custom LED name:

```bash
LED_NAME=platform::mute bash <(curl -fsSL https://raw.githubusercontent.com/chahalarsh/hp-mute-led-fix-linux/main/install.sh)
```

Uninstall the same way:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chahalarsh/hp-mute-led-fix-linux/main/uninstall.sh)
```

## Install (manual)

```bash
git clone https://github.com/chahalarsh/hp-mute-led-fix-linux.git
cd mute-led-sync
./install.sh
```

For a different LED name:

```bash
LED_NAME=platform::mute ./install.sh
```

To Uninstall:

```bash
./uninstall.sh
```

This stops the service, removes the files and udev rule, and restores the kernel's `audio-mute` trigger. To also remove the group:

```bash
sudo gpasswd -d $USER ledctl && sudo groupdel ledctl
```

## Troubleshooting

**`cannot write /sys/class/leds/... (udev rule applied? in group ledctl?)`**
Check the permissions:

```bash
ls -l /sys/class/leds/hda::mute/{brightness,trigger}
```

Both should be `root ledctl` with `g+w`. If not, re-run the udev trigger:

```bash
sudo udevadm trigger --subsystem-match=leds --action=add && sudo udevadm settle
```

Also confirm the LED name matches the one you installed with.

**LED is inverted or does nothing**
Some LEDs use inverted logic or have `max_brightness` other than 1. Check with `cat /sys/class/leds/hda::mute/max_brightness` and adjust the `update()` function.

**Service restarts in a loop**
Make sure `pactl info` works in your session and that `pipewire-pulse` is running.

**SELinux (Fedora)**
If the udev rule is silently ignored, check `sudo ausearch -m avc -ts recent`.
