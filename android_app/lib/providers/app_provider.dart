import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hospital.dart';
import '../models/device_status.dart';
import '../models/ahu_state.dart';
import '../models/user.dart';
import '../models/register_request.dart';
import '../services/api_service.dart';
import '../services/aws_iot_service.dart';
import '../services/firebase_auth_service.dart';

/// Main app state provider
class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AwsIoTService _awsIoTService = AwsIoTService();
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _useDirectAws = false; // Toggle between Flask API and direct AWS IoT
  bool _isAdmin = false; // Track if user is admin or hospital user
  User? _currentUser; // Current logged-in hospital user
  bool _isInitialized = false; // Track if auth state has been loaded
  
  // Data
  Map<String, Hospital> _hospitals = {};
  Map<String, DeviceStatus> _deviceStatuses = {};
  Timer? _statusPollTimer;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, Hospital> get hospitals => _hospitals;
  List<Hospital> get hospitalsList => _hospitals.values.toList();
  bool get isAdmin => _isAdmin;
  User? get currentUser => _currentUser;
  
  DeviceStatus? getDeviceStatus(String deviceId) {
    // Try AWS IoT first if connected, otherwise fall back to API cache
    if (_useDirectAws && _awsIoTService.isConnected) {
      return _awsIoTService.getDeviceStatus(deviceId) ?? _deviceStatuses[deviceId];
    }
    return _deviceStatuses[deviceId];
  }
  
  bool get useDirectAws => _useDirectAws;
  bool get awsConnected => _awsIoTService.isConnected;
  bool get isInitialized => _isInitialized;
  
  /// Initialize authentication state from persistent storage
  Future<void> initializeAuth() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('is_authenticated') ?? false;
      final isAdmin = prefs.getBool('is_admin') ?? false;
      
      if (isAuth) {
        _isAuthenticated = true;
        _isAdmin = isAdmin;
        
        // If hospital user, try to restore user data
        if (!isAdmin) {
          final userJson = prefs.getString('current_user');
          if (userJson != null) {
            try {
              // You might need to import json_serializable or use a different method
              // For now, we'll just mark as authenticated and reload user status
              await checkUserStatus();
            } catch (e) {
              print('Error restoring user data: $e');
            }
          }
        } else {
          // Admin - restore session
          await _apiService.restoreSession();
        }
        
        // Connect to AWS IoT if admin
        if (isAdmin) {
          await connectToAwsIoT();
          await loadHospitals();
          _startPolling();
        } else {
          // Hospital user - load their assigned AHUs
          await loadHospitals();
        }
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing auth: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// Save authentication state to persistent storage
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', _isAuthenticated);
      await prefs.setBool('is_admin', _isAdmin);
      
      if (_currentUser != null) {
        // Save user data as JSON string (simplified - you might want to use proper serialization)
        await prefs.setString('current_user', _currentUser!.email);
      }
    } catch (e) {
      print('Error saving auth state: $e');
    }
  }
  
  /// Clear authentication state from persistent storage
  Future<void> _clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_authenticated');
      await prefs.remove('is_admin');
      await prefs.remove('current_user');
    } catch (e) {
      print('Error clearing auth state: $e');
    }
  }
  
  /// Admin Login
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final success = await _apiService.login(username, password);
      if (success) {
        _isAuthenticated = true;
        _isAdmin = true;
        _currentUser = null; // Admin doesn't have user object
        
        // Save auth state
        await _saveAuthState();
        
        // Connect to AWS IoT Core directly
        await connectToAwsIoT();
        
        await loadHospitals();
        _startPolling();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        // Check if it's a network/DNS error
        final apiError = _apiService.errorMessage ?? '';
        if (apiError.contains('SocketException') || 
            apiError.contains('Failed host lookup') ||
            apiError.contains('No address associated with hostname')) {
          _setError('Network error: Cannot resolve Railway domain. Your mobile carrier may be blocking DNS. Try using WiFi or change DNS to Google (8.8.8.8). See DNS_ISSUE_SOLUTION.md for details.');
        } else {
          _setError('Invalid username or password');
        }
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Check if it's a network/DNS error
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('No address associated with hostname')) {
        _setError('Network error: Cannot resolve Railway domain. Your mobile carrier may be blocking it. Try using WiFi or change DNS settings (see DNS_ISSUE_SOLUTION.md).');
      } else {
        _setError('Login failed: ${e.toString()}');
      }
      _setLoading(false);
      return false;
    }
  }

  /// Hospital User Registration
  Future<bool> register(RegisterRequest request) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final user = await _apiService.register(request);
      if (user != null) {
        _isAuthenticated = true;
        _isAdmin = false;
        _currentUser = user;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(_apiService.errorMessage ?? 'Registration failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Registration failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Hospital User Login
  Future<bool> userLogin(String email, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final user = await _apiService.userLogin(email, password);
      if (user != null) {
        _isAuthenticated = true;
        _isAdmin = false;
        _currentUser = user;
        
        // Save auth state
        await _saveAuthState();
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(_apiService.errorMessage ?? 'Login failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Check if Google user exists in system
  Future<User?> checkGoogleUser(String email) async {
    return await _apiService.checkGoogleUser(email);
  }
  
  /// Check current user status (for hospital users)
  Future<void> checkUserStatus() async {
    if (_isAdmin) return; // Admin doesn't need status check
    
    try {
      final user = await _apiService.checkUserStatus();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  /// Sign in with Google
  Future<GoogleSignInResult> signInWithGoogle() async {
    return await _firebaseAuth.signInWithGoogle();
  }


  /// Register with Google (after collecting additional info)
  Future<bool> registerWithGoogle({
    required String googleId,
    required String email,
    required String username,
    required String phoneNumber,
    required String hospitalName,
    String? profileImageUrl,
    required String idToken,
  }) async {
    _setLoading(true);
    _setError(null);

    // Validate email before proceeding
    if (email.isEmpty || !email.contains('@')) {
      _setError('Valid email is required');
      _setLoading(false);
      return false;
    }

    try {
      print('AppProvider: registerWithGoogle - Email: $email, GoogleId: $googleId');
      
      final registerRequest = RegisterRequest(
        email: email.trim(),
        username: username,
        phoneNumber: phoneNumber,
        hospitalName: hospitalName,
        password: '', // No password for Google users
        googleId: googleId,
        profileImageUrl: profileImageUrl,
      );
      
      print('AppProvider: RegisterRequest created - Email: ${registerRequest.email}');

      final user = await _apiService.registerWithGoogle(
        registerRequest: registerRequest,
        idToken: idToken,
      );

      if (user != null) {
        _isAuthenticated = true;
        _isAdmin = false;
        _currentUser = user;
        
        // Save auth state
        await _saveAuthState();
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(_apiService.errorMessage ?? 'Registration failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Registration failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Login with Google (existing user)
  Future<bool> userLoginWithGoogle(
    String googleId,
    String email,
    String displayName,
    String? photoUrl,
    String idToken,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final user = await _apiService.userLoginWithGoogle(
        googleId: googleId,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        idToken: idToken,
      );

      if (user != null) {
        _isAuthenticated = true;
        _isAdmin = false;
        _currentUser = user;
        
        // Save auth state
        await _saveAuthState();
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(_apiService.errorMessage ?? 'Login failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }
  
  /// Connect to AWS IoT Core directly
  Future<void> connectToAwsIoT() async {
    try {
      // Set up callbacks
      _awsIoTService.onDeviceUpdate = (deviceId, status) {
        _deviceStatuses[deviceId] = status;
        notifyListeners();
      };
      
      _awsIoTService.onConnectionChanged = (connected) {
        _useDirectAws = connected;
        notifyListeners();
      };
      
      // Connect
      final connected = await _awsIoTService.connect();
      if (connected) {
        _useDirectAws = true;
        print('Connected to AWS IoT Core directly');
      } else {
        print('Failed to connect to AWS IoT Core, using Flask API');
        _useDirectAws = false;
      }
    } catch (e) {
      print('AWS IoT connection error: $e');
      _useDirectAws = false;
    }
  }
  
  /// Logout
  void logout() async {
    _stopPolling();
    _awsIoTService.disconnect();
    _apiService.logout();
    await _firebaseAuth.signOut(); // Sign out from Firebase
    
    // Clear persistent auth state
    await _clearAuthState();
    
    _isAuthenticated = false;
    _isAdmin = false;
    _useDirectAws = false;
    _currentUser = null;
    _hospitals.clear();
    _deviceStatuses.clear();
    _setError(null);
    notifyListeners();
  }
  
  /// Load hospitals and devices
  Future<void> loadHospitals() async {
    try {
      final hospitals = await _apiService.getDevices();
      _hospitals = hospitals;
      
      // Load status for all devices
      for (final hospital in hospitals.values) {
        for (final ahu in hospital.allAhus) {
          await loadDeviceStatus(ahu.id);
        }
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load devices: ${e.toString()}');
    }
  }
  
  /// Load device status
  Future<void> loadDeviceStatus(String deviceId) async {
    try {
      final status = await _apiService.getDeviceStatus(deviceId);
      if (status != null) {
        _deviceStatuses[deviceId] = status;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading device status: $e');
    }
  }
  
  /// Send command to device
  Future<bool> sendCommand(String deviceId, Map<String, dynamic> command) async {
    try {
      // Try AWS IoT first if connected, otherwise use Flask API
      if (_useDirectAws && _awsIoTService.isConnected) {
        final success = await _awsIoTService.publishCommand(deviceId, command);
        if (success) {
          // Wait a bit for status update
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return success;
      } else {
        // Fall back to Flask API
        final success = await _apiService.sendCommand(deviceId, command);
        if (success) {
          await loadDeviceStatus(deviceId);
        }
        return success;
      }
    } catch (e) {
      _setError('Failed to send command: ${e.toString()}');
      return false;
    }
  }
  
  /// Toggle AHU system (start/stop)
  Future<void> toggleAhu(String deviceId) async {
    final status = _deviceStatuses[deviceId];
    if (status == null) return;
    
    // ESP32 expects "start": true or "stop": true, not "run"
    final command = status.isRunning
        ? {'stop': true}
        : {'start': true};
    
    await sendCommand(deviceId, command);
  }
  
  /// Set temperature setpoint
  Future<void> setTemperature(String deviceId, double temp) async {
    // Optimistic update: Update UI immediately
    final status = _deviceStatuses[deviceId];
    if (status != null && status.state != null) {
      // Create updated status with new setpoint
      final updatedStatus = DeviceStatus(
        deviceId: status.deviceId,
        status: status.status,
        telemetry: status.telemetry,
        state: AhuState(
          run: status.state!.run,
          tempSet: temp, // Update setpoint immediately
          humSet: status.state!.humSet,
          fan: status.state!.fan,
          fanSpeed: status.state!.fanSpeed,
          cp: status.state!.cp,
          heater: status.state!.heater,
          m1: status.state!.m1,
          m2: status.state!.m2,
          ip: status.state!.ip,
          m1Start: status.state!.m1Start,
          m1Post: status.state!.m1Post,
          m2Interval: status.state!.m2Interval,
          m2Run: status.state!.m2Run,
          m2Delay: status.state!.m2Delay,
        ),
        lastUpdate: status.lastUpdate,
      );
      _deviceStatuses[deviceId] = updatedStatus;
      notifyListeners(); // Update UI instantly
    }
    
    // Send command in background
    // ESP32 expects "setpoint" not "tempSet"
    final command = {
      'setpoint': temp,
    };
    
    sendCommand(deviceId, command); // Don't await - send in background
  }
  
  /// Set humidity setpoint
  Future<void> setHumidity(String deviceId, double hum) async {
    // Optimistic update: Update UI immediately
    final status = _deviceStatuses[deviceId];
    if (status != null && status.state != null) {
      // Create updated status with new setpoint
      final updatedStatus = DeviceStatus(
        deviceId: status.deviceId,
        status: status.status,
        telemetry: status.telemetry,
        state: AhuState(
          run: status.state!.run,
          tempSet: status.state!.tempSet,
          humSet: hum, // Update humidity setpoint immediately
          fan: status.state!.fan,
          fanSpeed: status.state!.fanSpeed,
          cp: status.state!.cp,
          heater: status.state!.heater,
          m1: status.state!.m1,
          m2: status.state!.m2,
          ip: status.state!.ip,
          m1Start: status.state!.m1Start,
          m1Post: status.state!.m1Post,
          m2Interval: status.state!.m2Interval,
          m2Run: status.state!.m2Run,
          m2Delay: status.state!.m2Delay,
        ),
        lastUpdate: status.lastUpdate,
      );
      _deviceStatuses[deviceId] = updatedStatus;
      notifyListeners(); // Update UI instantly
    }
    
    // Send command in background
    // ESP32 expects "humset" (lowercase) not "humSet"
    final command = {
      'humset': hum,
    };
    
    sendCommand(deviceId, command); // Don't await - send in background
  }
  
  /// Set fan speed (0=OFF, 1=LOW, 2=MED, 3=HIGH)
  Future<void> setFanSpeed(String deviceId, int speed) async {
    if (speed < 0 || speed > 3) return;
    
    // ESP32 expects "fan" not "fanSpeed"
    final command = {
      'fan': speed,
    };
    
    await sendCommand(deviceId, command);
  }
  
  /// Start polling for device status updates
  void _startPolling() {
    _stopPolling();
    // Poll every 3 seconds for faster updates
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        // Poll all devices
        for (final hospital in _hospitals.values) {
          for (final ahu in hospital.allAhus) {
            loadDeviceStatus(ahu.id);
          }
        }
      },
    );
  }
  
  /// Force refresh all device statuses
  Future<void> refreshAllDevices() async {
    for (final hospital in _hospitals.values) {
      for (final ahu in hospital.allAhus) {
        await loadDeviceStatus(ahu.id);
      }
    }
    notifyListeners();
  }
  
  /// Stop polling
  void _stopPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Get pending users (admin only)
  Future<List<User>> getPendingUsers() async {
    try {
      return await _apiService.getPendingUsers();
    } catch (e) {
      _setError('Failed to load pending users: ${e.toString()}');
      return [];
    }
  }

  /// Get registered users (admin only)
  Future<List<User>> getRegisteredUsers() async {
    try {
      return await _apiService.getRegisteredUsers();
    } catch (e) {
      _setError('Failed to load registered users: ${e.toString()}');
      return [];
    }
  }

  /// Approve user (admin only)
  Future<bool> approveUser(String userId) async {
    try {
      return await _apiService.approveUser(userId);
    } catch (e) {
      _setError('Failed to approve user: ${e.toString()}');
      return false;
    }
  }

  /// Reject user (admin only)
  Future<bool> rejectUser(String userId) async {
    try {
      return await _apiService.rejectUser(userId);
    } catch (e) {
      _setError('Failed to reject user: ${e.toString()}');
      return false;
    }
  }

  /// Assign AHUs to user (admin only)
  Future<bool> assignAhusToUser(String userId, List<String> ahuIds) async {
    try {
      return await _apiService.assignAhusToUser(userId, ahuIds);
    } catch (e) {
      _setError('Failed to assign AHUs: ${e.toString()}');
      return false;
    }
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    _awsIoTService.disconnect();
    super.dispose();
  }
}

