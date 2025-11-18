import 'package:json_annotation/json_annotation.dart';

part 'ahu_telemetry.g.dart';

/// AHU Telemetry model - matches web dashboard structure
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
}

