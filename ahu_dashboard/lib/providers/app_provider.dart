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
      _telemetryData[entry.key] = entry.value;
      _debouncedNotify();
    });

    // Listen to state updates
    _mqttService!.stateStream.listen((entry) {
      _stateData[entry.key] = entry.value;
      notifyListeners(); // State changes are important, notify immediately
    });

    // Listen to log updates (throttled)
    _mqttService!.logStream.listen((entry) {
      if (!_logData.containsKey(entry.key)) {
        _logData[entry.key] = [];
      }
      _logData[entry.key]!.add(entry.value);
      // Keep only last 100 logs
      if (_logData[entry.key]!.length > 100) {
        _logData[entry.key]!.removeAt(0);
      }
      _debouncedNotify();
    });

    // Listen to status updates
    _mqttService!.statusStream.listen((entry) {
      _statusData[entry.key] = entry.value;
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


