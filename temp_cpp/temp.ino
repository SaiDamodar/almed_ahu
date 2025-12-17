#include <Wire.h>
#include "Adafruit_SHT4x.h"

Adafruit_SHT4x sht4;

void setup() {
  Serial.begin(115200);
  Wire.begin(21,22);
  Serial.println("Initializing SHT45...");

  if (!sht4.begin()) {
    Serial.println("SHT45 not found on I2C bus. Check wiring (SDA=21, SCL=22, 3.3V, GND).");
    while(1);
  }

  sht4.setPrecision(SHT4X_HIGH_PRECISION);
  sht4.setHeater(SHT4X_NO_HEATER);
  Serial.println("SHT45 ready — starting readings.");
}

void loop() {
  sensors_event_t hum, temp;
  sht4.getEvent(&hum, &temp);

  Serial.print("Temperature: ");
  Serial.print(temp.temperature);
  Serial.print(" °C  |  Humidity: ");
  Serial.print(hum.relative_humidity);
  Serial.println(" %");

  delay(2000);
}
