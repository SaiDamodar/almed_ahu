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
  bool _useDirectAws = false;
  bool _isAdmin = false;
  User? _currentUser;
  bool _isInitialized = false;
  
  // Data
  Map<String, Hospital> _hospitals = {};
  Map<String, DeviceStatus> _deviceStatuses = {};
  Timer? _statusPollTimer;
  Timer? _notifyDebounceTimer;
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, Hospital> get hospitals => _hospitals;
  List<Hospital> get hospitalsList => _hospitals.values.toList();
  bool get isAdmin => _isAdmin;
  User? get currentUser => _currentUser;
  bool get useDirectAws => _useDirectAws;
  bool get awsConnected => _awsIoTService.isConnected;
  bool get isInitialized => _isInitialized;
  
  DeviceStatus? getDeviceStatus(String deviceId) {
    if (_useDirectAws && _awsIoTService.isConnected) {
      return _awsIoTService.getDeviceStatus(deviceId) ?? _deviceStatuses[deviceId];
    }
    return _deviceStatuses[deviceId];
  }
  
  /// Debounced notify to prevent excessive rebuilds
  void _debouncedNotify() {
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
  }
  
  /// Initialize authentication state from persistent storage
  Future<void> initializeAuth() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('is_authenticated') ?? false;
      final isAdmin = prefs.getBool('is_admin') ?? false;
      
      if (isAuth) {
        final sessionRestored = await _apiService.restoreSession();
        
        if (!sessionRestored) {
          await _clearAuthState();
          _isAuthenticated = false;
          _isAdmin = false;
          _currentUser = null;
          _isInitialized = true;
          notifyListeners();
          return;
        }
        
        _isAuthenticated = true;
        _isAdmin = isAdmin;
        
        if (!isAdmin) {
          try {
            await checkUserStatus();
            if (_currentUser == null) {
              await _clearAuthState();
              _isAuthenticated = false;
              _isAdmin = false;
              _isInitialized = true;
              notifyListeners();
              return;
            }
          } catch (e) {
            debugPrint('Error restoring user data: $e');
            await _clearAuthState();
            _isAuthenticated = false;
            _isAdmin = false;
            _currentUser = null;
            _isInitialized = true;
            notifyListeners();
            return;
          }
        }
        
        if (isAdmin) {
          try {
            await connectToAwsIoT();
            await loadHospitals();
            _startPolling();
          } catch (e) {
            debugPrint('Error loading admin data: $e');
          }
        } else {
          try {
            await loadHospitals();
          } catch (e) {
            debugPrint('Error loading hospital user data: $e');
          }
        }
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      await _clearAuthState();
      _isAuthenticated = false;
      _isAdmin = false;
      _currentUser = null;
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
        await prefs.setString('current_user', _currentUser!.email);
      }
    } catch (e) {
      debugPrint('Error saving auth state: $e');
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
      debugPrint('Error clearing auth state: $e');
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
        _currentUser = null;
        
        await _saveAuthState();
        await connectToAwsIoT();
        await loadHospitals();
        _startPolling();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        final apiError = _apiService.errorMessage ?? '';
        if (apiError.contains('SocketException') || 
            apiError.contains('Failed host lookup') ||
            apiError.contains('No address associated with hostname')) {
          _setError('Network error: Cannot connect. Try using WiFi or check DNS settings.');
        } else {
          _setError('Invalid username or password');
        }
        _setLoading(false);
        return false;
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup')) {
        _setError('Network error: Cannot connect. Try using WiFi.');
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
    if (_isAdmin) return;
    
    try {
      final user = await _apiService.checkUserStatus();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking user status: $e');
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

    if (email.isEmpty || !email.contains('@')) {
      _setError('Valid email is required');
      _setLoading(false);
      return false;
    }

    try {
      final registerRequest = RegisterRequest(
        email: email.trim(),
        username: username,
        phoneNumber: phoneNumber,
        hospitalName: hospitalName,
        password: '',
        googleId: googleId,
        profileImageUrl: profileImageUrl,
      );

      final user = await _apiService.registerWithGoogle(
        registerRequest: registerRequest,
        idToken: idToken,
      );

      if (user != null) {
        _isAuthenticated = true;
        _isAdmin = false;
        _currentUser = user;
        
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
      _awsIoTService.onDeviceUpdate = (deviceId, status) {
        _deviceStatuses[deviceId] = status;
        _debouncedNotify();
      };
      
      _awsIoTService.onConnectionChanged = (connected) {
        _useDirectAws = connected;
        notifyListeners();
      };
      
      final connected = await _awsIoTService.connect();
      if (connected) {
        _useDirectAws = true;
        debugPrint('Connected to AWS IoT Core directly');
      } else {
        debugPrint('Failed to connect to AWS IoT Core, using Flask API');
        _useDirectAws = false;
      }
    } catch (e) {
      debugPrint('AWS IoT connection error: $e');
      _useDirectAws = false;
    }
  }
  
  /// Logout
  Future<void> logout() async {
    _stopPolling();
    _awsIoTService.disconnect();
    _apiService.logout();
    await _firebaseAuth.signOut();
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
      
      // Load status for all devices in parallel
      final futures = <Future>[];
      for (final hospital in hospitals.values) {
        for (final ahu in hospital.allAhus) {
          futures.add(loadDeviceStatus(ahu.id));
        }
      }
      await Future.wait(futures);
      
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
        // Use debounced notify to batch updates
        _debouncedNotify();
      }
    } catch (e) {
      debugPrint('Error loading device status: $e');
    }
  }
  
  /// Send command to device
  Future<bool> sendCommand(String deviceId, Map<String, dynamic> command) async {
    try {
      if (_useDirectAws && _awsIoTService.isConnected) {
        final success = await _awsIoTService.publishCommand(deviceId, command);
        if (success) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return success;
      } else {
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
    
    final command = status.isRunning
        ? {'stop': true}
        : {'start': true};
    
    await sendCommand(deviceId, command);
  }
  
  /// Set temperature setpoint with optimistic update
  Future<void> setTemperature(String deviceId, double temp) async {
    final status = _deviceStatuses[deviceId];
    if (status?.state != null) {
      _deviceStatuses[deviceId] = DeviceStatus(
        deviceId: status!.deviceId,
        status: status.status,
        telemetry: status.telemetry,
        state: AhuState(
          run: status.state!.run,
          tempSet: temp,
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
      notifyListeners();
    }
    
    sendCommand(deviceId, {'setpoint': temp});
  }
  
  /// Set humidity setpoint with optimistic update
  Future<void> setHumidity(String deviceId, double hum) async {
    final status = _deviceStatuses[deviceId];
    if (status?.state != null) {
      _deviceStatuses[deviceId] = DeviceStatus(
        deviceId: status!.deviceId,
        status: status.status,
        telemetry: status.telemetry,
        state: AhuState(
          run: status.state!.run,
          tempSet: status.state!.tempSet,
          humSet: hum,
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
      notifyListeners();
    }
    
    sendCommand(deviceId, {'humset': hum});
  }
  
  /// Set fan speed (0=OFF, 1=LOW, 2=MED, 3=HIGH)
  Future<void> setFanSpeed(String deviceId, int speed) async {
    if (speed < 0 || speed > 3) return;
    await sendCommand(deviceId, {'fan': speed});
  }
  
  /// Start polling for device status updates
  void _startPolling() {
    _stopPolling();
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
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
    final futures = <Future>[];
    for (final hospital in _hospitals.values) {
      for (final ahu in hospital.allAhus) {
        futures.add(loadDeviceStatus(ahu.id));
      }
    }
    await Future.wait(futures);
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
    _notifyDebounceTimer?.cancel();
    _awsIoTService.disconnect();
    super.dispose();
  }
}
