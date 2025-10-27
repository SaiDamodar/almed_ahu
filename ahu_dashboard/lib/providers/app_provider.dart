import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ahu_unit.dart';
import '../models/ahu_telemetry.dart';
import '../models/ahu_state.dart';
import '../models/ahu_log.dart';
import '../models/user_role.dart';
import '../services/mqtt_service.dart';

/// Main application state provider with optimized updates
class AppProvider extends ChangeNotifier {
  Timer? _debounceTimer;
  MqttService? _mqttService;
  UserRole? _currentRole;
  final Map<String, AhuUnit> _ahuUnits = {};
  final Map<String, AhuTelemetry> _telemetryData = {};
  final Map<String, AhuState> _stateData = {};
  final Map<String, List<AhuLog>> _logData = {};
  final Map<String, String> _statusData = {};
  bool _isConnected = false;

  // Getters
  UserRole? get currentRole => _currentRole;
  bool get isConnected => _isConnected;
  List<AhuUnit> get ahuUnits => _ahuUnits.values.toList();
  MqttService? get mqttService => _mqttService;

  /// Get telemetry for specific AHU
  AhuTelemetry? getTelemetry(String ahuId) => _telemetryData[ahuId];

  /// Get state for specific AHU
  AhuState? getState(String ahuId) => _stateData[ahuId];

  /// Get logs for specific AHU
  List<AhuLog> getLogs(String ahuId) => _logData[ahuId] ?? [];

  /// Get status for specific AHU
  String? getStatus(String ahuId) => _statusData[ahuId];

  /// Set user role
  void setUserRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  /// Initialize MQTT connection
  Future<bool> initializeMqtt({
    String broker = '127.0.0.1',
    int port = 1883,
    String username = 'almed',
    String password = 'Almed1234\$',
  }) async {
    _mqttService = MqttService(
      broker: broker,
      port: port,
      username: username,
      password: password,
    );

    // Listen to connection status
    _mqttService!.connectionStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });

    // Listen to telemetry updates (debounced for performance)
    _mqttService!.telemetryStream.listen((entry) {
      final parts = entry.key.split('|');
      final ahuId = parts.isNotEmpty ? parts[0] : entry.key;
      
      _ensureAhuRegistered(entry.key);
      _telemetryData[ahuId] = entry.value;
      _debouncedNotify();
    });

    // Listen to state updates
    _mqttService!.stateStream.listen((entry) {
      final parts = entry.key.split('|');
      final ahuId = parts.isNotEmpty ? parts[0] : entry.key;
      
      _ensureAhuRegistered(entry.key);
      _stateData[ahuId] = entry.value;
      notifyListeners(); // State changes are important, notify immediately
    });

    // Listen to log updates (throttled)
    _mqttService!.logStream.listen((entry) {
      final parts = entry.key.split('|');
      final ahuId = parts.isNotEmpty ? parts[0] : entry.key;
      
      _ensureAhuRegistered(entry.key);
      if (!_logData.containsKey(ahuId)) {
        _logData[ahuId] = [];
      }
      _logData[ahuId]!.add(entry.value);
      // Keep only last 100 logs
      if (_logData[ahuId]!.length > 100) {
        _logData[ahuId]!.removeAt(0);
      }
      _debouncedNotify();
    });

    // Listen to status updates
    _mqttService!.statusStream.listen((entry) {
      final parts = entry.key.split('|');
      final ahuId = parts.isNotEmpty ? parts[0] : entry.key;
      
      _ensureAhuRegistered(entry.key);
      _statusData[ahuId] = entry.value;
      notifyListeners(); // Status changes are important
    });

    final connected = await _mqttService!.connect();
    return connected;
  }

  /// Debounced notify to reduce UI rebuilds
  void _debouncedNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      notifyListeners();
    });
  }

  /// Add AHU unit to monitor
  void addAhuUnit(AhuUnit ahu) {
    _ahuUnits[ahu.id] = ahu;
    _mqttService?.subscribeToAhu(ahu);
    notifyListeners();
  }

  /// Remove AHU unit
  void removeAhuUnit(String ahuId) {
    _ahuUnits.remove(ahuId);
    _telemetryData.remove(ahuId);
    _stateData.remove(ahuId);
    _logData.remove(ahuId);
    _statusData.remove(ahuId);
    notifyListeners();
  }

  /// Load default AHU units (from your ESP32 config)
  void loadDefaultAhus() {
    // Default AHU from your ESP32 code
    final defaultAhu = AhuUnit(
      id: 'ahu-01',
      name: 'ICU-1 AHU',
      site: 'hospitalA',
      room: 'icu1',
      org: 'almed',
    );
    addAhuUnit(defaultAhu);
  }

  /// Auto-discover and register AHU when data arrives from unknown ID
  /// topicData format: "ahuId|site|room"
  void _ensureAhuRegistered(String topicData, {String? site, String? room}) {
    // Parse topic data: format is "ahuId|site|room"
    final parts = topicData.split('|');
    final ahuId = parts.isNotEmpty ? parts[0] : topicData;
    final discoveredSite = parts.length > 1 ? parts[1] : (site ?? 'hospitalA');
    final discoveredRoom = parts.length > 2 ? parts[2] : (room ?? 'room1');
    
    if (_ahuUnits.containsKey(ahuId)) return;
    
    // Create new AHU unit automatically
    final newAhu = AhuUnit(
      id: ahuId,
      name: 'AHU ${ahuId.replaceAll('ahu-', '').toUpperCase()}',
      site: discoveredSite,
      room: discoveredRoom,
      org: 'almed',
    );
    
    addAhuUnit(newAhu);
    print('AppProvider: Auto-discovered new AHU - $ahuId at $discoveredSite/$discoveredRoom');
  }

  /// Start AHU
  void startAhu(String ahuId) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.startAhu(ahu);
    }
  }

  /// Stop AHU
  void stopAhu(String ahuId) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.stopAhu(ahu);
    }
  }

  /// Toggle AHU
  void toggleAhu(String ahuId) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.toggleAhu(ahu);
    }
  }

  /// Set temperature setpoint
  void setTemperature(String ahuId, double temp) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.setTemperature(ahu, temp);
    }
  }

  /// Set humidity setpoint
  void setHumidity(String ahuId, double humidity) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.setHumidity(ahu, humidity);
    }
  }

  /// Provision WiFi (admin only)
  void provisionWifi(
    String ahuId, {
    String? primarySsid,
    String? primaryPass,
    String? secondarySsid,
    String? secondaryPass,
  }) {
    if (_currentRole != UserRole.admin) return;
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.provisionWifi(
        ahu,
        primarySsid: primarySsid,
        primaryPass: primaryPass,
        secondarySsid: secondarySsid,
        secondaryPass: secondaryPass,
      );
    }
  }

  /// Provision broker (admin only)
  void provisionBroker(String ahuId, String host, int port) {
    if (_currentRole != UserRole.admin) return;
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.provisionBroker(ahu, host, port);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mqttService?.dispose();
    super.dispose();
  }
}


