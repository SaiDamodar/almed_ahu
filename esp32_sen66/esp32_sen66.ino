/*
 * SEN66 Environmental Sensor - Full Readings Demo
 * 
 * Sensor Capabilities:
 *   - PM1.0, PM2.5, PM4.0, PM10.0 (Particulate Matter)
 *   - Temperature & Humidity
 *   - VOC Index (Volatile Organic Compounds)
 *   - NOx Index (Nitrogen Oxides)
 *   - CO2 (Carbon Dioxide)
 *   - AQI Calculation (derived from PM2.5)
 * 
 * Library: Sensirion I2C SEN66
 * https://github.com/Sensirion/arduino-i2c-sen66
 */

#include <Arduino.h>
#include <SensirionI2cSen66.h>
#include <Wire.h>

// ========== CONFIGURATION ==========
#define SERIAL_BAUD      115200
#define READ_INTERVAL_MS 2000
#define I2C_SDA          21
#define I2C_SCL          22

// Error handling macro
#ifdef NO_ERROR
#undef NO_ERROR
#endif
#define NO_ERROR 0

// ========== SENSOR OBJECT ==========
SensirionI2cSen66 sensor;

static char errorMessage[64];
static int16_t error;

// ========== AQI CALCULATION (EPA Standard) ==========
struct AQIBreakpoint {
    float Clow, Chigh;
    int Ilow, Ihigh;
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
            return (int)((pm25Breakpoints[i].Ihigh - pm25Breakpoints[i].Ilow) / 
                   (pm25Breakpoints[i].Chigh - pm25Breakpoints[i].Clow) * 
                   (pm25 - pm25Breakpoints[i].Clow) + pm25Breakpoints[i].Ilow);
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

const char* getVOCLevel(float voc) {
    if (voc <= 100) return "Excellent";
    if (voc <= 200) return "Good";
    if (voc <= 300) return "Moderate";
    if (voc <= 400) return "Poor";
    return "Bad";
}

const char* getNOxLevel(float nox) {
    if (nox <= 20) return "Excellent";
    if (nox <= 100) return "Good";
    if (nox <= 200) return "Moderate";
    return "Poor";
}

const char* getCO2Level(uint16_t co2) {
    if (co2 <= 600) return "Excellent";
    if (co2 <= 800) return "Good";
    if (co2 <= 1000) return "Moderate";
    if (co2 <= 1500) return "Poor";
    return "Bad - Ventilate!";
}

// ========== SETUP ==========
void setup() {
    Serial.begin(SERIAL_BAUD);
    while (!Serial) delay(100);

    Serial.println("\n");
    Serial.println("╔═══════════════════════════════════════════════════════════════╗");
    Serial.println("║              SEN66 Environmental Sensor Demo                  ║");
    Serial.println("║     PM • Temperature • Humidity • VOC • NOx • CO2             ║");
    Serial.println("╚═══════════════════════════════════════════════════════════════╝");

    Wire.begin(I2C_SDA, I2C_SCL);
    sensor.begin(Wire, SEN66_I2C_ADDR_6B);

    Serial.println("\n[SEN66] Resetting sensor...");
    error = sensor.deviceReset();
    if (error != NO_ERROR) {
        Serial.print("❌ Reset failed: ");
        errorToString(error, errorMessage, sizeof errorMessage);
        Serial.println(errorMessage);
        return;
    }
    delay(1200);

    // Get Device Info
    Serial.println("\n┌───────────────────────────────────────┐");
    Serial.println("│           DEVICE INFORMATION          │");
    Serial.println("└───────────────────────────────────────┘");

    int8_t serialNumber[32] = {0};
    error = sensor.getSerialNumber(serialNumber, 32);
    if (error == NO_ERROR) {
        Serial.print("  Serial Number: ");
        Serial.println((const char*)serialNumber);
    }

    // Get firmware version
    uint8_t fwMajor, fwMinor;
    bool fwDebug;
    uint8_t hwMajor, hwMinor;
    uint8_t protocolMajor, protocolMinor;
    
    error = sensor.getVersion(fwMajor, fwMinor, fwDebug, hwMajor, hwMinor, protocolMajor, protocolMinor);
    if (error == NO_ERROR) {
        Serial.printf("  Firmware:      v%d.%d%s\n", fwMajor, fwMinor, fwDebug ? " (debug)" : "");
        Serial.printf("  Hardware:      v%d.%d\n", hwMajor, hwMinor);
        Serial.printf("  Protocol:      v%d.%d\n", protocolMajor, protocolMinor);
    }

    // Start measurement
    error = sensor.startContinuousMeasurement();
    if (error != NO_ERROR) {
        Serial.print("❌ Start measurement failed: ");
        errorToString(error, errorMessage, sizeof errorMessage);
        Serial.println(errorMessage);
        return;
    }

    Serial.println("\n✅ SEN66 Ready! Starting measurements...\n");
    delay(1000);
}

// ========== MAIN LOOP ==========
void loop() {
    static unsigned long lastRead = 0;
    if (millis() - lastRead < READ_INTERVAL_MS) return;
    lastRead = millis();

    // Variables for all readings
    float pm1p0 = 0.0, pm2p5 = 0.0, pm4p0 = 0.0, pm10p0 = 0.0;
    float humidity = 0.0, temperature = 0.0;
    float vocIndex = 0.0, noxIndex = 0.0;
    uint16_t co2 = 0;

    error = sensor.readMeasuredValues(
        pm1p0, pm2p5, pm4p0, pm10p0,
        humidity, temperature,
        vocIndex, noxIndex, co2
    );

    if (error != NO_ERROR) {
        Serial.print("❌ Read error: ");
        errorToString(error, errorMessage, sizeof errorMessage);
        Serial.println(errorMessage);
        return;
    }

    // Calculate AQI from PM2.5
    int aqi = calculateAQI(pm2p5);

    // Print formatted output
    Serial.println("═══════════════════════════════════════════════════════════════════");
    Serial.println("                      SEN66 SENSOR READINGS                        ");
    Serial.println("═══════════════════════════════════════════════════════════════════");

    // AQI Section
    Serial.println("\n🌍 AIR QUALITY INDEX (AQI)");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  AQI Value:        %d\n", aqi);
    Serial.printf("  Category:         %s\n", getAQICategory(aqi));

    // Particulate Matter Section
    Serial.println("\n💨 PARTICULATE MATTER (PM)");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  PM1.0:            %.1f µg/m³   (ultrafine particles)\n", pm1p0);
    Serial.printf("  PM2.5:            %.1f µg/m³   (fine particles - lung penetrating)\n", pm2p5);
    Serial.printf("  PM4.0:            %.1f µg/m³   (inhalable particles)\n", pm4p0);
    Serial.printf("  PM10.0:           %.1f µg/m³   (coarse particles)\n", pm10p0);

    // Environment Section
    Serial.println("\n🌡️  ENVIRONMENT");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  Temperature:      %.1f °C (%.1f °F)\n", temperature, (temperature * 9/5) + 32);
    Serial.printf("  Humidity:         %.1f %%RH\n", humidity);
    
    // Calculate Heat Index if temp > 26°C
    if (temperature >= 26 && humidity >= 40) {
        float hi = -8.78469475556 + 1.61139411*temperature + 2.33854883889*humidity 
                   - 0.14611605*temperature*humidity - 0.012308094*temperature*temperature 
                   - 0.0164248277778*humidity*humidity;
        Serial.printf("  Heat Index:       %.1f °C (feels like)\n", hi);
    }
    
    // Calculate Dew Point
    float dewPoint = temperature - ((100 - humidity) / 5);
    Serial.printf("  Dew Point:        %.1f °C\n", dewPoint);

    // Gas Section
    Serial.println("\n🧪 GAS INDICES");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  VOC Index:        %.0f (%s)\n", vocIndex, getVOCLevel(vocIndex));
    Serial.printf("  NOx Index:        %.0f (%s)\n", noxIndex, getNOxLevel(noxIndex));
    Serial.println("  ├─ VOC: Volatile Organic Compounds (cleaning products, paints, etc.)");
    Serial.println("  └─ NOx: Nitrogen Oxides (combustion, traffic pollution)");

    // CO2 Section
    Serial.println("\n🫁 CARBON DIOXIDE (CO2)");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  CO2 Level:        %d ppm (%s)\n", co2, getCO2Level(co2));
    Serial.println("  ├─ <600 ppm:  Fresh outdoor air");
    Serial.println("  ├─ 600-1000:  Normal indoor");
    Serial.println("  └─ >1500:     Needs ventilation");

    // Summary Bar
    Serial.println("\n📊 QUICK STATUS");
    Serial.println("───────────────────────────────────────────────────────────────────");
    Serial.printf("  [AQI: %3d] [PM2.5: %5.1f] [Temp: %4.1f°C] [Hum: %4.1f%%] [CO2: %4d]\n", 
                  aqi, pm2p5, temperature, humidity, co2);
    Serial.println("═══════════════════════════════════════════════════════════════════\n");
}
