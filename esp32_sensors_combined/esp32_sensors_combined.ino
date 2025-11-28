/*
 * ALMED AHU - Combined Sensor Module
 * 
 * Sensors:
 *   - SEN66: PM1.0, PM2.5, PM4.0, PM10.0, Humidity, Temperature, VOC, NOx, CO2
 *   - SDP810: Differential Pressure
 * 
 * Both sensors use I2C on the same bus (GPIO21=SDA, GPIO22=SCL)
 * 
 * Libraries Required:
 *   - Sensirion I2C SEN66: https://github.com/Sensirion/arduino-i2c-sen66
 *   - Sensirion I2C SDP: https://github.com/Sensirion/arduino-i2c-sdp
 * 
 * Author: ALMED Equipment
 * Date: 2025
 */

#include <Arduino.h>
#include <Wire.h>
#include <SensirionI2cSen66.h>
#include <SensirionI2CSdp.h>

// ========== FORWARD DECLARATIONS ==========
// HEPA Filter Status enum (must be declared before functions)
enum HEPAStatus { HEPA_LEAK, HEPA_NORMAL, HEPA_CLOGGING, HEPA_REPLACE_NOW };

// ========== CONFIGURATION ==========
#define SERIAL_BAUD      115200
#define READ_INTERVAL_MS 2000    // Read sensors every 2 seconds
#define I2C_SDA          21      // Default ESP32 I2C SDA
#define I2C_SCL          22      // Default ESP32 I2C SCL

// ========== SENSOR OBJECTS ==========
SensirionI2cSen66 sen66;
SensirionI2CSdp   sdp810;

// ========== GLOBAL VARIABLES ==========
static char errorMessage[64];
static int16_t error;

// SEN66 readings
float pm1p0 = 0.0;
float pm2p5 = 0.0;
float pm4p0 = 0.0;
float pm10p0 = 0.0;
float humidity = 0.0;
float temperature = 0.0;
float vocIndex = 0.0;
float noxIndex = 0.0;
uint16_t co2 = 0;

// SDP810 readings
float differentialPressure = 0.0;
float sdpTemperature = 0.0;

// Status flags
bool sen66Ready = false;
bool sdp810Ready = false;

// ========== AQI CALCULATION ==========
// EPA AQI breakpoints for PM2.5 (24-hour average, but used for instant reading)
struct AQIBreakpoint {
    float Clow;
    float Chigh;
    int Ilow;
    int Ihigh;
};

const AQIBreakpoint pm25Breakpoints[] = {
    {0.0, 12.0, 0, 50},        // Good
    {12.1, 35.4, 51, 100},     // Moderate
    {35.5, 55.4, 101, 150},    // Unhealthy for Sensitive Groups
    {55.5, 150.4, 151, 200},   // Unhealthy
    {150.5, 250.4, 201, 300},  // Very Unhealthy
    {250.5, 500.4, 301, 500}   // Hazardous
};

int calculateAQI(float pm25) {
    if (pm25 < 0) return 0;
    if (pm25 > 500.4) return 500;
    
    for (int i = 0; i < 6; i++) {
        if (pm25 >= pm25Breakpoints[i].Clow && pm25 <= pm25Breakpoints[i].Chigh) {
            float Ilow = pm25Breakpoints[i].Ilow;
            float Ihigh = pm25Breakpoints[i].Ihigh;
            float Clow = pm25Breakpoints[i].Clow;
            float Chigh = pm25Breakpoints[i].Chigh;
            return (int)((Ihigh - Ilow) / (Chigh - Clow) * (pm25 - Clow) + Ilow);
        }
    }
    return 0;
}

const char* getAQICategory(int aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy (Sensitive)";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
}

// ========== HEPA FILTER STATUS ==========
// Pressure thresholds for HEPA filter health
#define HEPA_MIN_NORMAL     9.0    // Below = leak/weak airflow
#define HEPA_MAX_NORMAL     25.0   // Above = clogging starts
#define HEPA_REPLACE        40.0   // Above = replace immediately

HEPAStatus getHEPAStatus(float pressure) {
    float absP = abs(pressure);
    if (absP < HEPA_MIN_NORMAL) return HEPA_LEAK;
    if (absP <= HEPA_MAX_NORMAL) return HEPA_NORMAL;
    if (absP <= HEPA_REPLACE) return HEPA_CLOGGING;
    return HEPA_REPLACE_NOW;
}

const char* getHEPAStatusText(HEPAStatus status) {
    switch (status) {
        case HEPA_LEAK:        return "Weak Airflow / Leak";
        case HEPA_NORMAL:      return "Normal Condition";
        case HEPA_CLOGGING:    return "Filter Clogging";
        case HEPA_REPLACE_NOW: return "Replace Required!";
        default:               return "Unknown";
    }
}

const char* getHEPAIcon(HEPAStatus status) {
    switch (status) {
        case HEPA_LEAK:        return "❌";
        case HEPA_NORMAL:      return "🟢";
        case HEPA_CLOGGING:    return "🟡";
        case HEPA_REPLACE_NOW: return "🔴";
        default:               return "⚪";
    }
}

int getHEPAHealthPercent(float pressure) {
    float absP = abs(pressure);
    if (absP < HEPA_MIN_NORMAL || absP >= HEPA_REPLACE) return 0;
    return constrain((int)(100.0 * (HEPA_REPLACE - absP) / (HEPA_REPLACE - HEPA_MIN_NORMAL)), 0, 100);
}

// ========== SETUP FUNCTIONS ==========
void setupSEN66() {
    Serial.println("\n[SEN66] Initializing...");
    
    sen66.begin(Wire, SEN66_I2C_ADDR_6B);
    
    error = sen66.deviceReset();
    if (error != 0) {
        Serial.print("[SEN66] Reset failed: ");
        errorToString(error, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
        return;
    }
    delay(1200);
    
    // Get serial number
    int8_t serialNumber[32] = {0};
    error = sen66.getSerialNumber(serialNumber, 32);
    if (error == 0) {
        Serial.print("[SEN66] Serial: ");
        Serial.println((const char*)serialNumber);
    }
    
    // Start measurement
    error = sen66.startContinuousMeasurement();
    if (error != 0) {
        Serial.print("[SEN66] Start measurement failed: ");
        errorToString(error, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
        return;
    }
    
    sen66Ready = true;
    Serial.println("[SEN66] Ready ✓");
}

void setupSDP810() {
    Serial.println("\n[SDP810] Initializing...");
    
    sdp810.begin(Wire, SDP8XX_I2C_ADDRESS_0);
    
    // Stop any existing measurement first
    sdp810.stopContinuousMeasurement();
    delay(100);
    
    // Get product info
    uint32_t productNumber;
    uint8_t serialNumber[8];
    
    uint16_t err = sdp810.readProductIdentifier(productNumber, serialNumber, 8);
    if (err == 0) {
        Serial.print("[SDP810] Product: ");
        Serial.print(productNumber);
        Serial.print(", Serial: 0x");
        for (int i = 0; i < 8; i++) {
            if (serialNumber[i] < 0x10) Serial.print("0");
            Serial.print(serialNumber[i], HEX);
        }
        Serial.println();
    }
    
    // Start continuous measurement with temperature compensation
    err = sdp810.startContinuousMeasurementWithDiffPressureTCompAndAveraging();
    if (err != 0) {
        Serial.print("[SDP810] Start measurement failed: ");
        errorToString(err, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
        return;
    }
    
    sdp810Ready = true;
    Serial.println("[SDP810] Ready ✓");
}

// ========== READ FUNCTIONS ==========
void readSEN66() {
    if (!sen66Ready) return;
    
    error = sen66.readMeasuredValues(
        pm1p0, pm2p5, pm4p0, pm10p0,
        humidity, temperature,
        vocIndex, noxIndex, co2
    );
    
    if (error != 0) {
        Serial.print("[SEN66] Read error: ");
        errorToString(error, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
    }
}

void readSDP810() {
    if (!sdp810Ready) return;
    
    uint16_t err = sdp810.readMeasurement(differentialPressure, sdpTemperature);
    
    if (err != 0) {
        Serial.print("[SDP810] Read error: ");
        errorToString(err, errorMessage, sizeof(errorMessage));
        Serial.println(errorMessage);
    }
}

// ========== PRINT FUNCTIONS ==========
void printReadings() {
    Serial.println("\n═══════════════════════════════════════════════════════════════");
    Serial.println("                    ALMED AHU SENSOR READINGS                   ");
    Serial.println("═══════════════════════════════════════════════════════════════");
    
    // Air Quality Section
    if (sen66Ready) {
        int aqi = calculateAQI(pm2p5);
        
        Serial.println("\n📊 AIR QUALITY");
        Serial.println("───────────────────────────────────────");
        Serial.printf("  AQI:          %d (%s)\n", aqi, getAQICategory(aqi));
        Serial.printf("  PM1.0:        %.1f µg/m³\n", pm1p0);
        Serial.printf("  PM2.5:        %.1f µg/m³\n", pm2p5);
        Serial.printf("  PM4.0:        %.1f µg/m³\n", pm4p0);
        Serial.printf("  PM10.0:       %.1f µg/m³\n", pm10p0);
        
        Serial.println("\n🌡️ ENVIRONMENT");
        Serial.println("───────────────────────────────────────");
        Serial.printf("  Temperature:  %.1f °C\n", temperature);
        Serial.printf("  Humidity:     %.1f %%RH\n", humidity);
        
        Serial.println("\n💨 GAS INDICES");
        Serial.println("───────────────────────────────────────");
        Serial.printf("  VOC Index:    %.0f\n", vocIndex);
        Serial.printf("  NOx Index:    %.0f\n", noxIndex);
        Serial.printf("  CO2:          %d ppm\n", co2);
    } else {
        Serial.println("\n❌ SEN66 not available");
    }
    
    // HEPA Filter Status Section
    Serial.println("\n🔄 HEPA FILTER STATUS");
    Serial.println("───────────────────────────────────────");
    if (sdp810Ready) {
        HEPAStatus hepaStatus = getHEPAStatus(differentialPressure);
        int hepaHealth = getHEPAHealthPercent(differentialPressure);
        
        Serial.printf("  Status:       %s %s\n", getHEPAIcon(hepaStatus), getHEPAStatusText(hepaStatus));
        Serial.printf("  Pressure:     %.2f Pa\n", differentialPressure);
        Serial.printf("  Filter Health: %d%%\n", hepaHealth);
        
        // Health bar
        Serial.print("  [");
        int filled = hepaHealth / 5;
        for (int i = 0; i < 20; i++) {
            Serial.print(i < filled ? "█" : "░");
        }
        Serial.println("]");
        
        // Thresholds reference
        Serial.println("  ────────────────────────────────");
        Serial.println("  ❌ <9Pa=Leak  🟢 9-25Pa=OK  🟡 25-40Pa=Clog  🔴 >40Pa=Replace");
    } else {
        Serial.println("  ❌ SDP810 not available");
    }
    
    Serial.println("\n═══════════════════════════════════════════════════════════════\n");
}

void printCompactJSON() {
    // JSON output for easy parsing
    Serial.print("{");
    
    if (sen66Ready) {
        int aqi = calculateAQI(pm2p5);
        Serial.printf("\"aqi\":%d,", aqi);
        Serial.printf("\"pm1p0\":%.1f,", pm1p0);
        Serial.printf("\"pm2p5\":%.1f,", pm2p5);
        Serial.printf("\"pm4p0\":%.1f,", pm4p0);
        Serial.printf("\"pm10p0\":%.1f,", pm10p0);
        Serial.printf("\"temperature\":%.1f,", temperature);
        Serial.printf("\"humidity\":%.1f,", humidity);
        Serial.printf("\"voc\":%.0f,", vocIndex);
        Serial.printf("\"nox\":%.0f,", noxIndex);
        Serial.printf("\"co2\":%d,", co2);
    }
    
    if (sdp810Ready) {
        HEPAStatus hepaStatus = getHEPAStatus(differentialPressure);
        Serial.printf("\"diffPressure\":%.2f,", differentialPressure);
        Serial.printf("\"hepaStatus\":\"%s\",", getHEPAStatusText(hepaStatus));
        Serial.printf("\"hepaHealth\":%d,", getHEPAHealthPercent(differentialPressure));
        Serial.printf("\"sdpTemp\":%.1f", sdpTemperature);
    }
    
    Serial.println("}");
}

// ========== MAIN FUNCTIONS ==========
void setup() {
    Serial.begin(SERIAL_BAUD);
    while (!Serial) {
        delay(100);
    }
    
    Serial.println("\n");
    Serial.println("╔═══════════════════════════════════════════════════════════════╗");
    Serial.println("║          ALMED AHU - Combined Sensor Module                   ║");
    Serial.println("║                   SEN66 + SDP810                              ║");
    Serial.println("╚═══════════════════════════════════════════════════════════════╝");
    
    // Initialize I2C
    Wire.begin(I2C_SDA, I2C_SCL);
    Serial.printf("\n[I2C] Initialized on SDA=%d, SCL=%d\n", I2C_SDA, I2C_SCL);
    
    // Initialize sensors
    setupSEN66();
    setupSDP810();
    
    // Status summary
    Serial.println("\n┌───────────────────────────────────────┐");
    Serial.printf("│  SEN66:  %s                           │\n", sen66Ready ? "✓ OK" : "✗ FAIL");
    Serial.printf("│  SDP810: %s                           │\n", sdp810Ready ? "✓ OK" : "✗ FAIL");
    Serial.println("└───────────────────────────────────────┘");
    
    if (!sen66Ready && !sdp810Ready) {
        Serial.println("\n⚠️  WARNING: No sensors detected! Check wiring.");
    }
    
    Serial.println("\nStarting measurements...\n");
    delay(1000);
}

void loop() {
    static unsigned long lastRead = 0;
    unsigned long now = millis();
    
    if (now - lastRead >= READ_INTERVAL_MS) {
        lastRead = now;
        
        // Read all sensors
        readSEN66();
        readSDP810();
        
        // Print formatted output
        printReadings();
        
        // Uncomment for JSON output instead:
        // printCompactJSON();
    }
}

