# Fifine AmpliGame SC8 — Linux Setup Guide

The Fifine SC8's Game/Chat dual-output mixing doesn't work out of the
box on Linux. One or both outputs will be silent, and the physical
Game/Chat balance knob won't function. This guide fixes that.

## Prerequisites

- Fifine SC8 connected via USB
- **PC/PS4 switch** on the rear of the SC8 must be set to **PC**
- A Linux distribution using PipeWire (Ubuntu 22.10+, Fedora 34+, Arch, etc.)

## Quick Setup

Save the script below as `setup-sc8.sh` and run it with `bash setup-sc8.sh`:

```bash
#!/bin/bash
set -e

echo "=== Fifine SC8 Linux Setup ==="
echo ""

# --- Find the SC8 ---
CARD=$(grep -l "fifine SC8" /proc/asound/card*/id 2>/dev/null | head -1 | grep -o 'card[0-9]*')
if [ -z "$CARD" ]; then
    echo "ERROR: Fifine SC8 not found. Is it plugged in with the switch set to PC?"
    exit 1
fi
CARD_NUM=${CARD#card}
CARD_ID=$(cat /proc/asound/$CARD/id)
echo "Found SC8 as card $CARD_NUM ($CARD_ID)"

# --- Volume fix service ---
echo ""
echo "Setting up volume initialization service..."
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/fifine-sc8-volume.service << EOF
[Unit]
Description=Set Fifine SC8 volumes
After=pipewire.service wireplumber.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/amixer -c $CARD_ID cset numid=3 4094,4094
ExecStart=/usr/bin/amixer -c $CARD_ID cset numid=9 4094,4094
RemainAfterExit=yes

[Install]
WantedBy=pipewire.service
EOF

systemctl --user daemon-reload
systemctl --user enable fifine-sc8-volume.service
echo "Volume service installed and enabled."

# --- WirePlumber rename config ---
echo ""
echo "Setting up output renaming..."
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

# Detect the actual node names from PipeWire
SERIAL=$(pw-cli list-objects Node 2>/dev/null \
    | grep "node.name.*fifine_SC8" \
    | head -1 \
    | grep -o 'fifine_SC8_Chat_[0-9]*' \
    | head -1)

if [ -z "$SERIAL" ]; then
    # Fallback: try to get serial from udev
    SERIAL=$(udevadm info /sys/class/sound/$CARD 2>/dev/null \
        | grep ID_USB_SERIAL \
        | head -1 \
        | grep -o 'fifine_SC8_Chat_[0-9]*')
fi

if [ -z "$SERIAL" ]; then
    echo "WARNING: Could not detect device serial. Skipping rename config."
    echo "You can run this script again after a reboot."
else
    BASENAME="alsa_output.usb-MV-SILICON_${SERIAL}-00"
    INPUTNAME="alsa_input.usb-MV-SILICON_${SERIAL}-00"

    cat > ~/.config/wireplumber/wireplumber.conf.d/51-fifine-sc8.conf << EOF
monitor.alsa.rules = [
  {
    matches = [
      {
        node.name = "${BASENAME}.pro-output-0"
      }
    ]
    actions = {
      update-props = {
        node.description = "SC8 Chat"
        node.nick = "SC8 Chat"
      }
    }
  }
  {
    matches = [
      {
        node.name = "${BASENAME}.pro-output-1"
      }
    ]
    actions = {
      update-props = {
        node.description = "SC8 Game"
        node.nick = "SC8 Game"
      }
    }
  }
  {
    matches = [
      {
        node.name = "${INPUTNAME}.pro-input-0"
      }
    ]
    actions = {
      update-props = {
        node.description = "SC8 Mic"
        node.nick = "SC8 Mic"
      }
    }
  }
]
EOF
    echo "Outputs renamed to SC8 Chat, SC8 Game, SC8 Mic."
fi

# --- Set volumes now ---
echo ""
echo "Setting volumes..."
amixer -c "$CARD_ID" cset numid=3 4094,4094 > /dev/null 2>&1
amixer -c "$CARD_ID" cset numid=9 4094,4094 > /dev/null 2>&1
echo "Volumes set."

# --- Done ---
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Reboot to apply all changes, or restart PipeWire now:"
echo "  systemctl --user restart pipewire wireplumber"
echo ""
echo "After reboot, set your apps like this:"
echo "  Games/Music  -> SC8 Game"
echo "  Discord/Chat -> SC8 Chat"
echo "  The physical knob balances between them."
echo ""
echo "If audio cuts out, try a different USB port."
```

Then reboot.

## How to Use the SC8 on Linux

Once set up, route your apps to the correct output:

| App Type | Output Device |
|----------|---------------|
| Games, music, YouTube | **SC8 Game** |
| Discord, TeamSpeak, Zoom | **SC8 Chat** |

You can route apps using:
- **KDE Plasma**: Click the speaker icon in the system tray while audio
  is playing, then change the output per app
- **GNOME**: Settings > Sound, or install `pavucontrol`
- **Any DE**: Install `pavucontrol` and use the Playback tab to move
  running audio streams between outputs

The physical **Game/Chat knob** balances between the two in your headphones.

## Uninstall

```bash
systemctl --user disable fifine-sc8-volume.service
rm ~/.config/systemd/user/fifine-sc8-volume.service
rm ~/.config/wireplumber/wireplumber.conf.d/51-fifine-sc8.conf
systemctl --user daemon-reload
systemctl --user restart pipewire wireplumber
```

## Troubleshooting

**One output is silent after reboot** —
Run `systemctl --user status fifine-sc8-volume.service` to check the
service ran. If it failed, set volumes manually:
`amixer -c 0 cset numid=3 4094,4094 && amixer -c 0 cset numid=9 4094,4094`

**Audio cuts out when both outputs are active** —
Try a different USB port. Some ports can't handle both audio streams.
This also happens on Windows with bad ports.

**Only one output shows up** —
Check the **PC/PS4 switch** on the rear — it must be set to **PC**.

**The Game/Chat knob doesn't do anything** —
Both outputs need audio playing simultaneously from different apps.
The knob mixes between the two streams.

**Using PulseAudio instead of PipeWire** —
The volume service still works. Skip the rename step. Use `pavucontrol`
to manage outputs.

## How It Works

The SC8 has three USB Audio Control interfaces with two output endpoints
(Chat and Game) and one input (Mic). The device firmware randomly
initializes output volumes to 0 (silent), and PipeWire resets them
during startup. The systemd service runs after PipeWire to set both
volumes. The WirePlumber config renames the outputs from confusing
default names to "SC8 Chat" and "SC8 Game".

A kernel patch is in progress to handle volume initialization at the
driver level, which will make the systemd service unnecessary.

## Tested On

- CachyOS (Arch-based), kernel 6.x, PipeWire 1.6.2, WirePlumber 0.5.14
- USB Audio device ID: `3142:0c88`

If you've tested on another distro, please report your results!
