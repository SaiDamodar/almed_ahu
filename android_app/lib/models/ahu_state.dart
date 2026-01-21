import 'package:json_annotation/json_annotation.dart';

part 'ahu_state.g.dart';

/// AHU State model - matches web dashboard structure
@JsonSerializable()
class AhuState {
  final bool run;
  final bool m1;
  final bool m2;
  final bool cp;
  @JsonKey(defaultValue: false)
  final bool cp2; // CP2 for dual compressor mode
  final bool heater;
  final bool fan;
  @JsonKey(name: 'fanSpeed')
  final int fanSpeed; // 0=OFF, 1=LOW, 2=MED, 3=HIGH
  @JsonKey(name: 'tempSet')
  final double tempSet;
  @JsonKey(name: 'humSet')
  final double humSet;
  final String? ip;
  
  // Dual CP mode fields
  @JsonKey(name: 'cpMode', defaultValue: 'dual')
  final String cpMode; // 'dual' or 'single'
  @JsonKey(name: 'cpActive', defaultValue: 1)
  final int cpActive; // 1 or 2 - which CP is active
  @JsonKey(name: 'dualCpBothOn', defaultValue: false)
  final bool dualCpBothOn; // Both CPs on in rapid cooling mode
  
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
    this.cp2 = false,
    required this.heater,
    required this.fan,
    required this.fanSpeed,
    required this.tempSet,
    required this.humSet,
    this.ip,
    this.cpMode = 'dual',
    this.cpActive = 1,
    this.dualCpBothOn = false,
    this.m1Start,
    this.m1Post,
    this.m2Interval,
    this.m2Run,
    this.m2Delay,
  });

  factory AhuState.fromJson(Map<String, dynamic> json) => _$AhuStateFromJson(json);
  Map<String, dynamic> toJson() => _$AhuStateToJson(this);
  
  /// Check if in dual CP mode
  bool get isDualMode => cpMode == 'dual';
  
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
  
  /// Create a copy with updated fields
  AhuState copyWith({
    bool? run,
    bool? m1,
    bool? m2,
    bool? cp,
    bool? cp2,
    bool? heater,
    bool? fan,
    int? fanSpeed,
    double? tempSet,
    double? humSet,
    String? ip,
    String? cpMode,
    int? cpActive,
    bool? dualCpBothOn,
    int? m1Start,
    int? m1Post,
    int? m2Interval,
    int? m2Run,
    int? m2Delay,
  }) {
    return AhuState(
      run: run ?? this.run,
      m1: m1 ?? this.m1,
      m2: m2 ?? this.m2,
      cp: cp ?? this.cp,
      cp2: cp2 ?? this.cp2,
      heater: heater ?? this.heater,
      fan: fan ?? this.fan,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      tempSet: tempSet ?? this.tempSet,
      humSet: humSet ?? this.humSet,
      ip: ip ?? this.ip,
      cpMode: cpMode ?? this.cpMode,
      cpActive: cpActive ?? this.cpActive,
      dualCpBothOn: dualCpBothOn ?? this.dualCpBothOn,
      m1Start: m1Start ?? this.m1Start,
      m1Post: m1Post ?? this.m1Post,
      m2Interval: m2Interval ?? this.m2Interval,
      m2Run: m2Run ?? this.m2Run,
      m2Delay: m2Delay ?? this.m2Delay,
    );
  }
}

