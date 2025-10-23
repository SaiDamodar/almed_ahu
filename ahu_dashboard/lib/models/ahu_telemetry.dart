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
}


