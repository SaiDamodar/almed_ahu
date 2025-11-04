import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// AWS IoT Core MQTT Service (Replaces HiveMQ Cloud)
/// 
/// Setup:
/// 1. For native platforms (Android/iOS): Use certificates
/// 2. For web: Use WebSocket with SigV4 signing (complex, consider using API Gateway)
/// 
/// Recommended: Use native mobile apps with certificates, web via API Gateway
class AwsMqttService {
  MqttServerClient? _client;
  
  // AWS IoT Core endpoint (get from AWS Console)
  final String awsIotEndpoint;
  final int awsIotPort;
  
  // Certificate paths (for native platforms)
  final String? rootCA;
  final String? clientCert;
  final String? clientKey;
  
  // Stream controllers
  final _telemetryController = StreamController<MapEntry<String, Map<String, dynamic>>>.broadcast();
  final _stateController = StreamController<MapEntry<String, Map<String, dynamic>>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  
  // Public streams
  Stream<MapEntry<String, Map<String, dynamic>>> get telemetryStream => _telemetryController.stream;
  Stream<MapEntry<String, Map<String, dynamic>>> get stateStream => _stateController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  AwsMqttService({
    required this.awsIotEndpoint,
    this.awsIotPort = 8883,
    this.rootCA,
    this.clientCert,
    this.clientKey,
  });
  
  /// Connect to AWS IoT Core
  /// 
  /// For native platforms: Requires certificates
  /// For web: Use API Gateway instead (WebSocket with SigV4 is complex)
  Future<bool> connect() async {
    try {
      if (kIsWeb) {
        // Web: Use API Gateway WebSocket or HTTP polling
        // AWS IoT Core WebSocket requires SigV4 signing which is complex
        // Consider using API Gateway WebSocket API instead
        print('AwsMqttService: Web platform - consider using API Gateway');
        return false;
      }
      
      // Native platforms: Use certificates
      if (rootCA == null || clientCert == null || clientKey == null) {
        print('AwsMqttService: Certificates required for native platforms');
        return false;
      }
      
      _client = MqttServerClient(awsIotEndpoint, 
        'ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}');
      _client!.port = awsIotPort;
      _client!.secure = true;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      
      // Configure TLS with certificates
      final securityContext = SecurityContext.defaultContext;
      
      // Load certificates
      // Note: In production, load certificates from secure storage, not hardcoded strings
      // For now, assume certificates are in assets or filesystem
      
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _pong;
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier('ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}')
          .withWillTopic('ahu_dashboard/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client!.connectionMessage = connMessage;
      
      await _client!.connect();
      
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('AwsMqttService: Connected to AWS IoT Core');
        _isConnected = true;
        _connectionController.add(true);
        
        // Subscribe to all AHU topics
        _client!.subscribe('almed/ahu/#', MqttQos.atLeastOnce);
        
        // Listen to messages
        _client!.updates!.listen(_onMessage);
        
        return true;
      } else {
        print('AwsMqttService: Connection failed - ${_client!.connectionStatus}');
        _isConnected = false;
        _connectionController.add(false);
        return false;
      }
    } catch (e) {
      print('AwsMqttService: Connection error - $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }
  
  /// Disconnect from AWS IoT Core
  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    _connectionController.add(false);
  }
  
  /// Publish command to device
  void publishCommand(String topic, Map<String, dynamic> command) {
    if (_client == null || !_isConnected) return;
    
    final payload = jsonEncode(command);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }
  
  // Callbacks
  void _onConnected() {
    print('AwsMqttService: Connected');
    _isConnected = true;
    _connectionController.add(true);
  }
  
  void _onDisconnected() {
    print('AwsMqttService: Disconnected');
    _isConnected = false;
    _connectionController.add(false);
  }
  
  void _onSubscribed(String topic) {
    print('AwsMqttService: Subscribed to $topic');
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
        final data = jsonDecode(payloadString) as Map<String, dynamic>;
        
        // Extract device ID from topic
        final parts = topic.split('/');
        if (parts.length < 5) continue;
        
        final deviceId = parts[4];
        final topicData = '$deviceId|${parts[2]}|${parts[3]}';
        
        // Route to appropriate stream
        if (topic.endsWith('/telemetry')) {
          _telemetryController.add(MapEntry(topicData, data));
        } else if (topic.endsWith('/state')) {
          _stateController.add(MapEntry(topicData, data));
        }
      } catch (e) {
        print('AwsMqttService: Error parsing message from $topic: $e');
      }
    }
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _telemetryController.close();
    _stateController.close();
    _connectionController.close();
  }
}

