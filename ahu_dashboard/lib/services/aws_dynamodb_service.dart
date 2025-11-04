import 'dart:convert';
import 'package:http/http.dart' as http;

/// AWS DynamoDB Service (Replaces Firestore for device state)
/// 
/// Setup:
/// 1. Add to pubspec.yaml:
///    dependencies:
///      http: ^1.0.0
/// 
/// 2. Configure AWS credentials (IAM user with DynamoDB read/write permissions)
/// 
/// 3. Table names:
///    - ahu-device-state: Real-time device state
///    - ahu-user-assignments: User device assignments
class DynamoDBService {
  // Configuration
  static const String region = 'ap-south-1';
  static const String deviceStateTable = 'ahu-device-state';
  static const String userAssignmentsTable = 'ahu-user-assignments';
  
  // AWS credentials
  final String accessKeyId;
  final String secretAccessKey;
  
  DynamoDBService({
    required this.accessKeyId,
    required this.secretAccessKey,
  });
  
  /// Get device state from DynamoDB
  /// 
  /// Example usage:
  /// ```dart
  /// final state = await dynamodb.getDeviceState('ahu-01');
  /// ```
  Future<Map<String, dynamic>?> getDeviceState(String deviceId) async {
    try {
      final url = Uri.parse(
        'https://dynamodb.$region.amazonaws.com/',
      );
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-amz-json-1.0',
          'X-Amz-Target': 'DynamoDB_20120810.GetItem',
          // Add AWS signature headers here
          // For production, use AWS SDK for proper signing
        },
        body: jsonEncode({
          'TableName': deviceStateTable,
          'Key': {
            'device_id': {'S': deviceId},
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Item'] != null) {
          return _parseDynamoDBItem(data['Item']);
        }
        return null;
      } else {
        print('DynamoDBService: Get item failed - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('DynamoDBService: Get device state error - $e');
      return null;
    }
  }
  
  /// Get all device states
  Future<List<Map<String, dynamic>>> getAllDeviceStates() async {
    try {
      final url = Uri.parse(
        'https://dynamodb.$region.amazonaws.com/',
      );
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-amz-json-1.0',
          'X-Amz-Target': 'DynamoDB_20120810.Scan',
          // Add AWS signature headers
        },
        body: jsonEncode({
          'TableName': deviceStateTable,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> states = [];
        
        if (data['Items'] != null) {
          for (final item in data['Items']) {
            states.add(_parseDynamoDBItem(item));
          }
        }
        
        return states;
      } else {
        print('DynamoDBService: Scan failed - ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('DynamoDBService: Get all device states error - $e');
      return [];
    }
  }
  
  /// Get user device assignments
  Future<List<String>> getUserAssignedDevices(String userId) async {
    try {
      final url = Uri.parse(
        'https://dynamodb.$region.amazonaws.com/',
      );
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-amz-json-1.0',
          'X-Amz-Target': 'DynamoDB_20120810.GetItem',
          // Add AWS signature headers
        },
        body: jsonEncode({
          'TableName': userAssignmentsTable,
          'Key': {
            'user_id': {'S': userId},
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Item'] != null) {
          final item = _parseDynamoDBItem(data['Item']);
          final devicesStr = item['assigned_devices'] as String? ?? '';
          if (devicesStr.isEmpty) return [];
          return devicesStr.split(',');
        }
        return [];
      } else {
        print('DynamoDBService: Get user assignments failed - ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('DynamoDBService: Get user assignments error - $e');
      return [];
    }
  }
  
  /// Update user device assignments
  Future<bool> updateUserAssignments({
    required String userId,
    required List<String> deviceIds,
  }) async {
    try {
      final url = Uri.parse(
        'https://dynamodb.$region.amazonaws.com/',
      );
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/x-amz-json-1.0',
          'X-Amz-Target': 'DynamoDB_20120810.PutItem',
          // Add AWS signature headers
        },
        body: jsonEncode({
          'TableName': userAssignmentsTable,
          'Item': {
            'user_id': {'S': userId},
            'assigned_devices': {'S': deviceIds.join(',')},
            'updated_at': {'S': DateTime.now().toIso8601String()},
          },
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('DynamoDBService: Update user assignments error - $e');
      return false;
    }
  }
  
  /// Parse DynamoDB item format to Dart Map
  Map<String, dynamic> _parseDynamoDBItem(Map<String, dynamic> item) {
    final Map<String, dynamic> result = {};
    
    item.forEach((key, value) {
      if (value is Map) {
        // DynamoDB format: {'S': 'string'}, {'N': '123'}, {'B': base64}, etc.
        if (value.containsKey('S')) {
          result[key] = value['S'] as String;
        } else if (value.containsKey('N')) {
          result[key] = num.parse(value['N'] as String);
        } else if (value.containsKey('BOOL')) {
          result[key] = value['BOOL'] as bool;
        } else if (value.containsKey('M')) {
          result[key] = _parseDynamoDBItem(value['M'] as Map<String, dynamic>);
        }
      }
    });
    
    return result;
  }
}

