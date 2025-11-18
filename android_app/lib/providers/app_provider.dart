import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/hospital.dart';
import '../models/device_status.dart';
import '../services/api_service.dart';
import '../services/aws_iot_service.dart';

/// Main app state provider
class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AwsIoTService _awsIoTService = AwsIoTService();
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _useDirectAws = false; // Toggle between Flask API and direct AWS IoT
  
  // Data
  Map<String, Hospital> _hospitals = {};
  Map<String, DeviceStatus> _deviceStatuses = {};
  Timer? _statusPollTimer;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, Hospital> get hospitals => _hospitals;
  List<Hospital> get hospitalsList => _hospitals.values.toList();
  
  DeviceStatus? getDeviceStatus(String deviceId) {
    // Try AWS IoT first if connected, otherwise fall back to API cache
    if (_useDirectAws && _awsIoTService.isConnected) {
      return _awsIoTService.getDeviceStatus(deviceId) ?? _deviceStatuses[deviceId];
    }
    return _deviceStatuses[deviceId];
  }
  
  bool get useDirectAws => _useDirectAws;
  bool get awsConnected => _awsIoTService.isConnected;
  
  /// Login
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final success = await _apiService.login(username, password);
      if (success) {
        _isAuthenticated = true;
        
        // Connect to AWS IoT Core directly
        await connectToAwsIoT();
        
        await loadHospitals();
        _startPolling();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Invalid username or password');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  /// Connect to AWS IoT Core directly
  Future<void> connectToAwsIoT() async {
    try {
      // Set up callbacks
      _awsIoTService.onDeviceUpdate = (deviceId, status) {
        _deviceStatuses[deviceId] = status;
        notifyListeners();
      };
      
      _awsIoTService.onConnectionChanged = (connected) {
        _useDirectAws = connected;
        notifyListeners();
      };
      
      // Connect
      final connected = await _awsIoTService.connect();
      if (connected) {
        _useDirectAws = true;
        print('Connected to AWS IoT Core directly');
      } else {
        print('Failed to connect to AWS IoT Core, using Flask API');
        _useDirectAws = false;
      }
    } catch (e) {
      print('AWS IoT connection error: $e');
      _useDirectAws = false;
    }
  }
  
  /// Logout
  void logout() {
    _stopPolling();
    _awsIoTService.disconnect();
    _apiService.logout();
    _isAuthenticated = false;
    _useDirectAws = false;
    _hospitals.clear();
    _deviceStatuses.clear();
    _setError(null);
    notifyListeners();
  }
  
  /// Load hospitals and devices
  Future<void> loadHospitals() async {
    try {
      final hospitals = await _apiService.getDevices();
      _hospitals = hospitals;
      
      // Load status for all devices
      for (final hospital in hospitals.values) {
        for (final ahu in hospital.allAhus) {
          await loadDeviceStatus(ahu.id);
        }
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load devices: ${e.toString()}');
    }
  }
  
  /// Load device status
  Future<void> loadDeviceStatus(String deviceId) async {
    try {
      final status = await _apiService.getDeviceStatus(deviceId);
      if (status != null) {
        _deviceStatuses[deviceId] = status;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading device status: $e');
    }
  }
  
  /// Send command to device
  Future<bool> sendCommand(String deviceId, Map<String, dynamic> command) async {
    try {
      // Try AWS IoT first if connected, otherwise use Flask API
      if (_useDirectAws && _awsIoTService.isConnected) {
        final success = await _awsIoTService.publishCommand(deviceId, command);
        if (success) {
          // Wait a bit for status update
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return success;
      } else {
        // Fall back to Flask API
        final success = await _apiService.sendCommand(deviceId, command);
        if (success) {
          await loadDeviceStatus(deviceId);
        }
        return success;
      }
    } catch (e) {
      _setError('Failed to send command: ${e.toString()}');
      return false;
    }
  }
  
  /// Toggle AHU system (start/stop)
  Future<void> toggleAhu(String deviceId) async {
    final status = _deviceStatuses[deviceId];
    if (status == null) return;
    
    // ESP32 expects "start": true or "stop": true, not "run"
    final command = status.isRunning
        ? {'stop': true}
        : {'start': true};
    
    await sendCommand(deviceId, command);
  }
  
  /// Set temperature setpoint
  Future<void> setTemperature(String deviceId, double temp) async {
    // ESP32 expects "setpoint" not "tempSet"
    final command = {
      'setpoint': temp,
    };
    
    await sendCommand(deviceId, command);
  }
  
  /// Set humidity setpoint
  Future<void> setHumidity(String deviceId, double hum) async {
    // ESP32 expects "humset" (lowercase) not "humSet"
    final command = {
      'humset': hum,
    };
    
    await sendCommand(deviceId, command);
  }
  
  /// Set fan speed (0=OFF, 1=LOW, 2=MED, 3=HIGH)
  Future<void> setFanSpeed(String deviceId, int speed) async {
    if (speed < 0 || speed > 3) return;
    
    // ESP32 expects "fan" not "fanSpeed"
    final command = {
      'fan': speed,
    };
    
    await sendCommand(deviceId, command);
  }
  
  /// Start polling for device status updates
  void _startPolling() {
    _stopPolling();
    // Poll every 3 seconds for faster updates
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        // Poll all devices
        for (final hospital in _hospitals.values) {
          for (final ahu in hospital.allAhus) {
            loadDeviceStatus(ahu.id);
          }
        }
      },
    );
  }
  
  /// Force refresh all device statuses
  Future<void> refreshAllDevices() async {
    for (final hospital in _hospitals.values) {
      for (final ahu in hospital.allAhus) {
        await loadDeviceStatus(ahu.id);
      }
    }
    notifyListeners();
  }
  
  /// Stop polling
  void _stopPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _stopPolling();
    _awsIoTService.disconnect();
    super.dispose();
  }
}

