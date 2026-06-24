# Radxa Kiosk Setup (AHU Dashboard)

This guide is the repeatable checklist to run `ahu_dashboard` in kiosk mode on a fresh Radxa image.

---

## 1) Build the app

```bash
cd ~/COO_app/ahu_dashboard
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build linux --release
```

Verify binary exists:

```bash
ls -l ~/COO_app/ahu_dashboard/build/linux/arm64/release/bundle/ahu_dashboard
```

---

## 2) Enable kiosk autostart

Run setup script:

```bash
cd ~/COO_app/ahu_dashboard/rpi_kiosk_setup
sudo ./setup_kiosk.sh
sudo reboot
```

After reboot on Radxa:
- system can auto-login to desktop user (`radxa`)
- then kiosk autostart launches dashboard from `~/.config/autostart/almed-kiosk.desktop`

Check autostart entry:

```bash
ls -l /home/radxa/.config/autostart/almed-kiosk.desktop
```

---

## 3) Start dashboard manually (without reboot)

```bash
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/launch_kiosk.sh
```

If needed, run binary directly:

```bash
export DISPLAY=:0
cd /home/radxa/COO_app/ahu_dashboard/build/linux/arm64/release/bundle
export LD_LIBRARY_PATH="$PWD/lib:$LD_LIBRARY_PATH"
./ahu_dashboard
```

---

## 4) Exit kiosk to desktop (for maintenance)

Preferred:
- Use **Admin Settings -> Exit to Desktop** inside app

Terminal fallback:

```bash
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/exit_to_desktop.sh
```

Hard fallback:

```bash
pkill -f ahu_dashboard
```

---

## 5) Re-enter kiosk after maintenance

Option A (quick):

```bash
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/launch_kiosk.sh
```

Option B:

```bash
sudo reboot
```

---

## 6) Disable kiosk mode completely

```bash
cd /home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup
sudo ./disable_kiosk.sh
sudo reboot
```

---

## 7) Change WiFi / network settings

You can do this in two ways:

1. **From desktop/network tray** after exiting kiosk
2. **From dashboard admin pages** (if using in-app provisioning)

After WiFi change, relaunch kiosk:

```bash
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/launch_kiosk.sh
```

---

## 8) Quick diagnostics

Kiosk log:

```bash
cat /tmp/almed_kiosk.log
```

MQTT live topics:

```bash
mosquitto_sub -h localhost -p 1883 -u almed -P 'Almed1234$' -t 'almed/ahu/#' -v
```

---

## 9) Fix tiny text / wrong aspect ratio on a new display

Images 1–4 in the field report usually mean the Radxa is outputting **1080p** while the
panel is a smaller **1024×600** (or similar) screen. The monitor OSD **16:9 / 4:3** menu
only changes the panel scaler — you must set the correct mode on the **Radxa**.

### Step A — Check what Radxa is sending now

SSH into the Radxa (or open Terminal after exiting kiosk):

```bash
export DISPLAY=:0
xrandr --query
xdpyinfo | grep dimensions
```

Look for:
- output name (often `HDMI-1`, `HDMI-A-1`, or `HDMI-2`)
- current mode (if you see `1920x1080` on a 7" panel, that is the problem)

### Step B — Test the correct resolution live

Most ALMED 7" kiosks use **1024×600 landscape** (same as the Pi setup):

```bash
export DISPLAY=:0
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/configure_display.sh
```

If the UI still looks wrong, try rotation (panel mounted vertically):

```bash
export ALMED_DISPLAY_ROTATION=left
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/configure_display.sh
```

Then relaunch the dashboard:

```bash
/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/launch_kiosk.sh
```

You should see full-screen UI similar to images 5–7.

### Step C — Make it permanent

`launch_kiosk.sh` already runs `configure_display.sh` on every boot.

Edit the top of:

`/home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/configure_display.sh`

Common settings:

```bash
DISPLAY_WIDTH=1024
DISPLAY_HEIGHT=600
DISPLAY_ROTATION=normal    # or left / right if mounted portrait
UI_SCALE=1                 # use 1.5 or 2 only for true high-DPI panels
```

Or set env vars in autostart (`~/.config/autostart/almed-kiosk.desktop`):

```ini
Exec=env ALMED_DISPLAY_WIDTH=1024 ALMED_DISPLAY_HEIGHT=600 ALMED_DISPLAY_ROTATION=normal /home/radxa/COO_app/ahu_dashboard/rpi_kiosk_setup/launch_kiosk.sh
```

Reboot:

```bash
sudo reboot
```

### Step D — If your panel is not 1024×600

Check the label on the LCD FPC cable or controller board for native resolution
(e.g. `800x480`, `1280x800`, `1920x1080`). Set `DISPLAY_WIDTH` / `DISPLAY_HEIGHT`
to that exact value.

Create + apply a one-off custom mode:

```bash
export DISPLAY=:0
cvt 1280 800 60
# copy the Modeline from output, then:
xrandr --newmode "1280x800_60.00" <paste numbers after Modeline>
xrandr --addmode HDMI-1 "1280x800_60.00"
xrandr --output HDMI-1 --mode "1280x800_60.00"
```

Replace `HDMI-1` with your output name from `xrandr --query`.

### Step E — Ignore the display OSD ratio menu

The on-screen **Display Ratio: 16:9 / 4:3** setting does not change Radxa output.
Fix resolution on the Radxa; leave the OSD on **16:9** once the Radxa sends the
correct native mode.

---

## Notes for Radxa

- Script folder name is `rpi_kiosk_setup`, but it can still be used on Radxa for desktop autostart/kiosk behavior.
- Some boot-splash tweaks are Raspberry Pi specific; autostart is the key part for Radxa.
- Keep app path consistent:
  - `/home/radxa/COO_app/ahu_dashboard`
- New display too small? Run section **9)** above before changing Flutter code.

