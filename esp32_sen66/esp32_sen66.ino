#include <Arduino.h>
#include <Wire.h>
#include <SensirionI2cSen66.h>

// make sure NO_ERROR is defined correctly
#ifdef NO_ERROR
#undef NO_ERROR
#endif
#define NO_ERROR 0

SensirionI2cSen66 sensor;

static char errorMessage[64];
static int16_t error;

// ---------------- AQI FUNCTIONS ----------------

String getAqiCategory(int aqi) {
    if (aqi <= 50) return "Good";
    else if (aqi <= 100) return "Satisfactory";
    else if (aqi <= 200) return "Moderately Polluted";
    else if (aqi <= 300) return "Poor";
    else if (aqi <= 400) return "Very Poor";
    return "Severe";
}

float calcAqiSubIndex(float concentration, float Blo, float Bhi, float Ilo, float Ihi) {
    return ((Ihi - Ilo) / (Bhi - Blo)) * (concentration - Blo) + Ilo;
}

int getAqiFromPm25(float pm25) {
    if (pm25 <= 30) return calcAqiSubIndex(pm25, 0, 30, 0, 50);
    else if (pm25 <= 60) return calcAqiSubIndex(pm25, 31, 60, 51, 100);
    else if (pm25 <= 90) return calcAqiSubIndex(pm25, 61, 90, 101, 200);
    else if (pm25 <= 120) return calcAqiSubIndex(pm25, 91, 120, 201, 300);
    else if (pm25 <= 250) return calcAqiSubIndex(pm25, 121, 250, 301, 400);
    return calcAqiSubIndex(pm25, 251, 500, 401, 500);
}

int getAqiFromPm10(float pm10) {
    if (pm10 <= 50) return calcAqiSubIndex(pm10, 0, 50, 0, 50);
    else if (pm10 <= 100) return calcAqiSubIndex(pm10, 51, 100, 51, 100);
    else if (pm10 <= 250) return calcAqiSubIndex(pm10, 101, 250, 101, 200);
    else if (pm10 <= 350) return calcAqiSubIndex(pm10, 251, 350, 201, 300);
    else if (pm10 <= 430) return calcAqiSubIndex(pm10, 351, 430, 301, 400);
    return calcAqiSubIndex(pm10, 431, 1000, 401, 500);
}

// ------------------------------------------------

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(50);

  Wire.begin(21, 22);  // SDA, SCL for ESP32

  sensor.begin(Wire, SEN66_I2C_ADDR_6B);

  // reset
  error = sensor.deviceReset();
  if (error != NO_ERROR) {
    Serial.println("Device reset failed!");
    return;
  }

  delay(1200); // boot

  int8_t serialNumber[32] = {0};
  error = sensor.getSerialNumber(serialNumber, sizeof(serialNumber));
  if (error == NO_ERROR) {
    Serial.print("SEN66 Serial: ");
    Serial.println((const char*)serialNumber);
  }

  // start measurement
  error = sensor.startContinuousMeasurement();
  if (error != NO_ERROR) {
    Serial.println("startContinuousMeasurement failed!");
    return;
  }
}

void loop() {
  float pm1_0   = 0.0f;
  float pm2_5   = 0.0f;
  float pm4_0   = 0.0f;
  float pm10_0  = 0.0f;
  float humidity = 0.0f;
  float temp     = 0.0f;
  float vocIndex = 0.0f;
  float noxIndex = 0.0f;
  uint16_t co2   = 0;

  delay(1000);

  error = sensor.readMeasuredValues(
      pm1_0,
      pm2_5,
      pm4_0,
      pm10_0,
      humidity,
      temp,
      vocIndex,
      noxIndex,
      co2
  );

  if (error != NO_ERROR) {
    Serial.print("readMeasuredValues error: ");
    errorToString(error, errorMessage, sizeof(errorMessage));
    Serial.println(errorMessage);
    return;
  }

  // AQI CALC
  int aqiPm25 = getAqiFromPm25(pm2_5);
  int aqiPm10 = getAqiFromPm10(pm10_0);
  int finalAqi = max(aqiPm25, aqiPm10);
  String aqiCat = getAqiCategory(finalAqi);

  // PRINT
  Serial.println("======== AIR DATA ========");
  Serial.printf("PM1.0     : %.2f µg/m³\n", pm1_0);
  Serial.printf("PM2.5     : %.2f µg/m³\n", pm2_5);
  Serial.printf("PM4.0     : %.2f µg/m³\n", pm4_0);
  Serial.printf("PM10      : %.2f µg/m³\n", pm10_0);
  Serial.printf("Temp      : %.2f °C\n", temp);
  Serial.printf("Humidity  : %.2f %%\n", humidity);
  Serial.printf("VOC Index : %.2f\n", vocIndex);
  Serial.printf("NOx Index : %.2f\n", noxIndex);
  Serial.printf("CO2       : %u ppm\n\n", co2);

  Serial.printf("AQI(PM2.5): %d\n", aqiPm25);
  Serial.printf("AQI(PM10) : %d\n", aqiPm10);
  Serial.printf("Final AQI : %d\n", finalAqi);
  Serial.printf("Category  : %s\n", aqiCat.c_str());
  Serial.println("==========================\n");
}
