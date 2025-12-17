/*
 * SDP810 Differential Pressure Sensor - HEPA Filter Monitor
 * 
 * This sensor measures the pressure drop across the HEPA filter
 * to determine the filter's condition and health.
 * 
 * HEPA Filter Status Thresholds:
 *   < 9 Pa    → Weak airflow / Leak detected
 *   9-25 Pa   → Normal HEPA condition
 *   25-40 Pa  → Filter clogging (schedule replacement)
 *   > 40 Pa   → HEPA replacement required immediately
 * 
 * Library: Sensirion I2C SDP
 * https://github.com/Sensirion/arduino-i2c-sdp
 */

#include <Arduino.h>
#include <SensirionI2CSdp.h>
#include <Wire.h>

// ========== CONFIGURATION ==========
#define SERIAL_BAUD      115200
#define READ_INTERVAL_MS 2000
#define I2C_SDA          21
#define I2C_SCL          22

// HEPA Filter Pressure Thresholds (Pa)
#define HEPA_MIN_NORMAL     9.0    // Below this = leak/weak airflow
#define HEPA_MAX_NORMAL     25.0   // Above this = clogging starts
#define HEPA_REPLACE_THRESHOLD 40.0 // Above this = replace immediately

// ========== SENSOR OBJECT ==========
SensirionI2CSdp sdp;

static char errorMessage[64];

// ========== HEPA STATUS FUNCTIONS ==========
enum HEPAStatus {
    HEPA_LEAK,        // < 9 Pa
    HEPA_NORMAL,      // 9-25 Pa
    HEPA_CLOGGING,    // 25-40 Pa
    HEPA_REPLACE      // > 40 Pa
};

HEPAStatus getHEPAStatus(float pressure) {
    float absP = abs(pressure);  // Use absolute value
    if (absP < HEPA_MIN_NORMAL) return HEPA_LEAK;
    if (absP <= HEPA_MAX_NORMAL) return HEPA_NORMAL;
    if (absP <= HEPA_REPLACE_THRESHOLD) return HEPA_CLOGGING;
    return HEPA_REPLACE;
}

const char* getHEPAStatusText(HEPAStatus status) {
    switch (status) {
        case HEPA_LEAK:     return "Weak Airflow / Leak Detected";
        case HEPA_NORMAL:   return "Normal HEPA Condition";
        case HEPA_CLOGGING: return "Filter Clogging - Schedule Replacement";
        case HEPA_REPLACE:  return "HEPA Replacement Required!";
        default:            return "Unknown";
    }
}

const char* getHEPAStatusIcon(HEPAStatus status) {
    switch (status) {
        case HEPA_LEAK:     return "❌";  // Red X - problem
        case HEPA_NORMAL:   return "🟢";  // Green - good
        case HEPA_CLOGGING: return "🟡";  // Yellow - warning
        case HEPA_REPLACE:  return "🔴";  // Red - critical
        default:            return "⚪";
    }
}

int getHEPAHealthPercent(float pressure) {
    float absP = abs(pressure);
    // Map pressure to health percentage
    // 9 Pa = 100% (new filter), 40 Pa = 0% (needs replacement)
    if (absP < HEPA_MIN_NORMAL) return 0;  // Leak = bad
    if (absP >= HEPA_REPLACE_THRESHOLD) return 0;
    
    // Linear interpolation: 9 Pa = 100%, 40 Pa = 0%
    float health = 100.0 * (HEPA_REPLACE_THRESHOLD - absP) / (HEPA_REPLACE_THRESHOLD - HEPA_MIN_NORMAL);
    return constrain((int)health, 0, 100);
}

void printHealthBar(int percent) {
    Serial.print("  [");
    int filled = percent / 5;  // 20 chars total
    for (int i = 0; i < 20; i++) {
        if (i < filled) Serial.print("█");
        else Serial.print("░");
    }
    Serial.printf("] %d%%\n", percent);
}

// ========== SETUP ==========
void setup() {
    Serial.begin(SERIAL_BAUD);
    while (!Serial) delay(100);

    Serial.println("\n");
    Serial.println("╔═══════════════════════════════════════════════════════════════╗");
    Serial.println("║          SDP810 Differential Pressure Sensor                  ║");
    Serial.println("║                  HEPA Filter Monitor                          ║");
    Serial.println("╚═══════════════════════════════════════════════════════════════╝");

    Wire.begin(I2C_SDA, I2C_SCL);
    sdp.begin(Wire, SDP8XX_I2C_ADDRESS_0);

    // Stop any existing measurement
    sdp.stopContinuousMeasurement();
    delay(100);

    // Get product info
    Serial.println("\n┌───────────────────────────────────────┐");
    Serial.println("│           DEVICE INFORMATION          │");
    Serial.println("└───────────────────────────────────────┘");

    uint32_t productNumber;
    uint8_t serialNumber[8];
    uint16_t error = sdp.readProductIdentifier(productNumber, serialNumber, 8);
    
    if (error == 0) {
        Serial.printf("  Product:  SDP%d\n", productNumber);
        Serial.print("  Serial:   0x");
        for (int i = 0; i < 8; i++) {
            if (serialNumber[i] < 0x10) Serial.print("0");
            Serial.print(serialNumber[i], HEX);
        }
        Serial.println();
    } else {
        errorToString(error, errorMessage, sizeof(errorMessage));
        Serial.printf("  ❌ Error: %s\n", errorMessage);
    }

    // Print threshold info
    Serial.println("\n┌───────────────────────────────────────┐");
    Serial.println("│         HEPA FILTER THRESHOLDS        │");
    Serial.println("└───────────────────────────────────────┘");
    Serial.printf("  ❌ < %.0f Pa     Weak airflow / Leak\n", HEPA_MIN_NORMAL);
    Serial.printf("  🟢 %.0f-%.0f Pa   Normal condition\n", HEPA_MIN_NORMAL, HEPA_MAX_NORMAL);
    Serial.printf("  🟡 %.0f-%.0f Pa   Filter clogging\n", HEPA_MAX_NORMAL, HEPA_REPLACE_THRESHOLD);
    Serial.printf("  🔴 > %.0f Pa    Replace immediately\n", HEPA_REPLACE_THRESHOLD);

    // Start continuous measurement
    error = sdp.startContinuousMeasurementWithDiffPressureTCompAndAveraging();
    if (error) {
        Serial.print("\n❌ Failed to start measurement: ");
        errorToString(error, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
        return;
    }

    Serial.println("\n✅ SDP810 Ready! Monitoring HEPA filter...\n");
    delay(1000);
}

// ========== MAIN LOOP ==========
void loop() {
    static unsigned long lastRead = 0;
    if (millis() - lastRead < READ_INTERVAL_MS) return;
    lastRead = millis();

    float pressure, temperature;
    uint16_t error = sdp.readMeasurement(pressure, temperature);

    if (error) {
        Serial.print("❌ Read error: ");
        errorToString(error, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
        return;
    }

    // Get HEPA status
    HEPAStatus status = getHEPAStatus(pressure);
    int health = getHEPAHealthPercent(pressure);

    // Print formatted output
    Serial.println("═══════════════════════════════════════════════════════════════════");
    Serial.println("                    HEPA FILTER STATUS                             ");
    Serial.println("═══════════════════════════════════════════════════════════════════");

    // Main status with big icon
    Serial.printf("\n  %s  %s\n\n", getHEPAStatusIcon(status), getHEPAStatusText(status));

    // Pressure reading
    Serial.println("📊 DIFFERENTIAL PRESSURE");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  Current:    %.2f Pa\n", pressure);
    Serial.printf("  Absolute:   %.2f Pa\n", abs(pressure));
    
    // Visual pressure bar (0-50 Pa range)
    Serial.print("  Range:      ");
    int barPos = constrain((int)(abs(pressure) / 50.0 * 40), 0, 40);
    Serial.print("[");
    for (int i = 0; i < 40; i++) {
        if (i == 7) Serial.print("|");       // 9 Pa mark
        else if (i == 20) Serial.print("|"); // 25 Pa mark
        else if (i == 32) Serial.print("|"); // 40 Pa mark
        else if (i < barPos) Serial.print("▓");
        else Serial.print("░");
    }
    Serial.println("]");
    Serial.println("            0    9    25       40     50 Pa");

    // Temperature
    Serial.println("\n🌡️  SENSOR TEMPERATURE");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  Temperature:  %.1f °C\n", temperature);

    // Filter health
    Serial.println("\n💪 FILTER HEALTH");
    Serial.println("───────────────────────────────────────────────────────────────────");
    printHealthBar(health);
    
    // Recommendation
    Serial.println("\n📝 RECOMMENDATION");
    Serial.println("───────────────────────────────────────────────────────────────────");
    switch (status) {
        case HEPA_LEAK:
            Serial.println("  ⚠️  Check for air leaks in the duct system");
            Serial.println("  ⚠️  Verify fan is running at correct speed");
            Serial.println("  ⚠️  Inspect filter seal and gaskets");
            break;
        case HEPA_NORMAL:
            Serial.println("  ✅ Filter is operating normally");
            Serial.println("  ✅ No action required");
            break;
        case HEPA_CLOGGING:
            Serial.println("  ⚠️  Schedule filter replacement soon");
            Serial.println("  ⚠️  Order replacement filter");
            Serial.printf("  ⚠️  Estimated remaining life: ~%d%%\n", health);
            break;
        case HEPA_REPLACE:
            Serial.println("  🚨 REPLACE FILTER IMMEDIATELY!");
            Serial.println("  🚨 System efficiency is compromised");
            Serial.println("  🚨 Risk of motor damage from high back-pressure");
            break;
    }

    Serial.println("\n═══════════════════════════════════════════════════════════════════\n");
}
