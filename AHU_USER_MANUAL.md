# ALMED AHU System - User Manual for Hospital Staff

## 👋 Welcome!

This manual is designed for **hospital staff who are new to the AHU system**. It contains detailed, step-by-step instructions for every operation you'll need to perform. Read through it once, and keep it handy for reference.

**If you're using this system for the first time**, start at the beginning and follow each section in order. You'll find detailed instructions for every button, every screen, and every action you need to take.

---

## 📖 What is the AHU System?

The **AHU (Air Handling Unit)** system is an intelligent air conditioning controller that helps maintain comfortable temperature and humidity levels in hospital rooms. It automatically controls cooling, heating, and air circulation to keep the environment optimal for patients and staff.

**Think of it as:**
- A **smart thermostat** that controls both temperature AND humidity
- An **automatic air quality manager** that keeps conditions perfect
- A **touchscreen control panel** that makes everything easy to use

You don't need to be a technician - the system does all the complex work automatically. You just need to set your preferences and monitor the results.

---

## 🎯 What Does It Do?

The AHU system:

- **Monitors** room temperature and humidity in real-time
- **Controls cooling** when it gets too hot
- **Controls heating and dehumidification** when it gets too humid
- **Circulates air** through a fan at adjustable speeds
- **Operates automatic drain and filter motors** to keep the system clean
- **Displays everything** on an easy-to-use touchscreen dashboard

---

## 🖥️ How the Dashboard Works

### **FIRST TIME - Getting Started (Step-by-Step)**

#### **Step 1: Turn On the System**

1. **Locate the touchscreen display** - This is typically mounted on the wall or placed on a desk near the AHU unit
2. **Press the power button** on the display (if there is one) OR the system may already be on
3. **Wait for the screen to load** - You'll see a welcome screen with the ALMED logo

#### **Step 2: Login Screen - Select Your Role**

You will see a login screen with **TWO large buttons**:

**What you'll see:**
- **ALMED  ** at the top
- **"Hospital Air Handling System"** text below the logo
- **Two role selection cards:**

  1. **HOSPITAL** button (usually blue)
     - Icon: Hospital symbol (🏥)
     - **USE THIS** for normal daily operations
     - **No password required**
   
  2. **ADMIN** button (usually lighter blue/gray)
     - Icon: Shield symbol (🛡️)
     - **USE THIS** only for advanced settings (requires passcode: 1234)
     - **Regular staff should NOT use this**

**What to do:**
1. **Tap the "HOSPITAL" button** (the one with the hospital icon)
2. **Wait for connection** - You'll see a loading message "Connecting to MQTT broker..."
3. **If connection succeeds** - The screen will automatically show the main dashboard

**Troubleshooting:**
- **If you see "Connection Failed"** - Contact technical support immediately
- **If the screen is black** - Check if the display is powered on
- **If buttons don't respond** - Gently tap again, the screen may need a moment

---

### **Main Dashboard View**

After logging in, you'll see the main dashboard screen:

**What you'll see:**
- **Top bar** with:
  - ALMED logo on the left
  - "Dashboard" title in the center
  - Your user role indicator (Hospital or Admin)
  - Connection status dot (🟢 green = connected, 🔴 red = disconnected)

- **AHU Unit Cards** in the center:
  - Each card shows one AHU unit
  - **Card displays:**
    - **AHU name** at the top (e.g., "AHU-01")
    - **Current temperature** (large number, e.g., "25.5°C") in orange/red color
    - **Current humidity** (large number, e.g., "52%") in blue color
    - **System status**: "RUNNING" (green) or "STOPPED" (gray)
    - **Connection indicator**: Small colored dot (green = online, red = offline)
    - **Location**: Shows hospital site and room (e.g., "hospitalA / icu1")

**How to use:**
1. **Look for your AHU unit** - Find the card that matches your room/unit
2. **Check the connection status** - Make sure there's a green dot (not red)
3. **Tap on the card** - This opens the control screen for that AHU unit

**Important Notes:**
- If you see **red dots**, the AHU unit is not connected - contact technical support
- If you don't see your AHU unit card, it may not be configured yet - contact technical support
- You can **scroll** if there are multiple AHU units listed

---

## 🎛️ How to Control the AHU Unit

When you tap on an AHU unit card, you'll see the control screen with the following sections:

### 1. **Temperature & Humidity Display**

#### **Visual Layout:**

At the top of the control screen, you'll see **TWO boxes side-by-side**:

**LEFT BOX - Temperature:**
- **Icon**: Thermostat symbol (🌡️) in orange/red color
- **Label**: "Temperature" text below icon
- **Large number**: Current target temperature (e.g., "22.0°C")
  - This is the **SETPOINT** (what you want the room to be)
- **Below the number**: Two buttons:
  - **Minus button (➖)** on the left - Tap to decrease temperature
  - **Plus button (➕)** on the right - Tap to increase temperature

**RIGHT BOX - Humidity:**
- **Icon**: Water drop symbol (💧) in blue color
- **Label**: "Humidity" text below icon
- **Large number**: Current target humidity (e.g., "55.0%")
  - This is the **SETPOINT** (what you want the room to be)
- **Below the number**: Two buttons:
  - **Minus button (➖)** on the left - Tap to decrease humidity
  - **Plus button (➕)** on the right - Tap to increase humidity

**Below these boxes**, you'll see the **ACTUAL READINGS**:
- **Temperature**: Large number showing current room temperature (orange/red)
- **Humidity**: Large number showing current room humidity (blue)

#### **DETAILED STEP-BY-STEP: Setting Temperature**

**To INCREASE temperature:**
1. **Locate the Temperature box** (left side, orange/red icon)
2. **Find the Plus button (➕)** - It's the circular button on the right side
3. **Tap the Plus button once** - Temperature increases by 0.5°C
4. **Watch the number** - It will update (e.g., 22.0°C → 22.5°C)
5. **Continue tapping** - Each tap increases by 0.5°C
6. **Maximum**: 30.0°C (button becomes disabled at maximum)

**To DECREASE temperature:**
1. **Locate the Temperature box** (left side, orange/red icon)
2. **Find the Minus button (➖)** - It's the circular button on the left side
3. **Tap the Minus button once** - Temperature decreases by 0.5°C
4. **Watch the number** - It will update (e.g., 22.0°C → 21.5°C)
5. **Continue tapping** - Each tap decreases by 0.5°C
6. **Minimum**: 15.0°C (button becomes disabled at minimum)

**Example - Setting temperature to 23°C:**
- Current setpoint: 22.0°C
- Tap Plus button: 22.5°C
- Tap Plus button: 23.0°C ✓ (Done!)

**Important Notes:**
- Changes take effect **immediately** - the system starts working right away
- The **actual temperature** (shown below) will gradually move toward your setpoint
- **Wait 10-15 minutes** before adjusting again - let the system respond
- **Recommended**: 22-24°C for hospital rooms

#### **DETAILED STEP-BY-STEP: Setting Humidity**

**To INCREASE humidity:**
1. **Locate the Humidity box** (right side, blue icon)
2. **Find the Plus button (➕)** - It's the circular button on the right side
3. **Tap the Plus button once** - Humidity increases by 0.5%
4. **Watch the number** - It will update (e.g., 55.0% → 55.5%)
5. **Continue tapping** - Each tap increases by 0.5%
6. **Maximum**: 80.0% (button becomes disabled at maximum)

**To DECREASE humidity:**
1. **Locate the Humidity box** (right side, blue icon)
2. **Find the Minus button (➖)** - It's the circular button on the left side
3. **Tap the Minus button once** - Humidity decreases by 0.5%
4. **Watch the number** - It will update (e.g., 55.0% → 54.5%)
5. **Continue tapping** - Each tap decreases by 0.5%
6. **Minimum**: 30.0% (button becomes disabled at minimum)

**Example - Setting humidity to 52%:**
- Current setpoint: 55.0%
- Tap Minus button: 54.5%
- Tap Minus button: 54.0%
- Tap Minus button: 53.5%
- Tap Minus button: 53.0%
- Tap Minus button: 52.5%
- Tap Minus button: 52.0% ✓ (Done!)

**Important Notes:**
- Changes take effect **immediately**
- The **actual humidity** (shown below) will gradually move toward your setpoint
- **Wait 10-15 minutes** before adjusting again
- **Recommended**: 50-55% for hospital environments

#### **Understanding the Display:**

**SETPOINT vs ACTUAL:**
- **Setpoint** (in the boxes above) = What you WANT (your target)
- **Actual** (displayed below) = What the room ACTUALLY is right now
- **Goal**: The system works to make the actual match the setpoint

**Example:**
- Setpoint: 22.0°C (what you set)
- Actual: 25.5°C (what the room currently is)
- **Result**: System will turn ON cooling to bring 25.5°C down toward 22.0°C

---

### 2. **System ON/OFF Control**

#### **Visual Layout:**

**Location**: At the very top of the control screen, below the top bar

**What you'll see:**
- **One large button** that changes color and text:
  - **When OFF**: Green button with ▶️ play icon and "START SYSTEM" text
  - **When ON**: Red button with ⏹️ stop icon and "STOP SYSTEM" text
- **Button size**: Very large (easy to tap, about 80 pixels tall)

#### **DETAILED STEP-BY-STEP: Starting the System**

**Prerequisites (Check before starting):**
1. ✅ Make sure you've set your desired temperature (see section above)
2. ✅ Make sure you've set your desired humidity (see section above)
3. ✅ Check connection status - should show green dot (not red)

**Step-by-Step Instructions:**

1. **Locate the START button**
   - Look at the top of the control screen
   - You'll see a **large GREEN button** with "START SYSTEM" text
   - There's a play arrow icon (▶️) on the left side of the button

2. **Tap the START button**
   - **Single tap** - Don't tap multiple times, once is enough
   - The button will become disabled briefly (you can't tap it again for a moment)

3. **Wait for system initialization (10-15 seconds)**
   - You'll see the button change from "START SYSTEM" to "STOP SYSTEM"
   - The button color changes from green to red
   - Status indicators will start updating

4. **Watch for startup sequence:**
   - **Motor 1 (M1)** indicator will turn green briefly (drain cleaning)
   - **Fan** will start running (you may hear it or see it in status)
   - **Motor 2 (M2)** indicator will turn green briefly (filter cleaning)
   - **System status** will show "RUNNING" in green

5. **System is now running!**
   - The system will now automatically:
     - Maintain your temperature setpoint
     - Maintain your humidity setpoint
     - Run cleaning cycles automatically

**What you'll notice:**
- Button text changes to "STOP SYSTEM" (red color)
- Temperature and humidity will gradually move toward your setpoints
- Status indicators will show which components are active

**If nothing happens:**
- Check if connection dot is green (not red) - if red, contact support
- Wait a few more seconds - system may be processing
- Tap the button once more if it's still green

#### **DETAILED STEP-BY-STEP: Stopping the System**

1. **Locate the STOP button**
   - Look at the top of the control screen
   - You'll see a **large RED button** with "STOP SYSTEM" text
   - There's a stop icon (⏹️) on the left side

2. **Tap the STOP button**
   - **Single tap** - Once is enough
   - Don't tap multiple times

3. **Wait for shutdown cycle (20-30 seconds)**
   - System performs automatic cleaning:
     - Motor 1 (M1) will run for final drain cleaning
     - Motor 2 (M2) will run for final filter cleaning
   - You'll see status indicators change

4. **System stops**
   - Button changes to "START SYSTEM" (green color)
   - All components turn OFF
   - Status shows "STOPPED" in gray
   - System is safe to leave

**Important Notes:**
- **Always wait** for the shutdown cycle to complete (20-30 seconds)
- **Don't unplug power** during shutdown - let it finish
- System is designed to run continuously - you usually don't need to stop it
- **Never start and stop rapidly** - allow at least 1-2 minutes between operations

---

### 3. **Fan Speed Control**

#### **Visual Layout:**

**Location**: Below the temperature/humidity controls, in a separate section

**What you'll see:**
- **Section header**: "Fan Control" with an air/fan icon (💨) in green
- **Current status**: Text showing "Current: OFF" or "Current: LOW (5V)" etc.
- **Four buttons in a row:**
  1. **OFF** - Gray button
  2. **LOW** - Light green button (shows "LOW")
  3. **MID** - Medium green button (shows "MID") 
  4. **HIGH** - Dark green button (shows "HIGH")
- **Active button**: The currently selected speed will be highlighted (brighter/green background)
- **Inactive buttons**: Gray background, can be tapped to change

#### **DETAILED STEP-BY-STEP: Changing Fan Speed**

**To set fan to LOW speed:**
1. **Locate the Fan Control section** - Look for the green air icon and "Fan Control" text
2. **Find the "LOW" button** - It's the second button from the left
3. **Check current speed** - Look at "Current:" text above the buttons
4. **If not already on LOW**: Tap the "LOW" button once
5. **Confirm change**: 
   - The "LOW" button will become highlighted/green
   - The "Current:" text will update to "Current: LOW (5V)"
   - You may hear/feel the fan speed change

**To set fan to MEDIUM (MID) speed:**
1. **Locate the Fan Control section**
2. **Find the "MID" button** - It's the third button from the left
3. **Tap the "MID" button once**
4. **Confirm change**:
   - "MID" button becomes highlighted
   - "Current:" text updates to "Current: MED (7V)"
   - Fan speed increases

**To set fan to HIGH speed:**
1. **Locate the Fan Control section**
2. **Find the "HIGH" button** - It's the rightmost button
3. **Tap the "HIGH" button once**
4. **Confirm change**:
   - "HIGH" button becomes highlighted
   - "Current:" text updates to "Current: HIGH (9V)"
   - Fan speed is at maximum

**To turn fan OFF:**
1. **Locate the Fan Control section**
2. **Find the "OFF" button** - It's the leftmost button (gray)
3. **Tap the "OFF" button once**
4. **Confirm change**:
   - "OFF" button becomes highlighted
   - "Current:" text updates to "Current: OFF"
   - Fan stops completely

**Understanding the speeds:**

| Speed | Voltage | When to Use | Sound Level | Air Movement |
|-------|---------|-------------|-------------|--------------|
| **OFF** | 0V | Fan completely off (not recommended when system is running) | Silent | None |
| **LOW** | 5V | Quiet operation needed, minimal air movement | Very quiet | Gentle |
| **MID** | 7V | **Normal daily operation (RECOMMENDED)** | Moderate | Good circulation |
| **HIGH** | 9V | Maximum ventilation, rapid temperature changes | Louder | Strong |

**Important Notes:**
- **Recommended setting**: MID (MED) for normal operation
- Changes take effect **immediately**
- **Keep fan ON** (not OFF) when system is running - it's needed for air circulation
- You can change fan speed **at any time**, even while system is running
- The currently selected speed will always be highlighted in green

---

### 4. **Component Status Display**

You can see the status of all system components:

- **Motor 1 (M1)**: Drain motor - automatically runs during startup and shutdown
- **Motor 2 (M2)**: Filter cleaning motor - runs automatically every 30 seconds when system is ON
- **CP (Compressor)**: Cooling unit - turns ON automatically when temperature is too high
- **Heater**: Dehumidifier/heater - turns ON automatically when humidity is too high
- **Fan**: Shows current speed (OFF/LOW/MED/HIGH)

**Note**: All status indicators show:
- 🟢 **Green** = Component is ON/Active
- ⚪ **Gray/White** = Component is OFF/Inactive

---

## 📱 COMPLETE OPERATING PROCEDURE - From Start to Finish

### **COMPLETE GUIDE: Starting and Operating the System**

Follow these steps **IN ORDER** for first-time setup or daily operation:

---

#### **STEP 1: Access the Dashboard**

1. **Turn on the touchscreen display** (if not already on)
2. **Wait for login screen** to appear (shows ALMED logo)
3. **Tap "HOSPITAL" button** (blue button with hospital icon)
4. **Wait for connection** - Screen shows "Connecting to MQTT broker..."
5. **Dashboard appears** - You'll see AHU unit cards

**Troubleshooting Step 1:**
- ❌ **Screen is black**: Check power connection
- ❌ **"Connection Failed" message**: Contact technical support
- ❌ **No AHU cards visible**: Contact technical support - unit may need configuration

---

#### **STEP 2: Select Your AHU Unit**

1. **Look at the dashboard** - Find the card for your AHU unit
2. **Identify your unit** by:
   - Unit name (e.g., "AHU-01")
   - Location shown (e.g., "hospitalA / icu1")
3. **Check connection status**:
   - 🟢 **Green dot** = Unit is connected (good - proceed)
   - 🔴 **Red dot** = Unit is disconnected (contact support - don't proceed)
4. **Tap on the AHU card** - Control screen opens

**What you'll see after tapping:**
- Control screen with all the controls
- Current temperature and humidity readings
- All buttons and status indicators

---

#### **STEP 3: Set Your Temperature Setpoint**

1. **Locate Temperature box** (left side, orange/red thermostat icon)
2. **Check current setpoint** - Look at the large number (e.g., "22.0°C")
3. **Decide your target** - Recommended: 22-24°C for hospital rooms
4. **Adjust if needed**:
   - **To INCREASE**: Tap the **Plus button (➕)** repeatedly
     - Each tap = +0.5°C
     - Example: To go from 22.0°C to 23.0°C = Tap Plus 2 times
   - **To DECREASE**: Tap the **Minus button (➖)** repeatedly
     - Each tap = -0.5°C
5. **Confirm your setting** - Number should show your desired temperature
6. **Double-check** - Make sure it's between 15°C and 30°C

**Example:**
- Current setpoint: 22.0°C
- Goal: 23.0°C
- Action: Tap Plus button 2 times
- Result: Shows 23.0°C ✓

---

#### **STEP 4: Set Your Humidity Setpoint**

1. **Locate Humidity box** (right side, blue water drop icon)
2. **Check current setpoint** - Look at the large number (e.g., "55.0%")
3. **Decide your target** - Recommended: 50-55% for hospital environments
4. **Adjust if needed**:
   - **To INCREASE**: Tap the **Plus button (➕)** repeatedly
     - Each tap = +0.5%
   - **To DECREASE**: Tap the **Minus button (➖)** repeatedly
     - Each tap = -0.5%
5. **Confirm your setting** - Number should show your desired humidity
6. **Double-check** - Make sure it's between 30% and 80%

**Example:**
- Current setpoint: 55.0%
- Goal: 52.0%
- Action: Tap Minus button 6 times
- Result: Shows 52.0% ✓

---

#### **STEP 5: Set Fan Speed**

1. **Locate Fan Control section** (below temperature/humidity, green air icon)
2. **Check current speed** - Look at "Current:" text
3. **Select appropriate speed**:
   - **Recommended**: Tap "MID" button (normal operation)
   - **Alternative**: Tap "LOW" (quieter) or "HIGH" (faster changes)
4. **Confirm selection** - The button you tapped should be highlighted in green
5. **Verify** - "Current:" text should show your selection (e.g., "Current: MED (7V)")

**Note**: Keep fan ON (not OFF) when system will be running

---

#### **STEP 6: Start the System**

1. **Review your settings**:
   - ✅ Temperature setpoint is correct (22-24°C recommended)
   - ✅ Humidity setpoint is correct (50-55% recommended)
   - ✅ Fan speed is set (MID recommended)
   - ✅ Connection dot is green (not red)

2. **Locate START button** (large green button at top, says "START SYSTEM")

3. **Tap START button once**
   - **Don't tap multiple times** - Once is enough
   - Button may become disabled briefly (this is normal)

4. **Wait 10-15 seconds** for initialization:
   - Button changes from green "START SYSTEM" to red "STOP SYSTEM"
   - You may see status indicators update
   - Motors may briefly activate (this is normal cleaning)

5. **Confirm system started**:
   - Button now shows red "STOP SYSTEM"
   - Status shows "RUNNING" (green text)
   - Fan should be running
   - Temperature/humidity will start moving toward setpoints

---

#### **STEP 7: Monitor and Verify**

**First 5 minutes:**
1. **Watch temperature reading**:
   - Should gradually move toward your setpoint
   - Don't expect instant change - give it time
2. **Watch humidity reading**:
   - Should gradually move toward your setpoint
   - May take 10-15 minutes to stabilize
3. **Check status indicators**:
   - CP (compressor) may turn ON/OFF automatically (normal)
   - Heater may turn ON/OFF automatically (normal)
   - Motors run automatically (normal - cleaning cycles)

**After 15-30 minutes:**
1. **Check if readings are approaching setpoints**
2. **Verify system is maintaining settings**
3. **If not working as expected**: See Troubleshooting section

---

#### **STEP 8: Daily Operation (Ongoing)**

**System is now running and maintaining your settings automatically**

**What you need to do:**
- **Check periodically** - Look at the dashboard occasionally
- **Monitor readings** - Make sure temperature/humidity are near setpoints
- **Adjust if needed** - Change setpoints if conditions require it

**What the system does automatically:**
- ✅ Maintains temperature (turns cooling ON/OFF as needed)
- ✅ Maintains humidity (turns heating/dehumidifier ON/OFF as needed)
- ✅ Runs cleaning cycles (motors activate automatically)
- ✅ Manages fan speed (maintains your selected speed)

**When to adjust:**
- Change setpoints only if room conditions need different targets
- Change fan speed if air circulation needs adjustment
- Wait 10-15 minutes between adjustments - let system respond

---

### **Detailed Monitoring Guide**

#### **What to Monitor:**

**1. Temperature Readings:**
- **Current actual**: Shows what the room is RIGHT NOW (large number below setpoint)
- **Setpoint**: Shows what you WANT (number in the temperature box)
- **Goal**: Actual should be within 1-2°C of setpoint
- **Normal behavior**: 
  - If actual is above setpoint: System cools (CP turns ON)
  - If actual is below setpoint: System may heat or just maintain
  - Temperature changes slowly - expect 10-20 minutes to reach setpoint

**2. Humidity Readings:**
- **Current actual**: Shows current room humidity (large number below setpoint)
- **Setpoint**: Shows what you WANT (number in humidity box)
- **Goal**: Actual should be within 2-3% of setpoint
- **Normal behavior**:
  - If actual is above setpoint: System dehumidifies (Heater turns ON)
  - Humidity changes slowly - expect 15-30 minutes to reach setpoint

**3. Component Status Indicators:**

Watch these status indicators in the component status section:

- **Motor 1 (M1) - Drain Motor**:
  - 🟢 Green = Running (cleaning drain)
  - ⚪ Gray = Off
  - **Normal**: Runs during startup, shutdown, and periodically

- **Motor 2 (M2) - Filter Motor**:
  - 🟢 Green = Running (cleaning filter)
  - ⚪ Gray = Off
  - **Normal**: Runs automatically every 30 seconds when system is ON

- **CP (Compressor) - Cooling**:
  - 🟢 Green = ON (cooling active)
  - ⚪ Gray = Off
  - **Normal**: Turns ON when temperature exceeds setpoint by 1°C
  - **Cycling**: May turn ON/OFF frequently - this is normal

- **Heater - Dehumidifier**:
  - 🟢 Green = ON (dehumidifying/heating)
  - ⚪ Gray = Off
  - **Normal**: Turns ON when humidity exceeds setpoint by 3%
  - **Cycling**: May turn ON/OFF - this is normal

- **Fan**:
  - Shows current speed: OFF, LOW, MED, or HIGH
  - **Normal**: Should show your selected speed (usually MED)
  - **Should be ON** when system is running (not OFF)

#### **When to Be Concerned:**

🚨 **Contact support if:**
- Temperature doesn't change after 30+ minutes
- Humidity doesn't change after 45+ minutes
- Status shows "Disconnected" (red dot)
- Components show incorrect status
- Unusual sounds or errors appear

✅ **Normal behavior (don't worry):**
- CP turning ON/OFF frequently (maintaining temperature)
- Heater turning ON/OFF (maintaining humidity)
- Motors running periodically (automatic cleaning)
- Slow temperature/humidity changes (takes time to stabilize)

---

### **DETAILED STEP-BY-STEP: Stopping the System**

**When to stop:**
- End of day/shift (if required by hospital protocol)
- Maintenance required
- Room not in use for extended period
- **Note**: System is designed to run continuously - stopping is usually not necessary

**Step-by-Step Procedure:**

1. **Navigate to control screen**:
   - From dashboard, tap on your AHU unit card
   - Wait for control screen to load

2. **Locate STOP button**:
   - Look at top of screen
   - You'll see a **large RED button** with "STOP SYSTEM" text
   - Button has a stop icon (⏹️)

3. **Tap STOP button once**:
   - **Single tap** - Don't tap multiple times
   - Button may become disabled briefly (normal)

4. **Wait for shutdown cycle (20-30 seconds)**:
   - **DO NOT** tap anything else during this time
   - **DO NOT** turn off power
   - System performs automatic cleaning:
     - Motor 1 (M1) runs briefly (final drain cleaning)
     - Motor 2 (M2) runs briefly (final filter cleaning)
   - You'll see status indicators update

5. **Confirm shutdown complete**:
   - Button changes to green "START SYSTEM"
   - Status shows "STOPPED" (gray text)
   - All component indicators turn gray (OFF)
   - Fan stops

6. **System is now OFF**:
   - Safe to leave
   - Can restart anytime using START button
   - Settings are preserved - won't need to set again

**Important Safety Notes:**
- ⚠️ **Always wait** for complete shutdown (20-30 seconds)
- ⚠️ **Never unplug power** during shutdown
- ⚠️ **Never stop/start rapidly** - allow proper cycles

---

## 🔍 Understanding the Indicators

### **Connection Status**
- **🟢 Green dot** = System is connected and working normally
- **🔴 Red dot** = System is disconnected or having issues
  - If you see red, check with technical staff

### **Temperature & Humidity Colors**
- **Orange/Red** = Temperature display
- **Blue** = Humidity display
- **Large numbers** = Current actual readings
- **Small numbers** = Target setpoints (what you set)

### **System Status**
- **RUNNING** (green) = System is active
- **STOPPED** (gray) = System is off

---

## ⚙️ Automatic Features (No Action Needed)

The system automatically handles:

1. **Cooling Control**:
   - Turns cooling ON when temperature exceeds setpoint by 1°C
   - Turns cooling OFF when temperature drops below setpoint
   - Prevents rapid cycling with minimum on/off times

2. **Humidity Control**:
   - Turns heater/dehumidifier ON when humidity exceeds setpoint by 3%
   - Turns heater OFF when humidity drops below setpoint
   - Maintains optimal air quality

3. **Automatic Cleaning**:
   - **Motor 1** runs during system startup and shutdown
   - **Motor 2** runs automatically every 30 seconds when system is ON
   - Keeps drain and filters clean without manual intervention

4. **Fan Management**:
   - Fan automatically runs when system is ON
   - You can adjust speed, but fan stays on (unless set to OFF)
   - Fan automatically turns OFF when system stops

---

## ❓ Common Questions

### **Q: What temperature should I set?**
**A:** For hospital rooms, 22-24°C is recommended for patient comfort and medical equipment operation.

### **Q: What humidity should I set?**
**A:** 50-55% is ideal for hospital environments - prevents mold growth while maintaining patient comfort.

### **Q: Why does the compressor keep turning on and off?**
**A:** This is normal! The system automatically cycles the compressor to maintain your set temperature. It prevents the room from getting too hot or too cold.

### **Q: Can I leave the system running all day?**
**A:** Yes! The system is designed to run continuously. It will automatically maintain your settings.

### **Q: What if the system shows "Disconnected" (red)?**
**A:** Contact technical support. The AHU unit may have lost connection to the dashboard.

### **Q: Should I turn the system off at night?**
**A:** Generally, no. Continuous operation is recommended to maintain stable conditions. However, follow your hospital's specific protocols.

### **Q: How do I know if something is wrong?**
**A:** Warning signs:
- Temperature or humidity not changing after 30+ minutes
- System shows "Disconnected" (red indicator)
- Unusual noises (contact maintenance)
- Error messages on screen

---

## ⚠️ Important Notes

### **DO:**
- ✅ Set realistic temperature and humidity targets
- ✅ Monitor readings regularly
- ✅ Use MED fan speed for normal operation
- ✅ Keep the dashboard screen clean
- ✅ Report any issues to technical staff immediately

### **DON'T:**
- ❌ Set extreme temperatures (< 18°C or > 28°C)
- ❌ Change settings too frequently (wait 10-15 minutes between adjustments)
- ❌ Turn system on/off rapidly (allow proper startup/shutdown cycles)
- ❌ Ignore "Disconnected" warnings
- ❌ Attempt to fix hardware issues yourself

---

## 🆘 Troubleshooting Guide - Detailed Solutions

### **Problem 1: System Won't Start**

**Symptoms:**
- START button doesn't respond
- System doesn't initialize after tapping START
- Status stays at "STOPPED"

**Step-by-Step Troubleshooting:**

1. **Check Connection Status**:
   - Look at top of screen for connection dot
   - 🟢 **Green dot** = Connected (proceed to step 2)
   - 🔴 **Red dot** = Disconnected → **Contact technical support immediately**

2. **Verify Button Response**:
   - Tap START button once
   - Wait 5 seconds
   - If button changes to "STOP SYSTEM" (red) → System started successfully ✓
   - If nothing happens → Proceed to step 3

3. **Check Settings**:
   - Make sure temperature setpoint is set (15-30°C)
   - Make sure humidity setpoint is set (30-80%)
   - Make sure fan speed is selected (not left at OFF)

4. **Try Again**:
   - Wait 30 seconds
   - Tap START button once more
   - Wait 15 seconds

5. **If still not working**: Contact technical support with:
   - AHU unit name
   - Connection status (green/red dot)
   - Error messages (if any)

---

### **Problem 2: Temperature Not Changing**

**Symptoms:**
- Actual temperature stays the same
- Temperature doesn't move toward setpoint
- Room feels too hot/cold but reading doesn't change

**Step-by-Step Troubleshooting:**

1. **Check if system is running**:
   - Button should show red "STOP SYSTEM"
   - Status should show "RUNNING" (green)
   - If not running → Start the system first

2. **Check fan speed**:
   - Fan should NOT be OFF
   - Set fan to MED or HIGH
   - Fan is needed for air circulation

3. **Check setpoint**:
   - Current setpoint should be reasonable (22-24°C recommended)
   - If room is 25°C and setpoint is 25°C → System won't change (already at target)
   - **Solution**: Set setpoint 2-3°C away from current temperature

4. **Check time elapsed**:
   - Temperature changes SLOWLY
   - Wait at least **15-20 minutes** after starting system
   - Changes may take 30-60 minutes depending on room size

5. **Check CP (Compressor) status**:
   - CP should turn ON (green) if temperature is above setpoint
   - If CP never turns ON → May indicate issue → Contact support

6. **Verify connection**:
   - Connection dot should be green (not red)
   - If red → Contact support

**If still not working**: Contact technical support

---

### **Problem 3: Room Too Hot or Too Cold**

**Symptoms:**
- Room feels uncomfortable
- Temperature is not at desired level
- Actual temperature is far from setpoint

**Solutions:**

**If room is TOO HOT:**
1. **Check current setpoint** - Look at temperature box
2. **Lower the setpoint**:
   - Tap Minus button (➖) several times
   - Lower by 1-2°C
   - Example: If 24°C, try 22-23°C
3. **Increase fan speed** to HIGH (faster cooling)
4. **Wait 15-20 minutes** for temperature to drop
5. **Verify CP is turning ON** (green indicator)

**If room is TOO COLD:**
1. **Check current setpoint** - Look at temperature box
2. **Raise the setpoint**:
   - Tap Plus button (➕) several times
   - Raise by 1-2°C
   - Example: If 20°C, try 22-23°C
3. **Wait 15-20 minutes** for temperature to rise
4. **Note**: System primarily cools - heating may be limited

---

### **Problem 4: Humidity Too High or Too Low**

**Symptoms:**
- Room feels too humid or too dry
- Humidity reading not at desired level

**Solutions:**

**If humidity is TOO HIGH:**
1. **Check current setpoint** - Look at humidity box
2. **Lower the setpoint**:
   - Tap Minus button (➖) several times
   - Lower by 2-3%
   - Recommended: 50-52%
3. **Verify Heater indicator**:
   - Should turn ON (green) when humidity exceeds setpoint
   - Heater acts as dehumidifier
4. **Wait 20-30 minutes** - Humidity changes slowly

**If humidity is TOO LOW:**
1. **Check current setpoint** - Look at humidity box
2. **Raise the setpoint**:
   - Tap Plus button (➕) several times
   - Raise by 2-3%
   - Recommended: 50-55%
3. **Wait 20-30 minutes** - System will adjust

---

### **Problem 5: Fan Not Working**

**Symptoms:**
- Fan doesn't respond to speed changes
- Fan speed stays the same
- No air movement

**Step-by-Step Troubleshooting:**

1. **Check if system is running**:
   - System must be RUNNING for fan to work
   - If stopped → Start system first

2. **Check current fan setting**:
   - Look at "Current:" text in Fan Control section
   - Make sure it's not stuck on OFF

3. **Try changing speed**:
   - Tap a different speed button (LOW, MID, or HIGH)
   - Wait 2-3 seconds
   - Check if "Current:" text updates

4. **Verify connection**:
   - Connection dot should be green
   - If red → Contact support

5. **If fan is stuck on OFF**:
   - Tap LOW, MID, or HIGH button
   - Should change from OFF to selected speed
   - If not → Contact support

---

### **Problem 6: Connection Lost (Red Dot)**

**Symptoms:**
- Connection indicator shows red dot
- "Disconnected" status
- Can't control system

**What to do:**

1. **Don't panic** - This is a communication issue, not a system failure
2. **Wait 30 seconds** - Connection may recover automatically
3. **Check if system is physically running**:
   - If AHU unit is still working (you can hear/feel it) → System may still be functioning
4. **Contact technical support immediately**:
   - Report: "Connection lost - red dot showing"
   - Provide: AHU unit name/number
   - System may need network troubleshooting

**DO NOT:**
- ❌ Try to fix network settings yourself
- ❌ Unplug or restart equipment without approval
- ❌ Continue operating if red dot persists

---

### **Problem 7: Buttons Not Responding**

**Symptoms:**
- Tapping buttons doesn't do anything
- Screen doesn't respond to touch
- Buttons appear disabled

**Solutions:**

1. **Wait 2-3 seconds** - System may be processing
2. **Try tapping again** - May have been a missed tap
3. **Check connection**:
   - If red dot → Connection issue → Contact support
4. **Verify system status**:
   - If disconnected (red), buttons will be disabled
   - Need connection restored first
5. **Screen may need restart** - Contact technical support

---

### **Quick Reference Troubleshooting Table**

| Problem | Quick Check | Solution |
|---------|-------------|----------|
| **System won't start** | Connection dot green? | If red → Contact support. If green → Check settings, try again |
| **Temperature not changing** | Fan OFF? System running? | Set fan to MED/HIGH. Wait 15-20 min. Check CP indicator |
| **Too hot** | Current setpoint? | Lower setpoint 1-2°C. Increase fan to HIGH |
| **Too cold** | Current setpoint? | Raise setpoint 1-2°C. Wait 15-20 min |
| **Too humid** | Current setpoint? | Lower humidity 2-3%. Check Heater indicator |
| **Too dry** | Current setpoint? | Raise humidity 2-3%. Wait 20-30 min |
| **Fan not working** | System running? | System must be ON. Change speed button |
| **Connection lost** | Red dot showing? | Wait 30 sec. Contact support if persists |
| **Buttons not responding** | Connection status? | Check green dot. Wait, try again |

---

## 📞 Getting Help

If you encounter issues:

1. **Check this manual** first
2. **Note the error message** (if any) on the dashboard
3. **Contact technical support** with:
   - AHU unit name/number
   - What you were trying to do
   - What error or problem you're seeing
   - Current temperature and humidity readings

---

## 📋 Quick Reference Checklist - Daily Operation

### **Starting Your Shift:**

- [ ] Turn on touchscreen display
- [ ] Login: Tap "HOSPITAL" button
- [ ] Wait for dashboard to load
- [ ] Check connection: Green dot visible (not red)
- [ ] Select your AHU unit card
- [ ] Check current temperature and humidity readings

### **Setting Up System:**

- [ ] Set temperature: Use ➕/➖ buttons (target: 22-24°C)
- [ ] Set humidity: Use ➕/➖ buttons (target: 50-55%)
- [ ] Set fan speed: Tap "MID" button (recommended)
- [ ] Verify all settings are correct

### **Starting System:**

- [ ] Tap green "START SYSTEM" button
- [ ] Wait 10-15 seconds for initialization
- [ ] Confirm button changed to red "STOP SYSTEM"
- [ ] Confirm status shows "RUNNING" (green)

### **During Operation:**

- [ ] Check readings every 1-2 hours
- [ ] Verify temperature is near setpoint (±2°C)
- [ ] Verify humidity is near setpoint (±3%)
- [ ] Check connection dot is still green
- [ ] Report any issues immediately

### **End of Shift:**

- [ ] Check if system should remain running (usually yes)
- [ ] If stopping: Tap red "STOP SYSTEM" button
- [ ] Wait 20-30 seconds for shutdown cycle
- [ ] Confirm system stopped safely

---

## 🎓 Summary - What You Need to Remember

### **The Three Main Actions:**

1. **SET** your desired temperature and humidity using the ➕/➖ buttons
2. **SELECT** fan speed (MID recommended for normal use)
3. **START** the system by tapping the green START button

### **The System Does Everything Else Automatically:**

✅ Maintains your temperature setpoint (turns cooling ON/OFF)
✅ Maintains your humidity setpoint (turns dehumidifier ON/OFF)
✅ Runs cleaning cycles automatically (motors activate periodically)
✅ Manages all components (you don't need to control individual parts)

### **Key Numbers to Remember:**

- **Temperature**: 22-24°C (ideal for hospital rooms)
- **Humidity**: 50-55% (ideal for hospital environments)
- **Fan Speed**: MID (recommended for normal operation)
- **Wait Time**: 15-20 minutes after starting/changing settings before expecting results

### **When in Doubt:**

1. ✅ **Check this manual** first
2. ✅ **Verify connection** - Green dot = good, Red dot = problem
3. ✅ **Wait for system** - Changes take time (15-20 minutes)
4. ✅ **Contact support** - If unsure or if problems persist

### **Remember:**

- **Simple = Good**: The system is designed to be easy to use
- **Automatic = Normal**: Components turn ON/OFF automatically - this is correct
- **Slow = Expected**: Temperature/humidity changes take time
- **Green = Good**: Green connection dot means everything is working
- **Red = Problem**: Red connection dot means contact support

---

The system handles all the complex operations automatically - cooling, heating, cleaning, and maintaining optimal conditions. You just set your preferences and monitor the results!

---

**Last Updated:** 2024  
**Version:** 2.0  
**For Hospital Staff Use**

