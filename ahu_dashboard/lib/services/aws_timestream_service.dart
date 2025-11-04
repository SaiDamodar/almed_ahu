import 'dart:convert';
import 'package:http/http.dart' as http;

/// AWS Timestream Service (Replaces InfluxDB)
/// 
/// Setup:
/// 1. Add to pubspec.yaml:
///    dependencies:
///      http: ^1.0.0
/// 
/// 2. Configure AWS credentials (IAM user with Timestream read permissions)
/// 
/// 3. Get database and table names from AWS Console:
///    AWS Console → Timestream → Databases → ahu_telemetry → Tables
class TimestreamService {
  // Configuration - Replace with your values
  static const String region = 'ap-south-1';
  static const String databaseName = 'ahu_telemetry';
  static const String tableName = 'sensor_data';
  
  // AWS credentials (from IAM user or Cognito)
  final String accessKeyId;
  final String secretAccessKey;
  
  TimestreamService({
    required this.accessKeyId,
    required this.secretAccessKey,
  });
  
  /// Query historical data from Timestream
  /// 
  /// Example usage:
  /// ```dart
  /// final data = await timestream.getHistoricalData(
  ///   deviceId: 'ahu-01',
  ///   hoursBack: 24,
  ///   measureName: 'temperature',
  /// );
  /// ```
  Future<List<TelemetryDataPoint>> getHistoricalData({
    required String deviceId,
    required int hoursBack,
    required String measureName, // 'temperature' or 'humidity'
  }) async {
    try {
      // Timestream query
      final query = '''
        SELECT 
          device_id,
          measure_value::double as value,
          measure_name,
          time
        FROM $databaseName.$tableName
        WHERE device_id = '$deviceId'
          AND measure_name = '$measureName'
          AND time > ago($hoursBack h)
        ORDER BY time ASC
      ''';
      
      // Use AWS SDK or direct API call
      // For simplicity, using direct API call (you may want to use aws_timestream_query_api package)
      
      final url = Uri.parse(
        'https://query.timestream.$region.amazonaws.com/',
      );
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-amz-json-1.0',
          'X-Amz-Target': 'Timestream_20181101.Query',
          // Add AWS signature headers here
          // For production, use AWS SDK for proper signing
        },
        body: jsonEncode({
          'QueryString': query,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseTimestreamResponse(data);
      } else {
        print('TimestreamService: Query failed - ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('TimestreamService: Query error - $e');
      return [];
    }
  }
  
  /// Get aggregated data (average, min, max) for a time period
  Future<Map<String, double>> getAggregatedData({
    required String deviceId,
    required int hoursBack,
    required String measureName,
    String aggregation = 'AVG', // AVG, MIN, MAX, SUM
  }) async {
    try {
      final query = '''
        SELECT 
          $aggregation(measure_value::double) as value
        FROM $databaseName.$tableName
        WHERE device_id = '$deviceId'
          AND measure_name = '$measureName'
          AND time > ago($hoursBack h)
      ''';
      
      // Execute query (similar to getHistoricalData)
      // Return aggregated value
      
      return {
        'value': 0.0, // Replace with actual query result
      };
    } catch (e) {
      print('TimestreamService: Aggregation error - $e');
      return {};
    }
  }
  
  /// Get data for multiple devices
  Future<Map<String, List<TelemetryDataPoint>>> getMultiDeviceData({
    required List<String> deviceIds,
    required int hoursBack,
    required String measureName,
  }) async {
    final Map<String, List<TelemetryDataPoint>> result = {};
    
    for (final deviceId in deviceIds) {
      final data = await getHistoricalData(
        deviceId: deviceId,
        hoursBack: hoursBack,
        measureName: measureName,
      );
      result[deviceId] = data;
    }
    
    return result;
  }
  
  /// Parse Timestream query response
  List<TelemetryDataPoint> _parseTimestreamResponse(Map<String, dynamic> response) {
    final List<TelemetryDataPoint> points = [];
    
    // Parse response format
    // Timestream returns data in a specific format
    // Adjust based on actual response structure
    
    return points;
  }
}

/// Data point model for telemetry
class TelemetryDataPoint {
  final String deviceId;
  final double value;
  final String measureName;
  final DateTime timestamp;
  
  TelemetryDataPoint({
    required this.deviceId,
    required this.value,
    required this.measureName,
    required this.timestamp,
  });
  
  factory TelemetryDataPoint.fromJson(Map<String, dynamic> json) {
    return TelemetryDataPoint(
      deviceId: json['device_id'] as String,
      value: (json['value'] as num).toDouble(),
      measureName: json['measure_name'] as String,
      timestamp: DateTime.parse(json['time'] as String),
    );
  }
}

