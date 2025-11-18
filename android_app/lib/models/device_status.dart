import 'ahu_state.dart';
import 'ahu_telemetry.dart';

/// Combined device status response from API
class DeviceStatus {
  final String deviceId;
  final String status; // 'online' or 'offline'
  final AhuTelemetry? telemetry;
  final AhuState? state;
  final int? lastUpdate; // Unix timestamp

  DeviceStatus({
    required this.deviceId,
    required this.status,
    this.telemetry,
    this.state,
    this.lastUpdate,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    // Handle last_update which can be int, double, or null
    int? parseLastUpdate(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }
    
    return DeviceStatus(
      deviceId: json['device_id'] as String? ?? json['deviceId'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      telemetry: json['telemetry'] != null
          ? AhuTelemetry.fromJson(json['telemetry'] as Map<String, dynamic>)
          : null,
      state: json['state'] != null
          ? AhuState.fromJson(json['state'] as Map<String, dynamic>)
          : null,
      lastUpdate: parseLastUpdate(json['last_update']),
    );
  }

  bool get isOnline {
    // Match web dashboard logic: online if status is 'online' OR last_update is within 5 minutes
    if (status == 'online') {
      return true;
    }
    
    if (lastUpdate != null && lastUpdate! > 0) {
      // lastUpdate from API is in seconds (Unix timestamp)
      // Convert to DateTime and check if within 5 minutes (300 seconds)
      try {
        final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch((lastUpdate! * 1000).toInt());
        final now = DateTime.now();
        final diff = now.difference(lastUpdateTime);
        // Consider online if data is less than 5 minutes old (matching web dashboard)
        final isRecent = diff.inSeconds < 300;
        
        // Debug logging
        if (!isRecent) {
          print('Device $deviceId: lastUpdate=${lastUpdate}, diff=${diff.inSeconds}s, isOnline=false');
        }
        
        return isRecent;
      } catch (e) {
        print('Error calculating isOnline for $deviceId: $e');
        // Fall back to status field if timestamp parsing fails
        return status == 'online';
      }
    }
    
    // If no lastUpdate or lastUpdate is 0, check if we have recent telemetry/state data
    // If we have telemetry or state data, device might be online but timestamp missing
    if (telemetry != null || state != null) {
      // If we have data but no timestamp, assume it's recent (within polling interval)
      // This handles cases where last_update is missing but data exists
      return true;
    }
    
    // If no lastUpdate and no data, fall back to status field
    return status == 'online';
  }
  
  /// Get temperature (from telemetry or state)
  double? get temperature => telemetry?.temp ?? state?.tempSet;
  
  /// Get humidity (from telemetry or state)
  double? get humidity => telemetry?.hum ?? state?.humSet;
  
  /// Get temperature setpoint
  double get tempSetpoint => state?.tempSet ?? telemetry?.tempSet ?? 22.0;
  
  /// Get humidity setpoint
  double get humSetpoint => state?.humSet ?? telemetry?.humSet ?? 55.0;
  
  /// Is system running
  bool get isRunning => state?.run ?? telemetry?.run ?? false;
}

