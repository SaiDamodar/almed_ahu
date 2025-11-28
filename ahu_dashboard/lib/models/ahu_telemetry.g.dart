// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ahu_telemetry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AhuTelemetry _$AhuTelemetryFromJson(Map<String, dynamic> json) => AhuTelemetry(
      temp: (json['temp'] as num?)?.toDouble(),
      hum: (json['hum'] as num?)?.toDouble(),
      m1: json['m1'] as bool? ?? false,
      m2: json['m2'] as bool? ?? false,
      run: json['run'] as bool? ?? false,
      cp: json['cp'] as bool? ?? false,
      heater: json['heater'] as bool? ?? false,
      fan: json['fan'] as bool? ?? false,
      fanSpeed: (json['fanSpeed'] as num?)?.toInt() ?? 0,
      tempSet: (json['tempSet'] as num?)?.toDouble() ?? 22.0,
      humSet: (json['humSet'] as num?)?.toDouble() ?? 55.0,
      ts: (json['ts'] as num?)?.toInt() ?? 0,
      sensorType: json['sensorType'] as String?,
      aqi: (json['aqi'] as num?)?.toInt(),
      pm1p0: (json['pm1p0'] as num?)?.toDouble(),
      pm2p5: (json['pm2p5'] as num?)?.toDouble(),
      pm4p0: (json['pm4p0'] as num?)?.toDouble(),
      pm10p0: (json['pm10p0'] as num?)?.toDouble(),
      voc: (json['voc'] as num?)?.toDouble(),
      nox: (json['nox'] as num?)?.toDouble(),
      co2: (json['co2'] as num?)?.toInt(),
      diffPressure: (json['diffPressure'] as num?)?.toDouble(),
      hepaStatus: json['hepaStatus'] as String?,
      hepaHealth: (json['hepaHealth'] as num?)?.toInt(),
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
      'sensorType': instance.sensorType,
      'aqi': instance.aqi,
      'pm1p0': instance.pm1p0,
      'pm2p5': instance.pm2p5,
      'pm4p0': instance.pm4p0,
      'pm10p0': instance.pm10p0,
      'voc': instance.voc,
      'nox': instance.nox,
      'co2': instance.co2,
      'diffPressure': instance.diffPressure,
      'hepaStatus': instance.hepaStatus,
      'hepaHealth': instance.hepaHealth,
    };
