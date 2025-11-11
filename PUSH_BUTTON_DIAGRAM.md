# Push Button Wiring Diagram (Future Implementation)

## Overview
This diagram shows how to add a push button for standalone system control, replacing Serial Monitor commands.

## Circuit Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PUSH BUTTON CIRCUIT                                 │
│                    (For Standalone System Control)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────┐                                                  │
│  │   ESP32              │                                                  │
│  │                      │                                                  │
│  │  GPIO Pin (e.g. D4)  │                                                  │
│  │       │              │                                                  │
│  │       │              │                                                  │
│  │       ▼              │                                                  │
│  │  ┌─────────┐         │                                                  │
│  │  │ 10kΩ    │         │                                                  │
│  │  │ Pull-up │         │                                                  │
│  │  │ Resistor│         │                                                  │
│  │  └────┬────┘         │                                                  │
│  │       │              │                                                  │
│  │       ├──────────────┼──► GPIO Pin (D4) - INPUT_PULLUP                 │
│  │       │              │                                                  │
│  │       │              │                                                  │
│  │       ▼              │                                                  │
│  │  ┌─────────────┐     │                                                  │
│  │  │  Push       │     │                                                  │
│  │  │  Button     │     │                                                  │
│  │  │  (NO)       │     │                                                  │
│  │  └──────┬──────┘     │                                                  │
│  │         │            │                                                  │
│  │         │            │                                                  │
│  │         ▼            │                                                  │
│  │    GND ──────────────┼──► ESP32 GND                                     │
│  │                      │                                                  │
│  └──────────────────────┘                                                  │
│                                                                              │
│  Operation:                                                                 │
│    - Button NOT pressed: GPIO reads HIGH (via pull-up)                     │
│    - Button pressed: GPIO reads LOW (connected to GND)                      │
│    - Use INPUT_PULLUP mode (internal pull-up resistor)                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    ALTERNATIVE: EXTERNAL PULL-UP                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  3.3V ──┬──[10kΩ Resistor]──┬──► GPIO Pin (D4)                             │
│         │                    │                                               │
│         │                    │                                               │
│         │              ┌─────▼─────┐                                         │
│         │              │  Push     │                                         │
│         │              │  Button  │                                         │
│         │              │  (NO)     │                                         │
│         │              └─────┬─────┘                                         │
│         │                    │                                               │
│         │                    ▼                                               │
│         │                  GND                                               │
│         │                                                                     │
│         └──► Use this if you prefer external pull-up                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEBOUNCING CIRCUIT (Recommended)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  For reliable button operation, add debouncing:                             │
│                                                                              │
│  GPIO Pin (D4) ──┬──[10kΩ]──┬──► 3.3V (Pull-up)                            │
│                  │           │                                               │
│                  │           │                                               │
│                  │      ┌────▼────┐                                         │
│                  │      │  Push   │                                         │
│                  │      │  Button │                                         │
│                  │      └────┬────┘                                         │
│                  │           │                                               │
│                  │           ├──[100nF Capacitor]──► GND                    │
│                  │           │                                               │
│                  │           ▼                                               │
│                  │          GND                                              │
│                  │                                                           │
│  Note: Software debouncing is also recommended (see code example)           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Pin Assignment

| Component | ESP32 Pin | Function | Notes |
|-----------|-----------|----------|-------|
| Push Button | D4 (or any GPIO) | System Start/Stop Toggle | INPUT_PULLUP mode |
| Button GND | GND | Common Ground | Connect to ESP32 GND |

## Recommended GPIO Pins

- **D4** - Recommended (not used by current system)
- **D0** - Alternative option
- **D5** - Alternative option
- **Avoid**: D2 (PWM Fan), D18-D19, D21-D23, D32-D33 (already used)

## Component List

1. **Push Button (Momentary NO)**
   - Type: Normally Open (NO) momentary push button
   - Rating: Any low-voltage button (5V/12V rating sufficient)
   - Example: Tactile switch, panel mount button

2. **Pull-up Resistor (Optional if using INPUT_PULLUP)**
   - Value: 10kΩ
   - Type: 1/4W resistor
   - Note: ESP32 has internal pull-up, external not needed

3. **Debouncing Capacitor (Optional but recommended)**
   - Value: 100nF (0.1µF) ceramic capacitor
   - Voltage: 10V or higher

## Wiring Instructions

### Simple Wiring (Using Internal Pull-up):
```
1. Connect one terminal of push button to ESP32 GPIO pin (e.g., D4)
2. Connect other terminal of push button to ESP32 GND
3. In code: pinMode(D4, INPUT_PULLUP);
4. In code: Read button state with digitalRead(D4)
   - LOW = button pressed
   - HIGH = button not pressed
```

### With External Pull-up:
```
1. Connect 10kΩ resistor between 3.3V and GPIO pin (D4)
2. Connect one terminal of push button to GPIO pin (D4)
3. Connect other terminal of push button to GND
4. In code: pinMode(D4, INPUT);
5. In code: Read button state with digitalRead(D4)
   - LOW = button pressed
   - HIGH = button not pressed
```

## Code Integration (Future)

When implementing the push button, add this code structure:

```cpp
// ========== Push Button Configuration ==========
#define PIN_BUTTON 4  // GPIO pin for push button
bool lastButtonState = HIGH;
bool buttonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long DEBOUNCE_DELAY = 50;  // 50ms debounce

void setup() {
  // ... existing setup code ...
  
  // Push button setup
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  lastButtonState = digitalRead(PIN_BUTTON);
}

void loop() {
  // ... existing loop code ...
  
  // Read push button with debouncing
  handlePushButton();
  
  // ... rest of loop code ...
}

void handlePushButton() {
  int reading = digitalRead(PIN_BUTTON);
  
  // Debounce logic
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  
  if ((millis() - lastDebounceTime) > DEBOUNCE_DELAY) {
    if (reading != buttonState) {
      buttonState = reading;
      
      // Button pressed (LOW because of pull-up)
      if (buttonState == LOW) {
        Serial.println("🔘 Push button pressed - Toggling system");
        toggleSystem();  // Toggle system on/off
        delay(200);  // Prevent multiple toggles from single press
      }
    }
  }
  
  lastButtonState = reading;
}
```

## Button Behavior Options

### Option 1: Toggle Mode (Recommended)
- Single press: Toggle system ON/OFF
- Simple and intuitive
- Code: `toggleSystem()` on button press

### Option 2: Start/Stop Separate Buttons
- Two buttons: One for START, one for STOP
- More explicit control
- Requires 2 GPIO pins

### Option 3: Long Press Detection
- Short press: Toggle system
- Long press (2+ seconds): Emergency stop
- More advanced, requires timing logic

## Safety Considerations

1. **Emergency Stop**: Consider adding a separate emergency stop button (hardware interrupt)
2. **Button Placement**: Place button in accessible location for manual control
3. **Visual Feedback**: Add LED indicator to show system state (optional)
4. **Waterproof**: If button is exposed, use waterproof button enclosure

## Integration with Current System

The push button will work alongside:
- ✅ Serial Monitor commands (both work simultaneously)
- ✅ MQTT commands (when WiFi/MQTT connected)
- ✅ System state persistence (button state saved across reboots)

## Testing

1. **Without Button**: System works via Serial Monitor (current state)
2. **With Button**: 
   - Press button → System toggles ON/OFF
   - Serial commands still work
   - MQTT commands still work (when connected)
   - All control methods work independently

## Future Enhancements

1. **LED Status Indicator**: Add LED to show system ON/OFF state
2. **Button LED**: Illuminate button when system is running
3. **Multi-function Button**: 
   - Single press: Toggle system
   - Double press: Change fan speed
   - Long press: Emergency stop
4. **Remote Button**: Use wireless button (433MHz/2.4GHz) for remote control

## Notes

- **Current Implementation**: System controlled via Serial Monitor (`start`/`stop` commands)
- **Future Implementation**: Push button will be added using this diagram
- **No Code Changes Yet**: This diagram is for future reference only
- **Standalone Operation**: Button will work even without WiFi/MQTT

