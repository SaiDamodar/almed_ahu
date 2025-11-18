/// Application configuration
class AppConfig {
  // Base URL for web dashboard API
  // Change this to your web dashboard server URL
  // For Android emulator: 'http://10.0.2.2:5000' (accesses host machine's localhost)
  // For physical device: 'http://YOUR_SERVER_IP:5000' (e.g., 'http://192.168.1.100:5000')
  static const String baseUrl = 'http://192.168.0.52:5000';
  static const String apiBaseUrl = '$baseUrl/api';
  
  // Admin credentials
  static const String adminUsername = 'admin';
  static const String adminPassword = '1234';
  
  // API endpoints
  static const String loginEndpoint = '$apiBaseUrl/login';
  static const String devicesEndpoint = '$apiBaseUrl/devices';
  static String deviceStatusEndpoint(String deviceId) => '$apiBaseUrl/device/$deviceId/status';
  static String deviceTelemetryEndpoint(String deviceId) => '$apiBaseUrl/device/$deviceId/telemetry';
  static String deviceCommandEndpoint(String deviceId) => '$apiBaseUrl/device/$deviceId/command';
  
  // Polling intervals (milliseconds)
  static const int statusPollInterval = 5000; // 5 seconds
  static const int telemetryPollInterval = 10000; // 10 seconds
}

