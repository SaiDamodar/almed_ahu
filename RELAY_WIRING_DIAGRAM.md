# 5-Channel Relay Module Wiring Diagram with Stability Improvements

## Complete Relay Circuit Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        5-CHANNEL RELAY MODULE                               │
│                    (Active LOW: LOW=ON, HIGH=OFF)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                           │
│  │   ESP32      │                                                           │
│  │              │                                                           │
│  │  D32 ────────┼──┐                                                        │
│  │  D33 ────────┼──┼──┐                                                     │
│  │  D19 ────────┼──┼──┼──┐                                                  │
│  │  D23 ────────┼──┼──┼──┼──┐                                               │
│  │  D18 ────────┼──┼──┼──┼──┼──┐                                            │
│  │              │  │  │  │  │  │                                            │
│  │  GND ────────┼──┼──┼──┼──┼──┼──┐                                        │
│  └──────────────┘  │  │  │  │  │  │  │                                      │
│                    │  │  │  │  │  │  │                                      │
│                    ▼  ▼  ▼  ▼  ▼  ▼  ▼                                      │
│              ┌─────────────────────────────┐                                 │
│              │   ULN2803 (Optional)        │                                 │
│              │   Darlington Array          │                                 │
│              │                             │                                 │
│              │  IN1 ──► OUT1              │                                 │
│              │  IN2 ──► OUT2               │                                 │
│              │  IN3 ──► OUT3               │                                 │
│              │  IN4 ──► OUT4               │                                 │
│              │  IN5 ──► OUT5               │                                 │
│              │  GND ──► COMMON GND          │                                 │
│              │  VCC ──► 5V (XY3606)        │                                 │
│              └─────────────────────────────┘                                 │
│                    │  │  │  │  │  │  │                                      │
│                    ▼  ▼  ▼  ▼  ▼  ▼  ▼                                      │
│              ┌─────────────────────────────┐                                 │
│              │   RELAY MODULE              │                                 │
│              │                             │                                 │
│              │  IN1 ──► Relay 1 Coil       │                                 │
│              │  IN2 ──► Relay 2 Coil       │                                 │
│              │  IN3 ──► Relay 3 Coil       │                                 │
│              │  IN4 ──► Relay 4 Coil       │                                 │
│              │  IN5 ──► Relay 5 Coil       │                                 │
│              │                             │                                 │
│              │  VCC ──► 5V (XY3606)        │                                 │
│              │  GND ──► COMMON GND          │                                 │
│              └─────────────────────────────┘                                 │
│                    │  │  │  │  │                                             │
│                    ▼  ▼  ▼  ▼  ▼                                            │
│              ┌─────────────────────────────┐                                 │
│              │   RELAY CONTACTS            │                                 │
│              │                             │                                 │
│              │  Relay 1: COM ──► NO ──►   │                                 │
│              │  Relay 2: COM ──► NO ──►   │                                 │
│              │  Relay 3: COM ──► NO ──►   │                                 │
│              │  Relay 4: COM ──► NO ──►   │                                 │
│              │  Relay 5: COM ──► NO ──►   │                                 │
│              └─────────────────────────────┘                                 │
│                    │  │  │  │  │                                             │
│                    ▼  ▼  ▼  ▼  ▼                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         DC MOTOR CONNECTIONS (12V)                          │
│                    Relay 1 & 2 (COM1, COM2)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  12V SMPS (+) ──┬─[FUSE 5A]─┬─► Relay 1 COM                                 │
│                  │            │                                              │
│                  │            └─► Relay 2 COM                               │
│                  │                                                           │
│                  └─[470µF Electrolytic]                                     │
│                  └─[0.1µF Ceramic]                                          │
│                                                                              │
│  Relay 1 NO ──┬─► Motor 1 (+)                                               │
│               │                                                              │
│  Relay 2 NO ──┼─► Motor 2 (+)                                               │
│               │                                                              │
│               │  ┌─────────────────────┐                                   │
│               │  │   FLYBACK DIODES     │                                   │
│               │  │                      │                                   │
│               │  │  Motor 1:           │                                   │
│               │  │  [1N4007]           │                                   │
│               │  │  Cathode ──► +12V   │                                   │
│               │  │  Anode ──► GND      │                                   │
│               │  │                      │                                   │
│               │  │  Motor 2:           │                                   │
│               │  │  [1N4007]           │                                   │
│               │  │  Cathode ──► +12V   │                                   │
│               │  │  Anode ──► GND      │                                   │
│               │  └─────────────────────┘                                   │
│               │                                                              │
│  Motor 1 (-) ──┼─► COMMON GND                                                │
│  Motor 2 (-) ──┘                                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    AC LOAD CONNECTIONS (220V)                               │
│              Relay 3, 4, 5 (COM3, COM4, COM5)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  220V AC (L) ──┬─[CIRCUIT BREAKER 10A]─┬─► Relay 3 COM                      │
│                │                        ├─► Relay 4 COM                      │
│                │                        └─► Relay 5 COM                      │
│                │                                                             │
│                └─[MOV 275V]─► 220V AC (N)                                    │
│                                                                              │
│  Relay 3 NO ──┬─[RC SNUBBER]─┬─► Heater (220V AC)                           │
│               │  100Ω + 0.1µF │                                              │
│               │               └─► 220V AC (N)                                │
│               │                                                              │
│  Relay 4 NO ──┬─[RC SNUBBER]─┬─► CP Compressor (220V AC)                    │
│               │  100Ω + 0.1µF │                                              │
│               │               └─► 220V AC (N)                                │
│               │                                                              │
│  Relay 5 NO ──┬─[RC SNUBBER]─┬─► System Master (220V AC)                    │
│               │  100Ω + 0.1µF │                                              │
│               │               └─► 220V AC (N)                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         POWER SUPPLY CONNECTIONS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  12V SMPS:                                                                   │
│    V+ ──► Relay COM1, COM2 (12V DC)                                          │
│    V+ ──► XY3606 VIN+                                                        │
│    V- ──► COMMON GND                                                          │
│                                                                              │
│  XY3606 (DC-DC Buck Converter):                                             │
│    VIN+ ──► 12V SMPS V+                                                      │
│    VIN- ──► COMMON GND                                                       │
│    VOUT+ ──► 5V ──┬─► Relay Module VCC                                       │
│                   ├─► ULN2803 VCC (if used)                                 │
│                   └─► ESP32 VIN (if needed)                                  │
│    VOUT- ──► COMMON GND                                                       │
│                                                                              │
│  ESP32 Power:                                                                │
│    USB ──► ESP32 (for programming/testing)                                 │
│    OR                                                                         │
│    XY3606 5V ──► ESP32 VIN (if using external power)                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         GROUNDING (STAR GROUND)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                    ┌─── COMMON GND POINT ───┐                              │
│                    │                         │                              │
│        ┌───────────┼──► ESP32 GND           │                              │
│        │           │                         │                              │
│        │           ├──► Relay Module GND      │                              │
│        │           │                         │                              │
│        │           ├──► ULN2803 GND           │                              │
│        │           │                         │                              │
│        │           ├──► 12V SMPS GND          │                              │
│        │           │                         │                              │
│        │           ├──► XY3606 GND            │                              │
│        │           │                         │                              │
│        │           ├──► Motor 1 GND           │                              │
│        │           │                         │                              │
│        │           ├──► Motor 2 GND           │                              │
│        │           │                         │                              │
│        │           ├──► SHT45 Sensor GND      │                              │
│        │           │                         │                              │
│        │           └──► PWM Converter GND      │                              │
│        │                                   │                              │
│        └──► All grounds connect to single point                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Pin Assignment Summary

| ESP32 Pin | Function | Relay Channel | Load | Voltage |
|-----------|----------|---------------|------|---------|
| D32       | Motor 1  | Relay 1 (IN1) | Motor 1 (12V DC) | 12V DC |
| D33       | Motor 2  | Relay 2 (IN2) | Motor 2 (12V DC) | 12V DC |
| D19       | Heater   | Relay 3 (IN3) | Heater (220V AC) | 220V AC |
| D23       | CP       | Relay 4 (IN4) | Compressor (220V AC) | 220V AC |
| D18       | System   | Relay 5 (IN5) | System Master (220V AC) | 220V AC |

## Component List for Stability

### Critical Components:
1. **Flyback Diodes (1N4007)** - 2x for Motor 1 & 2
2. **Decoupling Capacitors**:
   - 470µF electrolytic at 12V SMPS output
   - 100µF + 0.1µF at ESP32 VCC/GND
   - 0.1µF at XY3606 output
3. **Fuse 5A** - On 12V SMPS output
4. **Circuit Breaker 10A** - On 220V AC input

### Recommended Components:
5. **ULN2803** - Darlington array for relay isolation (optional but recommended)
6. **RC Snubber Circuits** - 3x (100Ω + 0.1µF) for AC relays
7. **MOV 275V** - Metal Oxide Varistor for AC surge protection

## Wiring Notes

### Relay Control Logic:
- **Active LOW**: ESP32 sends `LOW` (0V) to turn relay ON
- **Active LOW**: ESP32 sends `HIGH` (3.3V) to turn relay OFF
- ULN2803 inverts: ESP32 HIGH → ULN2803 LOW → Relay ON

### Flyback Diode Connection:
```
Motor +12V ──► [Diode Cathode] ──► [Diode Anode] ──► Motor GND
```
When motor turns OFF, back-EMF current flows through diode, protecting ESP32.

### RC Snubber Connection:
```
Relay NO ──► [Resistor 100Ω] ──┬─► Load
                                │
                                └─► [Capacitor 0.1µF] ──► Relay COM
```

### Star Grounding:
- All ground connections meet at ONE physical point
- Prevents ground loops and voltage differences
- Use thick wire/PCB trace for COMMON GND

## Safety Warnings

⚠️ **220V AC WIRING:**
- Always disconnect power before wiring
- Use proper wire gauge for AC loads (14 AWG minimum)
- Ensure proper insulation
- Test with multimeter before powering on

⚠️ **12V DC WIRING:**
- Polarity matters - check before connecting
- Fuse protects against overcurrent
- Flyback diodes MUST be correctly oriented

⚠️ **Relay Module:**
- Verify Active LOW vs Active HIGH before wiring
- Check relay contact ratings (current/voltage)
- Ensure relay module can handle AC loads safely

## Testing Sequence

1. **Test without loads:**
   - Connect relay module to ESP32
   - Test each relay with multimeter (should click when activated)
   - Verify Active LOW behavior

2. **Test DC motors:**
   - Add flyback diodes
   - Connect one motor at a time
   - Test start/stop cycles
   - Monitor ESP32 for brownouts

3. **Test AC loads (with caution):**
   - Add snubber circuits
   - Add MOV protection
   - Test with low-power AC device first
   - Gradually test higher power loads

4. **Full system test:**
   - Test all relays simultaneously
   - Monitor power supply voltage
   - Check for EMI/noise issues
   - Verify ESP32 stability

