// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ahu_telemetry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AhuTelemetry _$AhuTelemetryFromJson(Map<String, dynamic> json) => AhuTelemetry(
      temp: (json['temp'] as num?)?.toDouble(),
      hum: (json['hum'] as num?)?.toDouble(),
      m1: json['m1'] as bool,
      m2: json['m2'] as bool,
      run: json['run'] as bool,
      cp: json['cp'] as bool,
      heater: json['heater'] as bool,
      fan: json['fan'] as bool,
      fanSpeed: (json['fanSpeed'] as num).toInt(),
      tempSet: (json['tempSet'] as num).toDouble(),
      humSet: (json['humSet'] as num).toDouble(),
      ts: (json['ts'] as num).toInt(),
    );

Map<String, dynamic> _$AhuTelemetryToJson(AhuTelemetry instance) =>
    <String, dynamic>{
      'temp': instance.temp,
      'hum': instance.hum,
      'm1': instance.m1,
      'm2': instance.m2,
      'run': instance.run,
      'cp': instance.cp,
      'heater': instance.heater,
      'fan': instance.fan,
      'fanSpeed': instance.fanSpeed,
      'tempSet': instance.tempSet,
      'humSet': instance.humSet,
      'ts': instance.ts,
    };

