/// AWS IoT Core Configuration
class AwsConfig {
  // AWS Region
  static const String region = 'ap-south-1';
  
  // AWS IoT Core Endpoint
  static const String iotEndpoint = 'al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com';
  
  // AWS Credentials (WARNING: In production, use secure storage or AWS Cognito)
  // For now, using same credentials as web dashboard
  // TODO: Move to secure storage or use AWS Cognito for authentication
  static const String accessKeyId = 'AKIAXJ5YBP2HHKNQ334T';
  static const String secretAccessKey = '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';
  
  // MQTT Topics
  static const String topicPublish = 'esp32/pub';  // ESP32 publishes telemetry here
  static const String topicSubscribe = 'esp32/sub'; // ESP32 subscribes to commands here
  
  // WebSocket URL for MQTT
  static String get webSocketUrl => 'wss://$iotEndpoint/mqtt';
  
  // Service name for SigV4
  static const String service = 'iotdevicegateway';
}

