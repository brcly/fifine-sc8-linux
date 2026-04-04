# Fifine AmpliGame SC8 — Linux Manual Setup

If you prefer not to run scripts, here's how to set up the SC8 step by step.

## Before You Start

1. Plug in the SC8 via USB
2. Set the **PC/PS4 switch** on the rear to **PC**
3. Make sure `amixer` is installed (`alsa-utils` package)

## Step 1: Find Your Card Number

```
cat /proc/asound/cards
```

You'll see output like:

```
 0 [Chat           ]: USB-Audio - fifine SC8 Chat
                      MV-SILICON fifine SC8 Chat at usb-xxxx, full speed
 1 [NVidia         ]: HDA-Intel - HDA NVidia
 ...
```

Find the line with `fifine SC8 Chat`. The number on the left is your
**card number**. In this example it's `0`.

> Throughout this guide, replace `YOUR_CARD` with your card number.

## Step 2: Set the Volumes

Both outputs may initialize silent. Fix them:

```
amixer -c YOUR_CARD cset name="PCM Playback Volume" 4094,4094
amixer -c YOUR_CARD cset name="PCM Playback Volume",index=1 4094,4094
```

You should now hear audio from both outputs. Test with:

```
speaker-test -c 2 -D hw:YOUR_CARD,0 -t sine
speaker-test -c 2 -D hw:YOUR_CARD,1 -t sine
```

## Step 3: Make Volumes Persist Across Reboots

PipeWire resets the volumes when it starts, so we need a service that runs after it.

Create the file `~/.config/systemd/user/fifine-sc8-volume.service` with this content:

```
[Unit]
Description=Set Fifine SC8 Chat and Game output volumes
After=pipewire.service wireplumber.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash -c 'CARD=$(grep -l "fifine SC8" /proc/asound/card*/stream0 2>/dev/null | head -1 | grep -o "card[0-9]*"); CARD=${CARD#card}; amixer -c $CARD cset name="PCM Playback Volume" 4094,4094; amixer -c $CARD cset name="PCM Playback Volume",index=1 4094,4094'
RemainAfterExit=yes

[Install]
WantedBy=pipewire.service
```

Then enable it:

```
systemctl --user daemon-reload
systemctl --user enable fifine-sc8-volume.service
```

## Step 4: Rename the Outputs (Optional)

By default both outputs are confusingly named "fifine SC8 Chat Pro" and "fifine SC8 Chat Pro 1". To rename them, first find your device's node names:

```
pw-cli list-objects Node | grep "node.name.*fifine"
```

You'll see something like:

```
node.name = "alsa_output.usb-MV-SILICON_fifine_SC8_Chat_20190808-00.pro-output-0"
node.name = "alsa_output.usb-MV-SILICON_fifine_SC8_Chat_20190808-00.pro-output-1"
node.name = "alsa_input.usb-MV-SILICON_fifine_SC8_Chat_20190808-00.pro-input-0"
```

The number after `Chat_` (e.g. `20190808`) is your device's **serial number**.
It may differ on your unit.

> Throughout this step, replace `YOUR_SERIAL` with the number you found above.

Create the file `~/.config/wireplumber/wireplumber.conf.d/51-fifine-sc8.conf`
with this content:

```
monitor.alsa.rules = [
  {
    matches = [
      {
        node.name = "alsa_output.usb-MV-SILICON_fifine_SC8_Chat_YOUR_SERIAL-00.pro-output-0"
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
        node.name = "alsa_output.usb-MV-SILICON_fifine_SC8_Chat_YOUR_SERIAL-00.pro-output-1"
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
        node.name = "alsa_input.usb-MV-SILICON_fifine_SC8_Chat_YOUR_SERIAL-00.pro-input-0"
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
```

## Step 5: Reboot

After rebooting, verify everything works:

```
wpctl status
```

You should see SC8 Game, SC8 Chat, and SC8 Mic listed.

## Step 6: Route Your Apps

| App Type | Output Device |
|----------|---------------|
| Games, music, YouTube | **SC8 Game** |
| Discord, TeamSpeak, Zoom | **SC8 Chat** |

The physical **Game/Chat knob** balances between the two in your headphones. Both outputs must be actively playing for the knob to work.

## Troubleshooting

**Silent output after reboot** — Run `systemctl --user status fifine-sc8-volume.service` to check the service. Set volumes manually if needed:
```
amixer -c YOUR_CARD cset name="PCM Playback Volume" 4094,4094
amixer -c YOUR_CARD cset name="PCM Playback Volume",index=1 4094,4094
```

**Audio cuts out** — Try a different USB port.

**Only one output** — PC/PS4 switch must be set to PC.

**Knob does nothing** — Both outputs need audio playing from different apps.