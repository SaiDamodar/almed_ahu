# ALMED AHU — Eco Touch Display

A low-cost ESP32 + ILI9341 4" touch-LCD controller that discovers every AHU
ESP32 on the local network, lets you pick one from a live dropdown, and shows
real-time Temperature / Humidity with setpoint control.

**Zero changes required to `esp32_main.ino`.**

---

## Hardware

| Part | Description | ~Cost |
|------|-------------|-------|
| ESP32 DevKit (WROOM-32 or WROVER) | Any 3.3 V variant | $3–5 |
| ILI9341 3.5" / 4" SPI TFT + XPT2046 | 320 × 240, on-board touch + SD | $5–9 |
| USB cable + 5 V supply | Power | — |

Total hardware cost: **~$10–14**

---

## Wiring

All signals run on the same SPI bus. The ILI9341 and XPT2046 use separate
chip-select pins so they can share MOSI / SCK / MISO.

```
ESP32 GPIO   Signal         ILI9341 pin    XPT2046 pin
──────────────────────────────────────────────────────
GPIO 23      MOSI / SDI         6             DIN
GPIO 18      SCK  / CLK         7             CLK
GPIO 19      MISO               —             DO
GPIO  5      TFT_CS             5             —
GPIO  2      TFT_DC / RS        4             —
GPIO  4      TFT_RST            3             —     (or tie to ESP EN)
GPIO 15      TOUCH_CS           —             CS
3V3          VCC            1 (LED + VCC)    VCC
GND          GND            2 (GND)          GND
```

> **LED (backlight):** Connect directly to 3.3 V for always-on.  
> For brightness control connect via a 100 Ω resistor or PWM GPIO.

---

## Libraries — install via Arduino Library Manager

| Library | Author | Min version |
|---------|--------|-------------|
| **TFT_eSPI** | Bodmer | ≥ 2.5.43 |
| **XPT2046_Touchscreen** | Paul Stoffregen | ≥ 1.4 |
| **PubSubClient** | Nick O'Leary | ≥ 2.8 |
| **ArduinoJson** | Benoit Blanchon | ≥ 6.21 (or v7) |

---

## TFT_eSPI Configuration

TFT_eSPI needs to know which pins your display uses.
You **must** replace (or overwrite) its `User_Setup.h` before building.

```bash
# macOS / Linux
cp eco_display/User_Setup.h \
   ~/Documents/Arduino/libraries/TFT_eSPI/User_Setup.h
```

```bat
:: Windows (PowerShell)
Copy-Item eco_display\User_Setup.h `
  "$env:USERPROFILE\Documents\Arduino\libraries\TFT_eSPI\User_Setup.h"
```

Restart the Arduino IDE after copying.

---

## Touch Calibration

The constants at the top of `eco_display.ino`:

```cpp
#define TOUCH_X_MIN   200
#define TOUCH_X_MAX  3900
#define TOUCH_Y_MIN   300
#define TOUCH_Y_MAX  3800
```

These are typical values for the XPT2046 on a standard 3.5" module.
If taps are off-target:

1. Open the **XPT2046_Touchscreen** example `TouchTest`
2. Note the raw `x` and `y` values when you touch each corner
3. Update the four constants accordingly

---

## Configuration (inside `eco_display.ino`)

```cpp
// WiFi — must match the hotspot the AHU ESP32 creates
const char* WIFI_SSID     = "PiSpot";
const char* WIFI_PASSWORD = "12345678";

// MQTT — AHU ESP32 runs Mosquitto at this IP
const char* MQTT_BROKER   = "10.42.0.1";
const char* MQTT_USER     = "almed";
const char* MQTT_PASS     = "Almed1234$";

// Default screen-lock passcode (6 digits)
#define DEFAULT_PASSCODE "123123"
```

Change `WIFI_SSID`, `WIFI_PASSWORD`, `MQTT_BROKER`, and credentials to match
your deployment.

---

## Flashing

1. Open `eco_display/eco_display.ino` in Arduino IDE
2. Select board: **ESP32 Dev Module** (or your specific variant)
3. Set **Partition Scheme** to *Default 4MB with spiffs* (or *Huge App*)
4. Upload speed: 921600
5. Flash

---

## How Discovery Works (no esp32_main changes needed)

The main AHU ESP32 already publishes two **retained** MQTT messages every
time it connects:

```
Topic:   almed/ahu/{SITE}/{ROOM}/{AHU}/status
Payload: online                              ← plain text, retained

Topic:   almed/ahu/{SITE}/{ROOM}/{AHU}/state
Payload: {"run":false,"tempSet":22.0,"humSet":55.0,"thing":"AHU_ESP2","ip":"..."}
```

The eco display subscribes to `almed/ahu/#`.  
Because the messages are **retained**, it receives them instantly —  
even if the main ESP32 was already running before the display powered on.

From the topic path it extracts `site`, `room`, `ahu`.  
From the `/state` JSON it extracts `thingName`, `ip`, `tempSet`, `humSet`, `run`.

Multiple AHU units each publish on their own unique topic, so all of them
appear in the dropdown automatically.

---

## Screen Descriptions

### 1 — Scanning
Shown for 5 seconds at startup. A progress bar fills while retained messages
arrive. Any tap skips straight to the device list.

### 2 — Device Select
Lists every discovered AHU unit. Tap a row to open its control screen.  
The previously active device is marked `ACTIVE`.  
If more than 4 devices exist, scroll arrows appear top/bottom.

### 3 — Control
```
┌─ Back            AHU_ESP2         OPEN ─┐
│  TEMPERATURE                           │
│   24.3 C                               │
│   SET: 22.0 C              [ − ] [ + ] │
├────────────────────────────────────────┤
│  HUMIDITY                              │
│   61.5 %                               │
│   SET: 55.0 %              [ − ] [ + ] │
├────────────────────────────────────────┤
│  AHU: RUNNING             Tap to toggle│
└────────────────────────────────────────┘
```

- Tap the TEMPERATURE or HUMIDITY card to make it active (blue left bar)
- Tap **−** / **+** to adjust the setpoint (sends MQTT command immediately)
- Tap the status bar at the bottom to toggle start / stop
- Tap **< Back** to return to device list
- Tap **LOCK / OPEN** (top right) to lock or open the passcode keypad

### 4 — Passcode Keypad
6-dot indicator shows progress. Tap digits, **←** to backspace, **✓** to confirm.  
Wrong passcode flashes red. Tap outside the pad to cancel.

---

## Lock Behaviour

| State | What is blocked |
|-------|----------------|
| Locked | All setpoint changes and toggle; viewing is always allowed |
| Unlocked | Full control |

Lock state is saved to ESP32 flash (`Preferences`) and survives reboots.  
Default passcode: `123123` — change `DEFAULT_PASSCODE` before flashing.

---

## MQTT Topics Used

| Direction | Topic | Payload |
|-----------|-------|---------|
| Subscribe | `almed/ahu/#` | wildcard catches status, state, telemetry |
| Publish | `almed/ahu/{site}/{room}/{ahu}/cmd` | `{"setpoint":22.5}` |
| Publish | `almed/ahu/{site}/{room}/{ahu}/cmd` | `{"humset":55.0}` |
| Publish | `almed/ahu/{site}/{room}/{ahu}/cmd` | `{"toggle":true}` |
| Publish (LWT) | `almed/eco_display/status` | `online` / `offline` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Display stays blank | Check TFT_CS, DC, RST wiring; verify `User_Setup.h` was replaced |
| Touch is inverted / off | Adjust `TOUCH_X_MIN/MAX`, `TOUCH_Y_MIN/MAX` in the `.ino` |
| No devices found | Confirm ESP32 AHU is on the same WiFi and MQTT credentials match |
| Screen freezes after touch | Likely SPI conflict — try reducing `SPI_FREQUENCY` to 27 MHz in `User_Setup.h` |
| Wrong colours | Uncomment `#define TFT_BGR_ORDER` in `User_Setup.h` |

