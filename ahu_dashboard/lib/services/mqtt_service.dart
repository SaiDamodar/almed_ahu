import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/ahu_telemetry.dart';
import '../models/ahu_state.dart';
import '../models/ahu_log.dart';
import '../models/ahu_unit.dart';

/// MQTT service for communicating with ESP32 AHU units
class MqttService {
  MqttServerClient? _client;
  final String broker;
  final int port;
  final String username;
  final String password;
  final bool useTLS;

  // Stream controllers for different message types
  final _telemetryController = StreamController<MapEntry<String, AhuTelemetry>>.broadcast();
  final _stateController = StreamController<MapEntry<String, AhuState>>.broadcast();
  final _logController = StreamController<MapEntry<String, AhuLog>>.broadcast();
  final _statusController = StreamController<MapEntry<String, String>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Public streams
  Stream<MapEntry<String, AhuTelemetry>> get telemetryStream => _telemetryController.stream;
  Stream<MapEntry<String, AhuState>> get stateStream => _stateController.stream;
  Stream<MapEntry<String, AhuLog>> get logStream => _logController.stream;
  Stream<MapEntry<String, String>> get statusStream => _statusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  MqttService({
    required this.broker,
    this.port = 1883,
    required this.username,
    required this.password,
    this.useTLS = false,
  });

  /// Connect to MQTT broker
  Future<bool> connect() async {
    try {
      final clientId = 'ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient(broker, clientId)
        ..port = port
        ..logging(on: false)
        ..keepAlivePeriod = 60
        ..onConnected = _onConnected
        ..onDisconnected = _onDisconnected
        ..onSubscribed = _onSubscribed
        ..pongCallback = _pong;

      if (useTLS) {
        _client!.secure = true;
        debugPrint('MQTT: TLS enabled for ${kIsWeb ? "web" : "native"} connection');
      }

      _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .withWillTopic('ahu_dashboard/status')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        debugPrint('MQTT: Connected to $broker:$port ${useTLS ? "(TLS)" : ""}');
        _isConnected = true;
        _connectionController.add(true);

        // Subscribe to all AHU topics
        _client!.subscribe('almed/ahu/#', MqttQos.atLeastOnce);
        _client!.updates!.listen(_onMessage);

        return true;
      } else {
        debugPrint('MQTT: Connection failed - ${_client!.connectionStatus}');
        _isConnected = false;
        _connectionController.add(false);
        return false;
      }
    } catch (e) {
      debugPrint('MQTT: Connection error - $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnect from MQTT broker
  void disconnect() {
    _client?.disconnect();
  }

  /// Subscribe to specific AHU topics
  void subscribeToAhu(AhuUnit ahu) {
    if (_client == null || !_isConnected) return;

    _client!.subscribe(ahu.telemetryTopic, MqttQos.atLeastOnce);
    _client!.subscribe(ahu.stateTopic, MqttQos.atLeastOnce);
    _client!.subscribe(ahu.logTopic, MqttQos.atLeastOnce);
    _client!.subscribe(ahu.statusTopic, MqttQos.atLeastOnce);
    _client!.subscribe(ahu.provAckTopic, MqttQos.atLeastOnce);
  }

  /// Send command to AHU
  void sendCommand(AhuUnit ahu, Map<String, dynamic> command) {
    if (_client == null || !_isConnected) return;

    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(command));
    _client!.publishMessage(ahu.cmdTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  /// Start AHU
  void startAhu(AhuUnit ahu) => sendCommand(ahu, {'start': true});

  /// Stop AHU
  void stopAhu(AhuUnit ahu) => sendCommand(ahu, {'stop': true});

  /// Toggle AHU
  void toggleAhu(AhuUnit ahu) => sendCommand(ahu, {'toggle': true});

  /// Set temperature setpoint
  void setTemperature(AhuUnit ahu, double temp) => sendCommand(ahu, {'setpoint': temp});

  /// Set humidity setpoint
  void setHumidity(AhuUnit ahu, double humidity) => sendCommand(ahu, {'humset': humidity});

  /// Set fan speed (0=OFF, 1=LOW, 2=MED, 3=HIGH)
  void setFanSpeed(AhuUnit ahu, int speed) {
    if (speed >= 0 && speed <= 3) {
      sendCommand(ahu, {'fan': speed});
    }
  }

  /// Toggle fan speed
  void toggleFanSpeed(AhuUnit ahu) => sendCommand(ahu, {'fanToggle': true});

  /// Set operation mode (true = online/cloud, false = offline/local only)
  void setMode(AhuUnit ahu, bool onlineMode) => sendCommand(ahu, {'mode': onlineMode ? 'online' : 'offline'});

  /// Set CP mode ("dual" = auto-switch every hour, "single" = use single CP)
  void setCpMode(AhuUnit ahu, String mode) => sendCommand(ahu, {'cpMode': mode});

  /// Set active CP (1 or 2) - only used in single mode
  void setCpActive(AhuUnit ahu, int cpActive) => sendCommand(ahu, {'cpActive': cpActive});

  /// Reset ESP32 (same as pressing physical reset button)
  void resetEsp32(AhuUnit ahu) => sendCommand(ahu, {'reset': true});

  /// Provision WiFi credentials
  void provisionWifi(
    AhuUnit ahu, {
    String? primarySsid,
    String? primaryPass,
    String? secondarySsid,
    String? secondaryPass,
  }) {
    if (_client == null || !_isConnected) return;

    final payload = <String, dynamic>{};

    if (primarySsid != null && primaryPass != null) {
      payload['primary'] = {'ssid': primarySsid, 'pass': primaryPass};
    }

    if (secondarySsid != null && secondaryPass != null) {
      payload['secondary'] = {'ssid': secondarySsid, 'pass': secondaryPass};
    }

    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    _client!.publishMessage(ahu.provWifiTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  /// Provision broker settings
  void provisionBroker(AhuUnit ahu, String host, int port) {
    if (_client == null || !_isConnected) return;

    final builder = MqttClientPayloadBuilder()
      ..addString(jsonEncode({'host': host, 'port': port}));
    _client!.publishMessage(ahu.provBrokerTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  /// Provision motor timings
  void provisionMotorTimings(
    AhuUnit ahu, {
    int? m1Start,
    int? m1Post,
    int? m2Interval,
    int? m2Run,
    int? m2Delay,
  }) {
    if (_client == null || !_isConnected) return;

    final payload = <String, dynamic>{};
    if (m1Start != null) payload['m1_start'] = m1Start;
    if (m1Post != null) payload['m1_post'] = m1Post;
    if (m2Interval != null) payload['m2_interval'] = m2Interval;
    if (m2Run != null) payload['m2_run'] = m2Run;
    if (m2Delay != null) payload['m2_delay'] = m2Delay;

    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    _client!.publishMessage(ahu.provMotorTimingsTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  // Callbacks
  void _onConnected() {
    debugPrint('MQTT: Connected');
    _isConnected = true;
    _connectionController.add(true);
  }

  void _onDisconnected() {
    debugPrint('MQTT: Disconnected');
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT: Subscribed to $topic');
  }

  void _pong() {
    // Keep-alive pong received
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      _processMessage(message);
    }
  }

  void _processMessage(MqttReceivedMessage<MqttMessage> message) {
    final topic = message.topic;
    final payload = message.payload as MqttPublishMessage;
    final payloadString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

    try {
      final parts = topic.split('/');
      if (parts.length < 5) return;

      final ahuId = parts[4];
      final site = parts.length > 2 ? parts[2] : 'hospitalA';
      final room = parts.length > 3 ? parts[3] : 'room1';
      final topicData = '$ahuId|$site|$room';

      if (topic.endsWith('/telemetry')) {
        final data = jsonDecode(payloadString) as Map<String, dynamic>;
        _telemetryController.add(MapEntry(topicData, AhuTelemetry.fromJson(data)));
      } else if (topic.endsWith('/state')) {
        final data = jsonDecode(payloadString) as Map<String, dynamic>;
        _stateController.add(MapEntry(topicData, AhuState.fromJson(data)));
      } else if (topic.endsWith('/log')) {
        final data = jsonDecode(payloadString) as Map<String, dynamic>;
        _logController.add(MapEntry(topicData, AhuLog.fromJson(data)));
      } else if (topic.endsWith('/status')) {
        _statusController.add(MapEntry(topicData, payloadString));
      }
    } catch (e) {
      debugPrint('MQTT: Error parsing message from $topic: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _telemetryController.close();
    _stateController.close();
    _logController.close();
    _statusController.close();
    _connectionController.close();
  }
}
