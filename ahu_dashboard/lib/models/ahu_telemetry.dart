import 'package:json_annotation/json_annotation.dart';

part 'ahu_telemetry.g.dart';

/// Telemetry data from ESP32 AHU unit
@JsonSerializable()
class AhuTelemetry {
  final double? temp;        // Temperature in °C
  final double? hum;         // Humidity in %RH
  final bool m1;             // Motor-1 (drain) status
  final bool m2;             // Motor-2 (filter clean) status
  final bool run;            // System running state
  final bool cp;             // Compressor (cooling) status
  final bool heater;         // Heater (dehumidifier) status
  final bool fan;             // Fan status (on/off)
  @JsonKey(name: 'fanSpeed') final int fanSpeed;  // Fan speed: 0=OFF, 1=LOW, 2=MID, 3=HIGH
  final double tempSet;      // Temperature setpoint
  final double humSet;       // Humidity setpoint
  final int ts;              // Timestamp (millis)

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
  });

  factory AhuTelemetry.fromJson(Map<String, dynamic> json) =>
      _$AhuTelemetryFromJson(json);

  Map<String, dynamic> toJson() => _$AhuTelemetryToJson(this);

  /// Get temperature display string
  String get tempDisplay => temp != null ? '${temp!.toStringAsFixed(1)}°C' : 'N/A';

  /// Get humidity display string
  String get humDisplay => hum != null ? '${hum!.toStringAsFixed(1)}%' : 'N/A';

  /// Check if sensor data is valid
  bool get hasSensorData => temp != null && hum != null;

  /// Get fan speed display string (OFF when system not running)
  String get fanSpeedDisplay {
    switch (fanSpeed) {
      case 0:
        return 'OFF';
      case 1:
        return 'LOW (5V)';
      case 2:
        return 'MID (9V)';
      case 3:
        return 'HIGH (12V)';
      default:
        return 'OFF';  // Default to OFF (fan off when system not running)
    }
  }
}


