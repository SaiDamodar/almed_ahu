import 'package:json_annotation/json_annotation.dart';

part 'ahu_telemetry.g.dart';

/// AHU Telemetry model - matches web dashboard structure
/// Supports both SHT45 (basic temp/hum) and combo sensors (SEN66+SDP810)
@JsonSerializable()
class AhuTelemetry {
  final double? temp;
  final double? hum;
  final bool m1;
  final bool m2;
  final bool run;
  final bool cp;
  final bool heater;
  final bool fan;
  @JsonKey(name: 'fanSpeed')
  final int fanSpeed;
  @JsonKey(name: 'tempSet')
  final double tempSet;
  @JsonKey(name: 'humSet')
  final double humSet;
  final int? ts; // Timestamp

  // Combo sensor fields (SEN66 + SDP810)
  @JsonKey(name: 'sensorType')
  final String? sensorType; // 'sht45' or 'combo'
  
  // Air Quality (SEN66)
  final int? aqi;
  @JsonKey(name: 'pm1p0')
  final double? pm1p0;
  @JsonKey(name: 'pm2p5')
  final double? pm2p5;
  @JsonKey(name: 'pm4p0')
  final double? pm4p0;
  @JsonKey(name: 'pm10p0')
  final double? pm10p0;
  final int? voc;
  final int? nox;
  final int? co2;
  
  // HEPA Filter (SDP810)
  @JsonKey(name: 'diffPressure')
  final double? diffPressure;
  @JsonKey(name: 'hepaStatus')
  final String? hepaStatus;
  @JsonKey(name: 'hepaHealth')
  final int? hepaHealth;

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
    this.ts,
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

  factory AhuTelemetry.fromJson(Map<String, dynamic> json) => _$AhuTelemetryFromJson(json);
  Map<String, dynamic> toJson() => _$AhuTelemetryToJson(this);

  String get tempDisplay => temp != null ? '${temp!.toStringAsFixed(1)}°C' : 'N/A';
  String get humDisplay => hum != null ? '${hum!.toStringAsFixed(1)}%' : 'N/A';
  bool get hasSensorData => temp != null && hum != null;
  
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

  // Combo sensor helpers
  bool get isComboSensor => sensorType == 'combo';
  bool get hasAirQualityData => isComboSensor && (pm2p5 != null || aqi != null);
  bool get hasHepaData => isComboSensor && (hepaStatus != null || diffPressure != null);
}
