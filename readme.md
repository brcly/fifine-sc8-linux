# Fifine AmpliGame SC8 — Linux Setup Guide

The Fifine SC8 works on Linux out of the box as a basic audio device, but
the Game/Chat dual-output mixing feature requires some configuration.
Without it, one or both outputs will be silent.

## The Problem

The SC8 presents two separate audio outputs (Chat and Game) and a
microphone input over USB. Linux detects all of them correctly, but the
device firmware initializes the output volumes to 0 (silent) randomly.
PipeWire also resets them during startup. The physical Game/Chat balance
knob only works when both outputs are active and audible.

## What You Need

- Fifine SC8 connected via USB (make sure PC/PS4 switch on rear is set to **PC**)
- PipeWire (default on most modern distros)
- A decent USB port — some ports cause audio dropouts; if you get issues, try a different port

## Step 1: Verify the Device is Detected

```bash
aplay -l | grep fifine
```

You should see two playback devices:

```
card X: Chat [fifine SC8 Chat], device 0: USB Audio [USB Audio]
card X: Chat [fifine SC8 Chat], device 1: USB Audio [USB Audio #1]
```

If you only see one device, try unplugging and replugging.

## Step 2: Fix the Volume Initialization

Create a user systemd service that sets both output volumes after
PipeWire starts:

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/fifine-sc8-volume.service << 'EOF'
[Unit]
Description=Set Fifine SC8 volumes
After=pipewire.service wireplumber.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/amixer -c X cset numid=3 4094,4094
ExecStart=/usr/bin/amixer -c X cset numid=9 4094,4094
RemainAfterExit=yes

[Install]
WantedBy=pipewire.service
EOF

systemctl --user daemon-reload
systemctl --user enable fifine-sc8-volume.service
```

**Note:** The SC8 isn't card X on your system, check `cat /proc/asound/cards`
and replace `-c X` with your card number.

## Step 3: Rename the Outputs (Optional but Recommended)

By default PipeWire names both outputs "fifine SC8 Chat Pro" which is
confusing. Create a WirePlumber config to give them proper names:

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

cat > ~/.config/wireplumber/wireplumber.conf.d/51-fifine-sc8.conf << 'EOF'
monitor.alsa.rules = [
  {
    matches = [
      {
        node.name = "alsa_output.usb-MV-SILICON_fifine_SC8_Chat_20190808-00.pro-output-0"
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
        node.name = "alsa_output.usb-MV-SILICON_fifine_SC8_Chat_20190808-00.pro-output-1"
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
        node.name = "alsa_input.usb-MV-SILICON_fifine_SC8_Chat_20190808-00.pro-input-0"
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
```

**Note:** The serial number `20190808` in the node names may differ on
your device. Check yours with:

```bash
pw-cli list-objects Node | grep "node.name.*fifine"
```

## Step 4: Reboot and Verify

```bash
sudo reboot
```

After reboot, check everything:

```bash
# Both volumes should be 4094
amixer -c 0 cget numid=3
amixer -c 0 cget numid=9

# Should show SC8 Game, SC8 Chat, SC8 Mic
wpctl status
```

## Step 5: Route Your Apps

The whole point of the SC8's dual output is to send different apps to
different outputs, then use the physical Game/Chat knob to balance them:

- Set your **game or music player & default audio** output to **SC8 Game**
- Set **Discord/voice chat** output to **SC8 Chat**
- The **Game/Chat knob** on the SC8 balances between them in your headphones

You can route apps in KDE Plasma's volume applet (click the speaker icon
in the system tray while audio is playing), or install `pavucontrol` for
a more detailed view.

## Troubleshooting

**One output is silent after reboot:**
The volume service may not have run. Check:
```bash
systemctl --user status fifine-sc8-volume.service
```
If it failed, manually set the volume:
```bash
amixer -c 0 cset numid=3 4094,4094
amixer -c 0 cset numid=9 4094,4094
```

**Audio cuts out or both outputs die:**
Try a different USB port. Some ports don't provide enough power or have
flaky connections that cause the device to drop audio when both streams
are active. Some USB ports with AMD Ryzen CPU's also have USB Audio 
issues that are persistent on both Windows & Linux.

**Only one output device shows up:**
Make sure the PC/PS4 switch on the rear of the SC8 is set to **PC**.
PS4 mode only exposes one output. Ensure that the device is set to
**Pro Audio** within Pavucontrol's configuration page.

**The knob doesn't do anything:**
Both outputs need to be actively playing audio. The knob mixes between
the two hardware streams — if only one is playing, turning the knob
towards the silent one, will fade the audio to silence.

## What's Being Fixed Upstream

A kernel patch is in progress to add a boot quirk that sets both output
volumes automatically during device probe, eliminating the need for the
systemd service. The patch modifies `sound/usb/quirks.c` to initialize
Feature Unit 2 (Chat) and Feature Unit 10 (Game) volumes for device
3142:0c88 at plug time.
