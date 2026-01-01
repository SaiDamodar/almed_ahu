import 'package:json_annotation/json_annotation.dart';

part 'ahu_telemetry.g.dart';

/// Telemetry data from ESP32 AHU unit
/// Supports both SHT45 (original) and SEN66+SDP810 (combo) sensors
@JsonSerializable()
class AhuTelemetry {
  // Basic readings (both sensor types)
  final double? temp;        // Temperature in °C
  final double? hum;         // Humidity in %RH
  final bool m1;             // Motor-1 (filter) status
  final bool m2;             // Motor-2 (drain) status
  final bool run;            // System running state
  final bool cp;             // Compressor (cooling) status
  final bool heater;         // Heater (dehumidifier) status
  final bool fan;            // Fan status (on/off)
  @JsonKey(name: 'fanSpeed') final int fanSpeed;  // Fan speed: 0=OFF, 1=LOW, 2=MED, 3=HIGH
  final double tempSet;      // Temperature setpoint
  final double humSet;       // Humidity setpoint
  final int ts;              // Timestamp (millis)
  
  // Sensor type indicator
  @JsonKey(name: 'sensorType') final String? sensorType;  // "sht45" or "combo"
  
  // SEN66 Air Quality readings (combo sensors only)
  final int? aqi;            // Air Quality Index
  @JsonKey(name: 'pm1p0') final double? pm1p0;    // PM1.0 µg/m³
  @JsonKey(name: 'pm2p5') final double? pm2p5;    // PM2.5 µg/m³
  @JsonKey(name: 'pm4p0') final double? pm4p0;    // PM4.0 µg/m³
  @JsonKey(name: 'pm10p0') final double? pm10p0;  // PM10.0 µg/m³
  final double? voc;         // VOC Index
  final double? nox;         // NOx Index
  final int? co2;            // CO2 in ppm
  
  // SDP810 HEPA readings (combo sensors only)
  @JsonKey(name: 'diffPressure') final double? diffPressure;  // Differential pressure Pa
  @JsonKey(name: 'hepaStatus') final String? hepaStatus;      // HEPA filter status
  @JsonKey(name: 'hepaHealth') final int? hepaHealth;         // HEPA health percentage

  AhuTelemetry({
    this.temp,
    this.hum,
    required this.m1,
    required this.m2,
    required this.run,
    required this.cp,
    required this.heater,
    required this.fan,
    required this.fanSpeed,
    required this.tempSet,
    required this.humSet,
    required this.ts,
    this.sensorType,
    this.aqi,
    this.pm1p0,
    this.pm2p5,
    this.pm4p0,
    this.pm10p0,
    this.voc,
    this.nox,
    this.co2,
    this.diffPressure,
    this.hepaStatus,
    this.hepaHealth,
  });

  factory AhuTelemetry.fromJson(Map<String, dynamic> json) =>
      _$AhuTelemetryFromJson(json);

  Map<String, dynamic> toJson() => _$AhuTelemetryToJson(this);

  /// Check if this is combo sensor data
  bool get isComboSensor => sensorType == 'combo';
  
  /// Check if air quality data is available
  bool get hasAirQualityData => aqi != null || pm2p5 != null || co2 != null;
  
  /// Check if HEPA data is available
  bool get hasHepaData => diffPressure != null || hepaStatus != null;

  /// Get temperature display string
  String get tempDisplay => temp != null ? '${temp!.toStringAsFixed(1)}°C' : 'N/A';

  /// Get humidity display string
  String get humDisplay => hum != null ? '${hum!.toStringAsFixed(1)}%' : 'N/A';

  /// Check if sensor data is valid
  bool get hasSensorData => temp != null && hum != null;

  /// Get fan speed display string
  String get fanSpeedDisplay {
    switch (fanSpeed) {
      case 0:
        return 'OFF';
      case 1:
        return 'LOW (5V)';
      case 2:
        return 'MED (7V)';
      case 3:
        return 'HIGH (9V)';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// Get AQI category
  String get aqiCategory {
    if (aqi == null) return 'N/A';
    if (aqi! <= 50) return 'Good';
    if (aqi! <= 100) return 'Moderate';
    if (aqi! <= 150) return 'Unhealthy (Sensitive)';
    if (aqi! <= 200) return 'Unhealthy';
    if (aqi! <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }
  
  /// Get AQI color
  int get aqiColorValue {
    if (aqi == null) return 0xFF9E9E9E;
    if (aqi! <= 50) return 0xFF4CAF50;    // Green
    if (aqi! <= 100) return 0xFFFFEB3B;   // Yellow
    if (aqi! <= 150) return 0xFFFF9800;   // Orange
    if (aqi! <= 200) return 0xFFF44336;   // Red
    if (aqi! <= 300) return 0xFF9C27B0;   // Purple
    return 0xFF880E4F;                     // Maroon
  }
  
  /// Get CO2 level description
  String get co2Level {
    if (co2 == null) return 'N/A';
    if (co2! <= 600) return 'Excellent';
    if (co2! <= 800) return 'Good';
    if (co2! <= 1000) return 'Moderate';
    if (co2! <= 1500) return 'Poor';
    return 'Ventilate!';
  }
}
