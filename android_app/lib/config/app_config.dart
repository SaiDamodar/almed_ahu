/// Application configuration
class AppConfig {
  // Base URL for web dashboard API
  // 
  // Option 1: Railway subdomain (may have DNS issues on mobile data)
  // static const String baseUrl = 'https://almedahuwebapp-production.up.railway.app';
  //
  // Option 2: Custom domain (RECOMMENDED - fixes DNS issues)
  // Using subdomain for faster DNS propagation
  // Root domain (almedequipments.in) can take 24-48 hours to propagate on mobile carriers
  // Subdomain (api.almedequipments.in) propagates faster (15-30 minutes)
  // 
  // If root domain doesn't work on mobile data, use subdomain:
  static const String baseUrl = 'https://api.almedequipments.in';
  // Or root domain (if DNS fully propagated):
  // static const String baseUrl = 'https://almedequipments.in';
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

