#pragma once

#include <stdint.h>

// Included last from the .ino so Arduino's auto-generated prototypes see these types.

enum SensorMode { SENSOR_NONE, SENSOR_SHT45, SENSOR_DHT22, SENSOR_COMBO };

enum FanSpeed : uint8_t { FAN_OFF = 0, FAN_LOW = 1, FAN_MED = 2, FAN_HIGH = 3 };
