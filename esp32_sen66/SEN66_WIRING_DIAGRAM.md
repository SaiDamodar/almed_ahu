# SEN66 Environmental Sensor - Wiring Diagram

## SEN66 Sensor Overview

The **Sensirion SEN66** is an all-in-one environmental sensor module that measures:

| Parameter | Range | Unit |
|-----------|-------|------|
| PM1.0 | 0-1000 | µg/m³ |
| PM2.5 | 0-1000 | µg/m³ |
| PM4.0 | 0-1000 | µg/m³ |
| PM10 | 0-1000 | µg/m³ |
| Temperature | -10 to 50 | °C |
| Humidity | 0-100 | %RH |
| VOC Index | 1-500 | Index |
| NOx Index | 1-500 | Index |
| CO2* | 400-5000 | ppm |

*CO2 available on SEN66-SDN variant

---

## Pin Configuration

### SEN66 Pinout (8-pin connector)

```
   ┌─────────────────────┐
   │                     │
   │      SEN66          │
   │   Environmental     │
   │      Sensor         │
   │                     │
   │  ┌─┬─┬─┬─┬─┬─┬─┬─┐  │
   │  │1│2│3│4│5│6│7│8│  │
   │  └─┴─┴─┴─┴─┴─┴─┴─┘  │
   └─────────────────────┘
```

| Pin | Name | Description |
|-----|------|-------------|
| 1 | VDD | Power supply (3.3V - 5V) |
| 2 | GND | Ground |
| 3 | SDA | I2C Data |
| 4 | SCL | I2C Clock |
| 5 | SEL | Interface select (GND for I2C) |
| 6 | NC | Not connected |
| 7 | NC | Not connected |
| 8 | NC | Not connected |

---

## ESP32 Wiring

### ESP32 DevKit V1 Pinout

```
                    ┌─────────────────────┐
                    │      ESP32          │
                    │     DevKit V1       │
                    │                     │
             3.3V ──┤ 3V3            VIN ├── 5V
              GND ──┤ GND            GND ├── GND
                    ┤ EN             D23 ├── (MOSI)
              VP ───┤ VP             D22 ├── SCL (GPIO22) ◄── SEN66 SCL
              VN ───┤ VN             TX0 ├──
             D34 ───┤ D34            RX0 ├──
             D35 ───┤ D35            D21 ├── SDA (GPIO21) ◄── SEN66 SDA
             D32 ───┤ D32            D19 ├──
             D33 ───┤ D33            D18 ├──
             D25 ───┤ D25             D5 ├──
             D26 ───┤ D26            D17 ├──
             D27 ───┤ D27            D16 ├──
             D14 ───┤ D14             D4 ├──
             D12 ───┤ D12             D2 ├── LED
             D13 ───┤ D13            D15 ├──
              GND ──┤ GND            GND ├── GND
              VIN ──┤ VIN            3V3 ├── 3.3V
                    └─────────────────────┘
```

---

## Connection Diagram

```
    ┌─────────────────┐                    ┌─────────────────┐
    │     ESP32       │                    │     SEN66       │
    │                 │                    │                 │
    │          3.3V ──┼────────────────────┼── VDD (Pin 1)   │
    │                 │                    │                 │
    │           GND ──┼────────────────────┼── GND (Pin 2)   │
    │                 │                    │                 │
    │    GPIO21/SDA ──┼────────────────────┼── SDA (Pin 3)   │
    │                 │                    │                 │
    │    GPIO22/SCL ──┼────────────────────┼── SCL (Pin 4)   │
    │                 │                    │                 │
    │           GND ──┼────────────────────┼── SEL (Pin 5)   │
    │                 │                    │  (for I2C mode) │
    └─────────────────┘                    └─────────────────┘
```

---

## Wiring Table

| ESP32 Pin | SEN66 Pin | Wire Color (Suggested) |
|-----------|-----------|------------------------|
| 3.3V | Pin 1 (VDD) | 🔴 Red |
| GND | Pin 2 (GND) | ⚫ Black |
| GPIO21 | Pin 3 (SDA) | 🔵 Blue |
| GPIO22 | Pin 4 (SCL) | 🟡 Yellow |
| GND | Pin 5 (SEL) | ⚫ Black |

---

## Physical Wiring Diagram

```
                                           ┌──────────────────┐
   ┌────────────────────┐                  │    SEN66         │
   │                    │                  │   ┌──────────┐   │
   │     ESP32          │                  │   │  Sensor  │   │
   │   ┌──────────┐     │                  │   │  Module  │   │
   │   │          │     │                  │   └──────────┘   │
   │   │   USB    │     │                  │                  │
   │   │          │     │    ┌─────────────┤ 1  VDD ──────────┼─── 3.3V (Red)
   │   └──────────┘     │    │             │                  │
   │                    │    │  ┌──────────┤ 2  GND ──────────┼─── GND (Black)
   │              3V3 ──┼────┘  │          │                  │
   │                    │       │   ┌──────┤ 3  SDA ──────────┼─── GPIO21 (Blue)
   │              GND ──┼───────┴───│──────┤                  │
   │                    │           │  ┌───┤ 4  SCL ──────────┼─── GPIO22 (Yellow)
   │           GPIO21 ──┼───────────┘  │   │                  │
   │                    │              │   │ 5  SEL ──────────┼─── GND (Black)
   │           GPIO22 ──┼──────────────┘   │                  │
   │                    │                  │ 6-8  NC          │
   │                    │                  │                  │
   └────────────────────┘                  └──────────────────┘
```

---

## I2C Configuration

- **I2C Address:** `0x6B`
- **I2C Speed:** 100 kHz (standard mode)
- **Logic Level:** 3.3V

### Pull-up Resistors

The SEN66 has internal pull-up resistors on SDA and SCL lines. 
External pull-ups are generally not required, but if you experience issues:

```
    3.3V ────┬────────┬────
             │        │
            [4.7K]  [4.7K]
             │        │
    SDA ─────┴────    │
    SCL ──────────────┴────
```

---

## Power Requirements

| Parameter | Value |
|-----------|-------|
| Supply Voltage | 3.3V - 5V |
| Average Current | ~60mA |
| Peak Current | ~100mA |
| Idle Current | ~5mA |

**Note:** Use a stable power supply. The SEN66 is sensitive to voltage fluctuations.

---

## Important Notes

1. **SEL Pin:** Connect to GND for I2C mode. Leave floating or connect to VDD for UART mode.

2. **Warm-up Time:** The sensor needs ~30 seconds warm-up for accurate readings.

3. **VOC/NOx Conditioning:** These indices need 24 hours of operation for optimal accuracy.

4. **Airflow:** Ensure proper airflow around the sensor for accurate readings.

5. **Placement:** Avoid placing near heat sources or in direct sunlight.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No I2C communication | Check SDA/SCL connections, verify SEL is connected to GND |
| Erratic readings | Check power supply stability, ensure proper airflow |
| High PM readings | Clean the sensor inlet, check for obstructions |
| Temperature offset | Use `setTemperatureOffset()` function to calibrate |

---

## Sensor Placement for AHU

```
    ┌───────────────────────────────────────────────────────┐
    │                     AHU UNIT                          │
    │                                                       │
    │   ┌─────────┐                          ┌─────────┐    │
    │   │  INLET  │  ───────────────────►    │ OUTLET  │    │
    │   │  AIR    │       AIR FLOW           │  AIR    │    │
    │   └─────────┘                          └─────────┘    │
    │       ▲                                     ▲         │
    │       │                                     │         │
    │   ┌───┴───┐                             ┌───┴───┐     │
    │   │ SEN66 │                             │ SEN66 │     │
    │   │(inlet)│                             │(outlet)│    │
    │   └───────┘                             └───────┘     │
    │                                                       │
    └───────────────────────────────────────────────────────┘
    
    Recommended: Place SEN66 at air outlet for treated air quality
    Optional: Place second SEN66 at inlet for comparison
```

---

## Libraries Required

```cpp
// Arduino IDE - Install via Library Manager
- Wire.h (built-in)
- ArduinoJson by Benoit Blanchon
- PubSubClient by Nick O'Leary
```

## Arduino IDE Board Settings

- **Board:** ESP32 Dev Module
- **Upload Speed:** 921600
- **CPU Frequency:** 240MHz
- **Flash Frequency:** 80MHz
- **Flash Mode:** QIO
- **Flash Size:** 4MB
- **Partition Scheme:** Default 4MB with spiffs

---

## Quick Test

After uploading the code, open Serial Monitor at 115200 baud:

```
========================================
ESP32 + SEN66 Environmental Sensor
========================================

Initializing SEN66...
Product: SEN66
Serial: 0123456789ABCDEF
Firmware: 1.0
✓ SEN66 initialized successfully

--- SEN66 Sensor Readings ---
PM1.0:       5.2 µg/m³
PM2.5:       8.7 µg/m³
PM4.0:       10.3 µg/m³
PM10:        12.1 µg/m³
Temperature: 25.50 °C
Humidity:    45.20 %RH
VOC Index:   95
NOx Index:   3
CO2:         450 ppm
Air Quality: Good
-----------------------------
```

