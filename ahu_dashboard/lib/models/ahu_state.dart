import 'package:json_annotation/json_annotation.dart';

part 'ahu_state.g.dart';

/// State data from ESP32 AHU unit (retained MQTT message)
@JsonSerializable()
class AhuState {
  final bool run;            // System running state
  final bool m1;             // Motor-1 status
  final bool m2;             // Motor-2 status
  final bool cp;             // Compressor status
  final bool heater;         // Heater status
  final double tempSet;      // Temperature setpoint
  final double humSet;       // Humidity setpoint
  final String ip;           // ESP32 IP address

  AhuState({
    required this.run,
    required this.m1,
    required this.m2,
    required this.cp,
    required this.heater,
    required this.tempSet,
    required this.humSet,
    required this.ip,
  });

  factory AhuState.fromJson(Map<String, dynamic> json) =>
      _$AhuStateFromJson(json);

  Map<String, dynamic> toJson() => _$AhuStateToJson(this);
}


