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
  
  // Cache for frequently accessed data
  List<AhuUnit>? _cachedAhuUnits;
  bool _ahuUnitsChanged = true;

  // Getters
  UserRole? get currentRole => _currentRole;
  bool get isConnected => _isConnected;
  MqttService? get mqttService => _mqttService;
  
  /// Get AHU units list with caching
  List<AhuUnit> get ahuUnits {
    if (_ahuUnitsChanged || _cachedAhuUnits == null) {
      _cachedAhuUnits = List.unmodifiable(_ahuUnits.values.toList());
      _ahuUnitsChanged = false;
    }
    return _cachedAhuUnits!;
  }

  /// Get telemetry for specific AHU
  AhuTelemetry? getTelemetry(String ahuId) => _telemetryData[ahuId];

  /// Get state for specific AHU
  AhuState? getState(String ahuId) => _stateData[ahuId];

  /// Get logs for specific AHU
  List<AhuLog> getLogs(String ahuId) => _logData[ahuId] ?? const [];

  /// Get status for specific AHU
  String? getStatus(String ahuId) => _statusData[ahuId];

  /// Set user role
  void setUserRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  /// Initialize MQTT connection
  Future<bool> initializeMqtt({
    String? broker,
    int? port,
    String? username,
    String? password,
  }) async {
    final defaultBroker = broker ?? '10.42.0.1';
    
    _mqttService = MqttService(
      broker: defaultBroker,
      port: port ?? 1883,
      username: username ?? 'almed',
      password: password ?? 'Almed1234\$',
      useTLS: false,
    );
    
    debugPrint('AppProvider: Initializing MQTT - Connecting to Raspberry Pi bridge at $defaultBroker:${port ?? 1883}');

    // Listen to connection status
    _mqttService!.connectionStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });

    // Listen to telemetry updates (debounced for performance)
    _mqttService!.telemetryStream.listen((entry) {
      final ahuId = _extractAhuId(entry.key);
      _ensureAhuRegistered(entry.key);
      _telemetryData[ahuId] = entry.value;
      _debouncedNotify();
    });

    // Listen to state updates
    _mqttService!.stateStream.listen((entry) {
      final ahuId = _extractAhuId(entry.key);
      _ensureAhuRegistered(entry.key);
      _stateData[ahuId] = entry.value;
      notifyListeners();
    });

    // Listen to log updates (throttled)
    _mqttService!.logStream.listen((entry) {
      final ahuId = _extractAhuId(entry.key);
      _ensureAhuRegistered(entry.key);
      
      final logs = _logData.putIfAbsent(ahuId, () => []);
      logs.add(entry.value);
      
      // Keep only last 100 logs
      if (logs.length > 100) {
        logs.removeAt(0);
      }
      _debouncedNotify();
    });

    // Listen to status updates
    _mqttService!.statusStream.listen((entry) {
      final ahuId = _extractAhuId(entry.key);
      _ensureAhuRegistered(entry.key);
      _statusData[ahuId] = entry.value;
      notifyListeners();
    });

    final connected = await _mqttService!.connect();
    return connected;
  }
  
  /// Extract AHU ID from topic data
  String _extractAhuId(String topicData) {
    final parts = topicData.split('|');
    return parts.isNotEmpty ? parts[0] : topicData;
  }

  /// Debounced notify to reduce UI rebuilds
  void _debouncedNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), notifyListeners);
  }

  /// Add AHU unit to monitor
  void addAhuUnit(AhuUnit ahu) {
    _ahuUnits[ahu.id] = ahu;
    _ahuUnitsChanged = true;
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
    _ahuUnitsChanged = true;
    notifyListeners();
  }

  /// Load default AHU units
  void loadDefaultAhus() {
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
  void _ensureAhuRegistered(String topicData, {String? site, String? room}) {
    final parts = topicData.split('|');
    final ahuId = parts.isNotEmpty ? parts[0] : topicData;
    final discoveredSite = parts.length > 1 ? parts[1] : (site ?? 'hospitalA');
    final discoveredRoom = parts.length > 2 ? parts[2] : (room ?? 'room1');
    
    if (_ahuUnits.containsKey(ahuId)) return;
    
    final newAhu = AhuUnit(
      id: ahuId,
      name: 'AHU ${ahuId.replaceAll('ahu-', '').toUpperCase()}',
      site: discoveredSite,
      room: discoveredRoom,
      org: 'almed',
    );
    
    addAhuUnit(newAhu);
    debugPrint('AppProvider: Auto-discovered new AHU - $ahuId at $discoveredSite/$discoveredRoom');
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

  /// Set fan speed (0=OFF, 1=LOW, 2=MED, 3=HIGH)
  void setFanSpeed(String ahuId, int speed) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.setFanSpeed(ahu, speed);
    }
  }

  /// Toggle fan speed
  void toggleFanSpeed(String ahuId) {
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.toggleFanSpeed(ahu);
    }
  }

  /// Set operation mode (Admin only)
  void setMode(String ahuId, bool onlineMode) {
    if (_currentRole != UserRole.admin) return;
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      _mqttService?.setMode(ahu, onlineMode);
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

  /// Provision motor timings (admin only)
  void provisionMotorTimings(String ahuId, {
    int? m1Start,
    int? m1Post,
    int? m2Interval,
    int? m2Run,
    int? m2Delay,
  }) {
    if (_currentRole != UserRole.admin) return;
    final ahu = _ahuUnits[ahuId];
    if (ahu != null) {
      final waitTime = m2Interval ?? 30;
      final m2RunTime = m2Run ?? 10;
      final actualInterval = waitTime + m2RunTime;
      
      debugPrint('AppProvider: M2 Interval calculation - Wait: ${waitTime}s + Run: ${m2RunTime}s = Actual: ${actualInterval}s');
      
      _mqttService?.provisionMotorTimings(
        ahu,
        m1Start: m1Start,
        m1Post: m1Post,
        m2Interval: actualInterval,
        m2Run: m2Run,
        m2Delay: m2Delay,
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mqttService?.dispose();
    super.dispose();
  }
}
