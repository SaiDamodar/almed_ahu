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

## Notes for Radxa

- Script folder name is `rpi_kiosk_setup`, but it can still be used on Radxa for desktop autostart/kiosk behavior.
- Some boot-splash tweaks are Raspberry Pi specific; autostart is the key part for Radxa.
- Keep app path consistent:
  - `/home/radxa/COO_app/ahu_dashboard`

