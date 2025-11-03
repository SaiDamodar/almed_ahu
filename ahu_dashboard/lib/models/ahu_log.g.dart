// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ahu_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AhuLog _$AhuLogFromJson(Map<String, dynamic> json) => AhuLog(
      ts: (json['ts'] as num).toInt(),
      lvl: json['lvl'] as String,
      msg: json['msg'] as String,
    );

Map<String, dynamic> _$AhuLogToJson(AhuLog instance) => <String, dynamic>{
      'ts': instance.ts,
      'lvl': instance.lvl,
      'msg': instance.msg,
    };

