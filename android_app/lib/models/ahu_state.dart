import 'package:json_annotation/json_annotation.dart';

part 'ahu_state.g.dart';

/// AHU State model - matches web dashboard structure
@JsonSerializable()
class AhuState {
  final bool run;
  final bool m1;
  final bool m2;
  final bool cp;
  final bool heater;
  final bool fan;
  @JsonKey(name: 'fanSpeed')
  final int fanSpeed; // 0=OFF, 1=LOW, 2=MED, 3=HIGH
  @JsonKey(name: 'tempSet')
  final double tempSet;
  @JsonKey(name: 'humSet')
  final double humSet;
  final String? ip;
  
  // Motor timings (optional)
  @JsonKey(name: 'm1_start')
  final int? m1Start;
  @JsonKey(name: 'm1_post')
  final int? m1Post;
  @JsonKey(name: 'm2_interval')
  final int? m2Interval;
  @JsonKey(name: 'm2_run')
  final int? m2Run;
  @JsonKey(name: 'm2_delay')
  final int? m2Delay;

  AhuState({
    required this.run,
    required this.m1,
    required this.m2,
    required this.cp,
    required this.heater,
    required this.fan,
    required this.fanSpeed,
    required this.tempSet,
    required this.humSet,
    this.ip,
    this.m1Start,
    this.m1Post,
    this.m2Interval,
    this.m2Run,
    this.m2Delay,
  });

  factory AhuState.fromJson(Map<String, dynamic> json) => _$AhuStateFromJson(json);
  Map<String, dynamic> toJson() => _$AhuStateToJson(this);
  
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

