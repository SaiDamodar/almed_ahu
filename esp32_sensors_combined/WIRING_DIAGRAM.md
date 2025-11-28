# ALMED AHU Combined Sensor Wiring

## Sensors
- **SEN66** - Environmental Sensor (PM, Temp, Humidity, VOC, NOx, CO2)
- **SDP810** - Differential Pressure Sensor

Both sensors share the same I2C bus.

---

## Wiring Diagram

```
                    ┌─────────────────────┐
                    │       ESP32         │
                    │                     │
                    │  3.3V ─────────┬────┼──── VCC (both sensors)
                    │                │    │
                    │  GND ──────────┼────┼──── GND (both sensors)
                    │                │    │
                    │  GPIO21 (SDA) ─┼────┼──── SDA (both sensors)
                    │                │    │
                    │  GPIO22 (SCL) ─┼────┼──── SCL (both sensors)
                    │                │    │
                    └────────────────┼────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
              ┌─────┴─────┐                    ┌──────┴──────┐
              │   SEN66   │                    │   SDP810    │
              │           │                    │             │
              │ VCC ──────│ 3.3V               │ VCC ────────│ 3.3V
              │ GND ──────│ GND                │ GND ────────│ GND
              │ SDA ──────│ GPIO21             │ SDA ────────│ GPIO21
              │ SCL ──────│ GPIO22             │ SCL ────────│ GPIO22
              └───────────┘                    └─────────────┘
```

---

## Pin Connections

### ESP32 DevKit
| ESP32 Pin | Function | Connect To |
|-----------|----------|------------|
| 3.3V | Power | VCC on both sensors |
| GND | Ground | GND on both sensors |
| GPIO21 | I2C SDA | SDA on both sensors |
| GPIO22 | I2C SCL | SCL on both sensors |

### SEN66 Sensor (6-pin JST)
| Pin | Name | Color | Connect To |
|-----|------|-------|------------|
| 1 | VCC | Red | ESP32 3.3V |
| 2 | GND | Black | ESP32 GND |
| 3 | SDA | Green | ESP32 GPIO21 |
| 4 | SCL | Yellow | ESP32 GPIO22 |
| 5 | SEL | - | Leave floating (I2C mode) |
| 6 | NC | - | Not connected |

### SDP810 Sensor (4-pin)
| Pin | Name | Connect To |
|-----|------|------------|
| 1 | VCC | ESP32 3.3V |
| 2 | GND | ESP32 GND |
| 3 | SDA | ESP32 GPIO21 |
| 4 | SCL | ESP32 GPIO22 |

---

## I2C Addresses

| Sensor | I2C Address |
|--------|-------------|
| SEN66 | 0x6B |
| SDP810 | 0x25 |

Both sensors use different addresses, so they work together on the same bus!

---

## Physical Layout

```
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │   ┌─────────┐        ┌─────────┐        ┌─────────┐    │
    │   │ ESP32   │        │  SEN66  │        │ SDP810  │    │
    │   │ DevKit  │        │         │        │         │    │
    │   │         │        │   ┌─┐   │        │  ┌───┐  │    │
    │   │  ┌───┐  │        │   │ │   │        │  │ ○ │  │    │
    │   │  │USB│  │        │   └─┘   │        │  └───┘  │    │
    │   │  └───┘  │        │         │        │  tubes  │    │
    │   │         │        └─────────┘        └─────────┘    │
    │   └─────────┘                                          │
    │        │                  │                  │         │
    │        │    ┌─────────────┴──────────────────┘         │
    │        │    │                                          │
    │        └────┼──── I2C Bus (SDA + SCL)                  │
    │             │                                          │
    │             └──── Power (3.3V + GND)                   │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

---

## Libraries Required

Install via Arduino Library Manager:

1. **Sensirion I2C SEN66**
   - Search: "Sensirion I2C SEN66"
   - Or: https://github.com/Sensirion/arduino-i2c-sen66

2. **Sensirion I2C SDP**
   - Search: "Sensirion I2C SDP"
   - Or: https://github.com/Sensirion/arduino-i2c-sdp

---

## Serial Output Example

```
═══════════════════════════════════════════════════════════════
                    ALMED AHU SENSOR READINGS                   
═══════════════════════════════════════════════════════════════

📊 AIR QUALITY
───────────────────────────────────────
  AQI:          42 (Good)
  PM1.0:        5.2 µg/m³
  PM2.5:        10.1 µg/m³
  PM4.0:        12.3 µg/m³
  PM10.0:       14.5 µg/m³

🌡️ ENVIRONMENT
───────────────────────────────────────
  Temperature:  24.5 °C
  Humidity:     55.2 %RH

💨 GAS INDICES
───────────────────────────────────────
  VOC Index:    102
  NOx Index:    1
  CO2:          650 ppm

🔄 DIFFERENTIAL PRESSURE
───────────────────────────────────────
  Pressure:     12.45 Pa
  SDP Temp:     24.3 °C

═══════════════════════════════════════════════════════════════
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SEN66 not detected | Check SEL pin is floating (not connected) |
| SDP810 not detected | Verify I2C address 0x25 |
| Both not working | Check 3.3V power, not 5V |
| Erratic readings | Add 4.7kΩ pull-ups on SDA/SCL |
| I2C bus locked | Power cycle ESP32 |

---

## Notes

- Both sensors use **3.3V logic** - do NOT use 5V!
- SEN66 needs ~1.2 seconds warmup after reset
- SDP810 differential pressure range: ±500 Pa
- AQI calculation based on EPA PM2.5 breakpoints

