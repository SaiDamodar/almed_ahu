import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/hospital.dart';
import '../models/device_status.dart';

/// API Service for communicating with web dashboard
class ApiService {
  String? _sessionCookie;
  String? _lastError;
  
  String? get errorMessage => _lastError;
  
  /// Login and get session cookie
  Future<bool> login(String username, String password) async {
    try {
      print('Login: Attempting to login to ${AppConfig.loginEndpoint}');
      print('Login: Username: $username, Password: ${password.isNotEmpty ? '***' : 'empty'}');
      
      final response = await http.post(
        Uri.parse(AppConfig.loginEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      print('Login: Response status: ${response.statusCode}');
      print('Login: Response headers: ${response.headers}');
      print('Login: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Extract session cookie from Set-Cookie header
          final cookies = response.headers['set-cookie'];
          if (cookies != null) {
            _sessionCookie = cookies.split(';').first;
            print('Login: Session cookie stored');
          }
          print('Login: Success');
          return true;
        } else {
          print('Login: Failed - ${data['message'] ?? 'Unknown error'}');
          return false;
        }
      } else {
        // Try to parse error message
        try {
          final data = jsonDecode(response.body);
          print('Login: Failed with status ${response.statusCode} - ${data['message'] ?? 'Unknown error'}');
        } catch (e) {
          print('Login: Failed with status ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } on SocketException catch (e) {
      _lastError = e.message;
      print('Login error: DNS/Network error - ${e.message}');
      print('This usually means:');
      print('1. No internet connection');
      print('2. DNS cannot resolve Railway domain');
      print('3. Mobile carrier blocking the domain');
      print('Solution: Check internet connection or try using WiFi');
      return false;
    } catch (e, stackTrace) {
      _lastError = e.toString();
      print('Login error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Get all devices grouped by hospital
  Future<Map<String, Hospital>> getDevices() async {
    try {
      final response = await _authenticatedRequest(
        Uri.parse(AppConfig.devicesEndpoint),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['hospitals'] != null) {
          final hospitals = <String, Hospital>{};
          final hospitalsData = data['hospitals'] as Map<String, dynamic>;
          
          hospitalsData.forEach((siteId, roomsData) {
            // Parse rooms structure from web dashboard API
            // Format: { "hospitalA": { "icu1": [devices...], "room2": [devices...] } }
            final rooms = <String, List<AhuDevice>>{};
            if (roomsData is Map) {
              roomsData.forEach((roomId, devices) {
                if (devices is List) {
                  rooms[roomId] = (devices as List)
                      .map((d) {
                        // Ensure device has required fields
                        final deviceMap = d as Map<String, dynamic>;
                        if (!deviceMap.containsKey('status')) {
                          // Try to determine status from last_seen
                          final lastSeen = deviceMap['last_seen'];
                          if (lastSeen != null) {
                            final lastSeenTime = lastSeen is int 
                                ? DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000)
                                : DateTime.tryParse(lastSeen.toString());
                            if (lastSeenTime != null) {
                              final diff = DateTime.now().difference(lastSeenTime);
                              deviceMap['status'] = diff.inMinutes < 5 ? 'online' : 'offline';
                            }
                          }
                        }
                        return AhuDevice.fromJson(deviceMap);
                      })
                      .toList();
                }
              });
            }
            
            hospitals[siteId] = Hospital(
              id: siteId,
              name: _formatHospitalName(siteId),
              rooms: rooms,
            );
          });
          
          return hospitals;
        }
      }
      return {};
    } catch (e) {
      print('Get devices error: $e');
      return {};
    }
  }
  
  /// Get device status (telemetry + state)
  Future<DeviceStatus?> getDeviceStatus(String deviceId) async {
    try {
      final response = await _authenticatedRequest(
        Uri.parse(AppConfig.deviceStatusEndpoint(deviceId)),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          try {
            return DeviceStatus.fromJson(data['data'] as Map<String, dynamic>);
          } catch (e, stackTrace) {
            print('Error parsing device status for $deviceId: $e');
            print('Stack trace: $stackTrace');
            print('Data received: ${data['data']}');
            return null;
          }
        }
      }
      return null;
    } catch (e, stackTrace) {
      print('Get device status error for $deviceId: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Send command to device via AWS IoT Core (esp32/sub topic)
  Future<bool> sendCommand(String deviceId, Map<String, dynamic> command) async {
    try {
      // ESP32 expects the command directly, not wrapped in 'command' key
      // The web dashboard sends: json.dumps(command) directly
      // So we just send the command object as-is
      final response = await _authenticatedRequest(
        Uri.parse(AppConfig.deviceCommandEndpoint(deviceId)),
        method: 'POST',
        body: jsonEncode({'command': command}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Send command error: $e');
      return false;
    }
  }
  
  /// Helper: Make authenticated HTTP request
  Future<http.Response> _authenticatedRequest(
    Uri url, {
    String method = 'GET',
    String? body,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    
    switch (method.toUpperCase()) {
      case 'POST':
        return await http.post(url, headers: headers, body: body);
      case 'PUT':
        return await http.put(url, headers: headers, body: body);
      case 'DELETE':
        return await http.delete(url, headers: headers);
      default:
        return await http.get(url, headers: headers);
    }
  }
  
  /// Format hospital name for display
  String _formatHospitalName(String siteId) {
    // Convert "hospitalA" -> "Hospital A"
    if (siteId.startsWith('hospital')) {
      final suffix = siteId.substring(8);
      return 'Hospital ${suffix.toUpperCase()}';
    }
    return siteId.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    ).trim();
  }
  
  /// Logout (clear session)
  void logout() {
    _sessionCookie = null;
  }
}

