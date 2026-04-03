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
