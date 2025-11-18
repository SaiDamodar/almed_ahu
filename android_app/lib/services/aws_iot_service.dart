import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/aws_config.dart';
import '../models/device_status.dart';
import '../models/ahu_state.dart';
import '../models/ahu_telemetry.dart';

/// Service for direct AWS IoT Core MQTT connection
class AwsIoTService {
  MqttServerClient? _client;
  bool _isConnected = false;
  final Map<String, DeviceStatus> _deviceStatuses = {};
  
  // Callbacks
  Function(String deviceId, DeviceStatus status)? onDeviceUpdate;
  Function(bool connected)? onConnectionChanged;
  
  bool get isConnected => _isConnected;
  Map<String, DeviceStatus> get deviceStatuses => Map.unmodifiable(_deviceStatuses);
  
  /// Generate SigV4 signed WebSocket URL for AWS IoT Core
  String _generateSignedUrl() {
    final now = DateTime.now().toUtc();
    final amzDate = now.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0] + 'Z';
    final dateStamp = amzDate.substring(0, 8);
    
    // Create canonical request
    final canonicalUri = '/mqtt';
    final canonicalQueryString = 
        'X-Amz-Algorithm=AWS4-HMAC-SHA256&'
        'X-Amz-Credential=${Uri.encodeComponent('${AwsConfig.accessKeyId}/$dateStamp/${AwsConfig.region}/${AwsConfig.service}/aws4_request')}&'
        'X-Amz-Date=$amzDate&'
        'X-Amz-SignedHeaders=host';
    
    final canonicalHeaders = 'host:${AwsConfig.iotEndpoint}\n';
    final signedHeaders = 'host';
    final payloadHash = sha256.convert(utf8.encode('')).toString();
    
    final canonicalRequest = 
        'GET\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
    
    // Create string to sign
    const algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/${AwsConfig.region}/${AwsConfig.service}/aws4_request';
    final stringToSign = 
        '$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}';
    
    // Calculate signature
    Uint8List sign(Uint8List key, String msg) {
      return Uint8List.fromList(Hmac(sha256, key).convert(utf8.encode(msg)).bytes);
    }
    
    final kDate = sign(utf8.encode('AWS4${AwsConfig.secretAccessKey}'), dateStamp);
    final kRegion = sign(kDate, AwsConfig.region);
    final kService = sign(kRegion, AwsConfig.service);
    final kSigning = sign(kService, 'aws4_request');
    final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();
    
    // Add signature to query string
    final finalQueryString = '$canonicalQueryString&X-Amz-Signature=$signature';
    
    return 'wss://${AwsConfig.iotEndpoint}$canonicalUri?$finalQueryString';
  }
  
  /// Connect to AWS IoT Core via MQTT
  Future<bool> connect() async {
    try {
      if (_isConnected) {
        return true;
      }
      
      // Generate signed WebSocket URL
      final wsUrl = _generateSignedUrl();
      
      // Parse WebSocket URL
      final uri = Uri.parse(wsUrl);
      final host = uri.host;
      final port = uri.port == 0 ? 443 : uri.port;
      
      // Create MQTT client with WebSocket
      final clientId = 'almed_android_${DateTime.now().millisecondsSinceEpoch}';
      _client = MqttServerClient.withPort(host, clientId, port);
      _client!.logging(on: true);
      _client!.keepAlivePeriod = 20;
      _client!.autoReconnect = true;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;
      
      // Set up message handler
      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c != null && c.isNotEmpty) {
          final recMess = c[0].payload as MqttPublishMessage;
          final topic = c[0].topic;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          _handleMessage(topic, payload);
        }
      });
      
      // Configure WebSocket
      _client!.useWebSocket = true;
      _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
      
      // Note: mqtt_client package has limitations with AWS IoT Core's custom WebSocket authentication
      // AWS IoT Core requires SigV4 signed query parameters in the WebSocket URL path
      // The mqtt_client package doesn't support custom WebSocket paths with query parameters
      // 
      // For now, we'll attempt connection but it may fail. The app will fall back to Flask API.
      // For full AWS IoT Core support, consider:
      // 1. Using AWS Amplify for Flutter (recommended)
      // 2. Using X.509 certificates instead of WebSocket
      // 3. Using a custom WebSocket implementation
      
      print('AWS IoT: Connecting to $host:$port via WebSocket...');
      print('AWS IoT: WARNING - Direct AWS IoT connection may not work due to WebSocket path limitations');
      print('AWS IoT: App will fall back to Flask API if connection fails');
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      _client!.connectionMessage = connMessage;
      
      await _client!.connect();
      
      // Wait a bit for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
      
      return _isConnected;
    } catch (e) {
      print('AWS IoT connection error: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
      return false;
    }
  }
  
  /// Disconnect from AWS IoT Core
  void disconnect() {
    _client?.disconnect();
    _client = null;
    _isConnected = false;
    _deviceStatuses.clear();
    onConnectionChanged?.call(false);
  }
  
  /// Subscribe to telemetry topic
  Future<void> subscribe() async {
    if (!_isConnected || _client == null) {
      print('AWS IoT: Not connected, cannot subscribe');
      return;
    }
    
    try {
      _client!.subscribe(AwsConfig.topicPublish, MqttQos.atLeastOnce);
      print('AWS IoT: Subscribed to ${AwsConfig.topicPublish}');
    } catch (e) {
      print('AWS IoT: Subscribe error: $e');
    }
  }
  
  /// Publish command to ESP32
  Future<bool> publishCommand(String deviceId, Map<String, dynamic> command) async {
    if (!_isConnected || _client == null) {
      print('AWS IoT: Not connected, cannot publish');
      return false;
    }
    
    try {
      // ESP32 expects the command directly, without wrapping
      // The command already has the correct format (start/stop, setpoint, humset, fan)
      // Just send it as-is to esp32/sub topic
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(command));
      
      _client!.publishMessage(
        AwsConfig.topicSubscribe,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
      
      print('AWS IoT: Published command to ${AwsConfig.topicSubscribe}: ${jsonEncode(command)}');
      return true;
    } catch (e) {
      print('AWS IoT: Publish error: $e');
      return false;
    }
  }
  
  /// Handle incoming MQTT messages
  void _handleMessage(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // Extract device ID
      final deviceId = data['thing'] as String? ?? 
                      data['device_id'] as String? ?? 
                      data['deviceId'] as String? ?? 
                      'unknown';
      
      // Determine message type
      final msgType = data['type'] as String? ?? 'telemetry';
      
      // Parse telemetry or state
      if (msgType == 'telemetry' || msgType == 'state') {
        final telemetry = msgType == 'telemetry' 
            ? AhuTelemetry.fromJson(data)
            : null;
        final state = msgType == 'state'
            ? AhuState.fromJson(data)
            : null;
        
        // Update device status
        final existingStatus = _deviceStatuses[deviceId];
        final status = DeviceStatus(
          deviceId: deviceId,
          status: 'online',
          telemetry: telemetry ?? existingStatus?.telemetry,
          state: state ?? existingStatus?.state,
          lastUpdate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        
        _deviceStatuses[deviceId] = status;
        onDeviceUpdate?.call(deviceId, status);
      }
    } catch (e) {
      print('AWS IoT: Error handling message: $e');
    }
  }
  
  /// Connection callbacks
  void _onConnected() {
    _isConnected = true;
    print('AWS IoT: Connected successfully');
    onConnectionChanged?.call(true);
    // Subscribe after connection is established
    Future.delayed(const Duration(milliseconds: 300), () {
      subscribe();
    });
  }
  
  void _onDisconnected() {
    if (_isConnected) {
      _isConnected = false;
      print('AWS IoT: Disconnected');
      onConnectionChanged?.call(false);
    }
  }
  
  void _onSubscribed(String topic) {
    print('AWS IoT: Successfully subscribed to $topic');
  }
  
  /// Get device status
  DeviceStatus? getDeviceStatus(String deviceId) {
    return _deviceStatuses[deviceId];
  }
}

