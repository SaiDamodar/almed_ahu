import 'dart:async';
import 'dart:convert';
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
  });

  /// Connect to MQTT broker
  Future<bool> connect() async {
    try {
      _client = MqttServerClient(broker, 'ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}');
      _client!.port = port;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _pong;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}')
          .authenticateAs(username, password)
          .withWillTopic('ahu_dashboard/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT: Connected to $broker:$port');
        _isConnected = true;
        _connectionController.add(true);

        // Subscribe to all AHU topics (wildcard)
        _client!.subscribe('almed/ahu/#', MqttQos.atLeastOnce);

        // Listen to messages
        _client!.updates!.listen(_onMessage);

        return true;
      } else {
        print('MQTT: Connection failed - ${_client!.connectionStatus}');
        _isConnected = false;
        _connectionController.add(false);
        return false;
      }
    } catch (e) {
      print('MQTT: Connection error - $e');
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

    final payload = jsonEncode(command);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client!.publishMessage(
      ahu.cmdTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  /// Start AHU
  void startAhu(AhuUnit ahu) {
    sendCommand(ahu, {'start': true});
  }

  /// Stop AHU
  void stopAhu(AhuUnit ahu) {
    sendCommand(ahu, {'stop': true});
  }

  /// Toggle AHU
  void toggleAhu(AhuUnit ahu) {
    sendCommand(ahu, {'toggle': true});
  }

  /// Set temperature setpoint
  void setTemperature(AhuUnit ahu, double temp) {
    sendCommand(ahu, {'setpoint': temp});
  }

  /// Set humidity setpoint
  void setHumidity(AhuUnit ahu, double humidity) {
    sendCommand(ahu, {'humset': humidity});
  }

  /// Set fan speed (0=OFF, 1=LOW, 2=MID, 3=HIGH)
  void setFanSpeed(AhuUnit ahu, int speed) {
    if (speed < 0 || speed > 3) return;
    sendCommand(ahu, {'fan': speed});
  }

  /// Provision WiFi credentials
  void provisionWifi(AhuUnit ahu, {
    String? primarySsid,
    String? primaryPass,
    String? secondarySsid,
    String? secondaryPass,
  }) {
    if (_client == null || !_isConnected) return;

    final Map<String, dynamic> payload = {};

    if (primarySsid != null && primaryPass != null) {
      payload['primary'] = {
        'ssid': primarySsid,
        'pass': primaryPass,
      };
    }

    if (secondarySsid != null && secondaryPass != null) {
      payload['secondary'] = {
        'ssid': secondarySsid,
        'pass': secondaryPass,
      };
    }

    final json = jsonEncode(payload);
    final builder = MqttClientPayloadBuilder();
    builder.addString(json);

    _client!.publishMessage(
      ahu.provWifiTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  /// Provision broker settings
  void provisionBroker(AhuUnit ahu, String host, int port) {
    if (_client == null || !_isConnected) return;

    final payload = jsonEncode({
      'host': host,
      'port': port,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client!.publishMessage(
      ahu.provBrokerTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  /// Provision motor timings (Admin only)
  void provisionMotorTimings(AhuUnit ahu, {
    int? m1Start,
    int? m1Post,
    int? m2Interval,
    int? m2Run,
    int? m2Delay,
  }) {
    if (_client == null || !_isConnected) return;

    final Map<String, dynamic> payload = {};
    if (m1Start != null) payload['m1_start'] = m1Start;
    if (m1Post != null) payload['m1_post'] = m1Post;
    if (m2Interval != null) payload['m2_interval'] = m2Interval;
    if (m2Run != null) payload['m2_run'] = m2Run;
    if (m2Delay != null) payload['m2_delay'] = m2Delay;

    final json = jsonEncode(payload);
    final builder = MqttClientPayloadBuilder();
    builder.addString(json);

    _client!.publishMessage(
      ahu.provMotorTimingsTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  // Callbacks
  void _onConnected() {
    print('MQTT: Connected');
    _isConnected = true;
    _connectionController.add(true);
  }

  void _onDisconnected() {
    print('MQTT: Disconnected');
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onSubscribed(String topic) {
    print('MQTT: Subscribed to $topic');
  }

  void _pong() {
    // Keep-alive pong received
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final payloadString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

      try {
        // Parse topic to extract AHU metadata
        // Expected format: almed/ahu/site/room/ahu-id/<type>
        final parts = topic.split('/');
        if (parts.length < 5) continue;

        final ahuId = parts[4]; // almed/ahu/site/room/ahu-id/...
        
        // Store topic metadata for later use
        final topicData = '$ahuId|${parts.length > 2 ? parts[2] : 'hospitalA'}|${parts.length > 3 ? parts[3] : 'room1'}';

        // Determine message type based on topic suffix
        if (topic.endsWith('/telemetry')) {
          final data = jsonDecode(payloadString) as Map<String, dynamic>;
          final telemetry = AhuTelemetry.fromJson(data);
          _telemetryController.add(MapEntry(topicData, telemetry));
        } else if (topic.endsWith('/state')) {
          final data = jsonDecode(payloadString) as Map<String, dynamic>;
          final state = AhuState.fromJson(data);
          _stateController.add(MapEntry(topicData, state));
        } else if (topic.endsWith('/log')) {
          final data = jsonDecode(payloadString) as Map<String, dynamic>;
          final log = AhuLog.fromJson(data);
          _logController.add(MapEntry(topicData, log));
        } else if (topic.endsWith('/status')) {
          _statusController.add(MapEntry(topicData, payloadString));
        }
      } catch (e) {
        print('MQTT: Error parsing message from $topic: $e');
      }
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


