# Motor Safety & Adjustable Timings

## ✅ **Completed: ESP32 Side**

### 🛡️ **1. Emergency Motor Stop (SAFETY CRITICAL)**

**Problem Solved:**
- Motors were running indefinitely when WiFi failed or system crashed
- No automatic shutdown during failures

**Solution Implemented:**
```cpp
void emergencyStopMotors(){
  if (m1Active) { m1_stop(); }
  if (m2Active) { m2_stop(); }
  if (cpOn) { cpWrite(false); cpOn=false; }
  if (heatOn) { heatWrite(false); heatOn=false; }
}
```

**When It Triggers:**
- ✅ WiFi association error detected → **IMMEDIATE motor stop**
- ✅ WiFi offline for 15 seconds → **Motor stop before reset**
- ✅ Loop hang detected (>5s) → **Motor stop before reset**
- ✅ Watchdog timeout (7s) → **Motor stop before reset**

**Serial Monitor Output:**
```
⚠️ WiFi Association Error - IMMEDIATE RESET
⚠️ EMERGENCY: Motor-1 stopped (WiFi/system failure)
⚠️ EMERGENCY: Motor-2 stopped (WiFi/system failure)
⚠️ EMERGENCY: CP stopped
⚠️ EMERGENCY: Heater stopped
```

---

### ⚙️ **2. Adjustable Motor Timings**

**Problem Solved:**
- Motor timings were hardcoded (10s, 30s, etc.)
- Required code changes to adjust timings
- No way to tune for different hospital requirements

**Solution Implemented:**
```cpp
// Changed from const to variables
unsigned long M1_START_RUN = 10UL * 1000UL;   // Adjustable via Admin
unsigned long M1_POST_RUN  = 10UL * 1000UL;   // Adjustable via Admin
unsigned long M2_INTERVAL  = 30UL * 1000UL;   // Adjustable via Admin
unsigned long M2_RUN_TIME  = 10UL * 1000UL;   // Adjustable via Admin
unsigned long M2_DELAY_AFTER_M1_STOP = 5UL * 1000UL; // Adjustable via Admin
```

**MQTT Topic:**
```
almed/ahu/<site>/<room>/<ahu-id>/provision/motor_timings
```

**JSON Format:**
```json
{
  "m1_start": 7,      // Motor-1 start run time (seconds)
  "m1_post": 7,       // Motor-1 post run time (seconds)
  "m2_interval": 25,  // Motor-2 interval (seconds)
  "m2_run": 7,        // Motor-2 run time (seconds)
  "m2_delay": 3       // Delay after M1 stops (seconds)
}
```

**Example: Change M1 and M2 to run for 7 seconds:**
```bash
mosquitto_pub -h localhost -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/provision/motor_timings" \
  -m '{"m1_start":7,"m1_post":7,"m2_run":7}'
```

**Persistence:**
- Saved to ESP32 flash memory
- Loaded automatically on boot
- Survives power cycles and resets

**Serial Monitor Output:**
```
✓ Motor timings loaded:
  M1 Start: 7s
  M1 Post: 7s
  M2 Interval: 30s
  M2 Run: 7s
  M2 Delay: 5s
```

---

### 📡 **3. MQTT Integration**

**New Provisioning Topic:**
- `provision/motor_timings` - Set motor timings
- `provision/ack` - Acknowledgment response

**Subscription:**
ESP32 subscribes to motor timings topic on MQTT connect:
```cpp
mqtt.subscribe(tProvMotorTimings().c_str(), 1);
```

**Acknowledgment:**
```json
{
  "ok": true,
  "msg": "motor timings saved"
}
```

---

## 🚧 **TODO: Flutter Dashboard UI**

### **1. Admin Passcode Lock** (PENDING)

**Requirements:**
- Passcode entry screen before Admin UI
- Default passcode: `1234` (or configurable)
- Lock icon on login screen
- Passcode stored securely

**Flow:**
```
Login Screen
  └─> Select "Admin" role
       └─> Passcode Entry Dialog
            ├─> Correct → Admin Screen
            └─> Incorrect → Error message
```

**UI Design:**
- Numeric keypad (0-9)
- 4-digit passcode
- Show/hide toggle
- "Forgot passcode?" → Show hint or reset option

---

### **2. Motor Timings UI in Admin Screen** (PENDING)

**Location:** Admin Screen (after WiFi and Broker provisioning sections)

**UI Layout:**
```
┌─────────────────────────────────────────┐
│  Motor Timing Configuration             │
├─────────────────────────────────────────┤
│  Select AHU: [Dropdown]                 │
│                                          │
│  Motor-1 Start Run Time:  [7] seconds   │
│  Motor-1 Post Run Time:   [7] seconds   │
│  Motor-2 Interval:        [30] seconds  │
│  Motor-2 Run Time:        [7] seconds   │
│  Motor-2 Delay:           [5] seconds   │
│                                          │
│  [Reset to Defaults]  [Save Timings]    │
└─────────────────────────────────────────┘
```

**Features:**
- Number input fields (1-999 seconds)
- Real-time validation
- "Reset to Defaults" button (10, 10, 30, 10, 5)
- "Save Timings" button → Sends MQTT message
- Success/error snackbar feedback

**Code Structure:**
```dart
// Add to AdminScreen state
final _m1StartController = TextEditingController(text: '10');
final _m1PostController = TextEditingController(text: '10');
final _m2IntervalController = TextEditingController(text: '30');
final _m2RunController = TextEditingController(text: '10');
final _m2DelayController = TextEditingController(text: '5');

void _saveMotorTimings() {
  if (selectedAhuId == null) return;
  
  final provider = context.read<AppProvider>();
  provider.provisionMotorTimings(
    selectedAhuId!,
    m1Start: int.parse(_m1StartController.text),
    m1Post: int.parse(_m1PostController.text),
    m2Interval: int.parse(_m2IntervalController.text),
    m2Run: int.parse(_m2RunController.text),
    m2Delay: int.parse(_m2DelayController.text),
  );
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Motor timings saved!')),
  );
}
```

---

## 🎯 **Implementation Steps (Flutter UI)**

### **Step 1: Create Passcode Dialog**
```dart
// lib/widgets/passcode_dialog.dart
class PasscodeDialog extends StatefulWidget {
  final Function(bool) onResult;
  const PasscodeDialog({required this.onResult});
  
  @override
  State<PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<PasscodeDialog> {
  final _passcodeController = TextEditingController();
  static const String ADMIN_PASSCODE = '1234'; // TODO: Make configurable
  
  void _checkPasscode() {
    if (_passcodeController.text == ADMIN_PASSCODE) {
      widget.onResult(true);
      Navigator.pop(context);
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect passcode')),
      );
      _passcodeController.clear();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin Access'),
      content: TextField(
        controller: _passcodeController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        decoration: const InputDecoration(
          labelText: 'Enter Passcode',
          hintText: '••••',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _checkPasscode,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
```

### **Step 2: Update Login Screen**
```dart
// In login_screen.dart
void _selectRole(UserRole role) async {
  if (role == UserRole.admin) {
    // Show passcode dialog
    await showDialog(
      context: context,
      builder: (context) => PasscodeDialog(
        onResult: (success) {
          if (success) {
            _navigateToAdmin();
          }
        },
      ),
    );
  } else {
    _navigateToDashboard(role);
  }
}
```

### **Step 3: Add Motor Timings Section to Admin Screen**
```dart
// In admin_screen.dart, after broker provisioning section
_buildMotorTimingsSection(context, provider),

Widget _buildMotorTimingsSection(BuildContext context, AppProvider provider) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motor Timing Configuration',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        
        // M1 Start Run Time
        TextField(
          controller: _m1StartController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Motor-1 Start Run Time (seconds)',
            hintText: '10',
          ),
        ),
        const SizedBox(height: 16),
        
        // M1 Post Run Time
        TextField(
          controller: _m1PostController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Motor-1 Post Run Time (seconds)',
            hintText: '10',
          ),
        ),
        const SizedBox(height: 16),
        
        // M2 Interval
        TextField(
          controller: _m2IntervalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Motor-2 Interval (seconds)',
            hintText: '30',
          ),
        ),
        const SizedBox(height: 16),
        
        // M2 Run Time
        TextField(
          controller: _m2RunController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Motor-2 Run Time (seconds)',
            hintText: '10',
          ),
        ),
        const SizedBox(height: 16),
        
        // M2 Delay
        TextField(
          controller: _m2DelayController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Motor-2 Delay After M1 (seconds)',
            hintText: '5',
          ),
        ),
        const SizedBox(height: 24),
        
        // Buttons
        Row(
          children: [
            OutlinedButton(
              onPressed: _resetToDefaults,
              child: const Text('Reset to Defaults'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _saveMotorTimings,
              child: const Text('Save Timings'),
            ),
          ],
        ),
      ],
    ),
  );
}

void _resetToDefaults() {
  setState(() {
    _m1StartController.text = '10';
    _m1PostController.text = '10';
    _m2IntervalController.text = '30';
    _m2RunController.text = '10';
    _m2DelayController.text = '5';
  });
}

void _saveMotorTimings() {
  if (selectedAhuId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select an AHU first')),
    );
    return;
  }
  
  final provider = context.read<AppProvider>();
  provider.provisionMotorTimings(
    selectedAhuId!,
    m1Start: int.tryParse(_m1StartController.text),
    m1Post: int.tryParse(_m1PostController.text),
    m2Interval: int.tryParse(_m2IntervalController.text),
    m2Run: int.tryParse(_m2RunController.text),
    m2Delay: int.tryParse(_m2DelayController.text),
  );
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('✓ Motor timings saved!'),
      backgroundColor: Colors.green,
    ),
  );
}
```

---

## 📊 **Testing**

### **Test 1: Emergency Motor Stop**
1. Start system via dashboard
2. Turn on motors
3. Disconnect WiFi from ESP32
4. **Expected:** Motors stop within 15 seconds
5. **Serial Monitor:** Should show "EMERGENCY: Motor-X stopped"

### **Test 2: Motor Timing Adjustment**
1. Login as Admin (enter passcode)
2. Select AHU from dropdown
3. Change M1 Start Run Time to 7 seconds
4. Change M2 Run Time to 7 seconds
5. Click "Save Timings"
6. **Expected:** Success message
7. Restart ESP32
8. **Serial Monitor:** Should show "M1 Start: 7s" and "M2 Run: 7s"
9. Start system
10. **Expected:** Motors run for 7 seconds instead of 10

### **Test 3: Passcode Lock**
1. Go to login screen
2. Click "Admin" role
3. **Expected:** Passcode dialog appears
4. Enter wrong passcode (e.g., "0000")
5. **Expected:** Error message
6. Enter correct passcode ("1234")
7. **Expected:** Admin screen opens

---

## 🔐 **Security Notes**

### **Passcode Storage**
- Store passcode in `shared_preferences` (encrypted)
- Default: `1234`
- Allow Admin to change passcode in settings
- Hash passcode before storing

### **Admin Access Control**
- All provisioning methods check `UserRole.admin`
- Motor timings only accessible from Admin UI
- Hospital role cannot access motor timings

---

## 📝 **Summary**

### ✅ **Completed (ESP32)**
- Emergency motor stop on failures
- Adjustable motor timings via MQTT
- Persistent storage in flash
- MQTT provisioning topic
- Serial monitor feedback

### 🚧 **Pending (Flutter)**
- Admin passcode lock dialog
- Motor timings UI in Admin screen
- Passcode storage and management
- Input validation for timing values

### 🎯 **Benefits**
- ✅ **Safety:** Motors never run indefinitely during failures
- ✅ **Flexibility:** Timings adjustable without code changes
- ✅ **Security:** Admin functions protected by passcode
- ✅ **Persistence:** Settings survive power cycles
- ✅ **User-Friendly:** Hospital staff can't accidentally change motor timings

---

**Status:** ESP32 implementation complete ✅  
**Next:** Flutter UI for passcode lock + motor timings  
**Estimated Time:** ~2-3 hours for complete Flutter UI

