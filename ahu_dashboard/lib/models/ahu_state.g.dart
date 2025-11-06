// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ahu_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AhuState _$AhuStateFromJson(Map<String, dynamic> json) => AhuState(
      run: json['run'] as bool,
      m1: json['m1'] as bool,
      m2: json['m2'] as bool,
      cp: json['cp'] as bool,
      heater: json['heater'] as bool,
      fan: json['fan'] as bool,
      fanSpeed: (json['fanSpeed'] as num).toInt(),
      tempSet: (json['tempSet'] as num).toDouble(),
      humSet: (json['humSet'] as num).toDouble(),
      ip: json['ip'] as String,
      m1Start: (json['m1_start'] as num?)?.toInt(),
      m1Post: (json['m1_post'] as num?)?.toInt(),
      m2Interval: (json['m2_interval'] as num?)?.toInt(),
      m2Run: (json['m2_run'] as num?)?.toInt(),
      m2Delay: (json['m2_delay'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AhuStateToJson(AhuState instance) => <String, dynamic>{
      'run': instance.run,
      'm1': instance.m1,
      'm2': instance.m2,
      'cp': instance.cp,
      'heater': instance.heater,
      'fan': instance.fan,
      'fanSpeed': instance.fanSpeed,
      'tempSet': instance.tempSet,
      'humSet': instance.humSet,
      'ip': instance.ip,
      'm1_start': instance.m1Start,
      'm1_post': instance.m1Post,
      'm2_interval': instance.m2Interval,
      'm2_run': instance.m2Run,
      'm2_delay': instance.m2Delay,
    };
