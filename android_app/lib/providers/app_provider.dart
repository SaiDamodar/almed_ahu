import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/hospital.dart';
import '../models/device_status.dart';
import '../models/ahu_state.dart';
import '../models/user.dart';
import '../models/register_request.dart';
import '../services/api_service.dart';
import '../services/aws_iot_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';

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
  
  // Optimistic UI tracking
  final Map<String, _PendingCommand> _pendingCommands = {};
  static const _commandTimeout = Duration(seconds: 10);
  
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
  
  /// Check if a command is pending for a device
  bool isCommandPending(String deviceId, [String? commandType]) {
    final pending = _pendingCommands[deviceId];
    if (pending == null) return false;
    if (commandType != null && pending.type != commandType) return false;
    // Check if command has timed out
    if (DateTime.now().difference(pending.timestamp) > _commandTimeout) {
      _pendingCommands.remove(deviceId);
      return false;
    }
    return true;
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
          // Regular user - load their assigned AHUs and start polling
          try {
            await _loadUserDeviceStatuses();
            _startUserPolling();
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
        
        // Register FCM token for push notifications
        await _registerFCMToken();
        
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
        
        // Load initial status for assigned AHUs
        await _loadUserDeviceStatuses();
        
        // Start polling for user's AHUs
        _startUserPolling();
        
        // Register FCM token for push notifications
        await _registerFCMToken();
        
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
  
  /// Load device statuses for current user's assigned AHUs
  Future<void> _loadUserDeviceStatuses() async {
    final user = _currentUser;
    if (user == null || user.assignedAhuIds.isEmpty) return;
    
    await Future.wait(
      user.assignedAhuIds.map((id) => loadDeviceStatus(id)),
    );
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
        
        // Load initial status and start polling (if user has assigned AHUs)
        await _loadUserDeviceStatuses();
        _startUserPolling();
        
        // Register FCM token for push notifications
        await _registerFCMToken();
        
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
        
        // Load initial status for assigned AHUs
        await _loadUserDeviceStatuses();
        
        // Start polling for user's AHUs
        _startUserPolling();
        
        // Register FCM token for push notifications
        await _registerFCMToken();
        
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
    
    // Unregister FCM token before logout
    await _apiService.unregisterFCMToken();
    
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
  
  /// Load device status with pending command cross-check
  Future<void> loadDeviceStatus(String deviceId) async {
    try {
      final status = await _apiService.getDeviceStatus(deviceId);
      if (status != null) {
        // Cross-check with pending commands
        final pending = _pendingCommands[deviceId];
        if (pending != null) {
          final elapsed = DateTime.now().difference(pending.timestamp);
          
          // Check if command has timed out
          if (elapsed > _commandTimeout) {
            debugPrint('Command timeout for $deviceId - clearing pending');
            _pendingCommands.remove(deviceId);
            _deviceStatuses[deviceId] = status;
          } else {
            // Validate if cloud state matches expected state
            bool stateMatches = true;
            
            if (pending.type == 'toggle' && pending.expectedRun != null) {
              stateMatches = status.isRunning == pending.expectedRun;
            } else if (pending.type == 'fan' && pending.expectedFanSpeed != null) {
              stateMatches = status.state?.fanSpeed == pending.expectedFanSpeed;
            }
            
            if (stateMatches) {
              // Cloud confirmed our expected state - clear pending
              debugPrint('✓ Cloud confirmed state for $deviceId');
              _pendingCommands.remove(deviceId);
              _deviceStatuses[deviceId] = status;
            } else if (elapsed > const Duration(seconds: 3)) {
              // Give some time for ESP to process, then accept cloud state
              debugPrint('State mismatch for $deviceId after ${elapsed.inSeconds}s - accepting cloud state');
              _pendingCommands.remove(deviceId);
              _deviceStatuses[deviceId] = status;
            }
            // Otherwise keep optimistic state until confirmed or timeout
          }
        } else {
          // No pending command - just update normally
          _deviceStatuses[deviceId] = status;
        }
        
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
  
  /// Toggle AHU system (start/stop) with optimistic UI update
  Future<void> toggleAhu(String deviceId) async {
    final status = _deviceStatuses[deviceId];
    if (status == null || status.state == null) return;
    
    final newRunState = !status.isRunning;
    final command = newRunState ? {'start': true} : {'stop': true};
    
    // Store pending command for cross-checking
    _pendingCommands[deviceId] = _PendingCommand(
      type: 'toggle',
      expectedRun: newRunState,
      timestamp: DateTime.now(),
    );
    
    // Optimistic UI update - immediately show new state
    _deviceStatuses[deviceId] = DeviceStatus(
      deviceId: status.deviceId,
      status: status.status,
      telemetry: status.telemetry,
      state: AhuState(
        run: newRunState,
        tempSet: status.state!.tempSet,
        humSet: status.state!.humSet,
        fan: newRunState ? status.state!.fan : false,
        fanSpeed: newRunState ? status.state!.fanSpeed : 0,
        cp: newRunState ? status.state!.cp : false,
        heater: newRunState ? status.state!.heater : false,
        m1: newRunState ? status.state!.m1 : false,
        m2: newRunState ? status.state!.m2 : false,
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
    
    // Send command to cloud (don't await - fire and forget for faster UI)
    sendCommand(deviceId, command).then((success) {
      if (!success) {
        // Revert on failure
        _revertOptimisticUpdate(deviceId, status);
      }
    });
  }
  
  /// Revert optimistic update on command failure
  void _revertOptimisticUpdate(String deviceId, DeviceStatus originalStatus) {
    _pendingCommands.remove(deviceId);
    _deviceStatuses[deviceId] = originalStatus;
    notifyListeners();
    debugPrint('Reverted optimistic update for $deviceId');
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
  
  /// Set fan speed (0=OFF, 1=LOW, 2=MED, 3=HIGH) with optimistic UI update
  Future<void> setFanSpeed(String deviceId, int speed) async {
    if (speed < 0 || speed > 3) return;
    
    final status = _deviceStatuses[deviceId];
    if (status?.state == null) return;
    
    // Store pending command
    _pendingCommands[deviceId] = _PendingCommand(
      type: 'fan',
      expectedFanSpeed: speed,
      timestamp: DateTime.now(),
    );
    
    // Optimistic UI update
    _deviceStatuses[deviceId] = DeviceStatus(
      deviceId: status!.deviceId,
      status: status.status,
      telemetry: status.telemetry,
      state: AhuState(
        run: status.state!.run,
        tempSet: status.state!.tempSet,
        humSet: status.state!.humSet,
        fan: speed > 0,
        fanSpeed: speed,
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
    
    // Send command (fire and forget)
    sendCommand(deviceId, {'fan': speed}).then((success) {
      if (!success) {
        _revertOptimisticUpdate(deviceId, status);
      }
    });
  }
  
  /// Start polling for device status updates (admin - polls all hospitals)
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

  /// Start polling for user's assigned AHUs
  void _startUserPolling() {
    _stopPolling();
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 2), // Faster polling for better UX
      (timer) {
        final user = _currentUser;
        if (user != null) {
          for (final ahuId in user.assignedAhuIds) {
            loadDeviceStatus(ahuId);
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

  // ============================================================================
  // Support Tickets
  // ============================================================================

  /// Create a new support ticket
  Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
    String? ahuId,
    String priority = 'medium',
  }) async {
    try {
      return await _apiService.createTicket(
        title: title,
        description: description,
        ahuId: ahuId,
        priority: priority,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create ticket: ${e.toString()}',
      };
    }
  }

  /// Get tickets for the current user
  Future<List<Map<String, dynamic>>> getMyTickets() async {
    try {
      return await _apiService.getMyTickets();
    } catch (e) {
      _setError('Failed to get tickets: ${e.toString()}');
      return [];
    }
  }

  /// Register FCM token with backend for push notifications
  Future<void> _registerFCMToken() async {
    try {
      final notificationService = NotificationService();
      
      // Try to get token - first from memory, then from storage
      String? token = notificationService.fcmToken;
      
      if (token == null) {
        token = await notificationService.getStoredFCMToken();
      }
      
      // If still null, try to get fresh token from Firebase
      if (token == null) {
        debugPrint('FCM token not available, requesting fresh token...');
        token = await FirebaseMessaging.instance.getToken();
        debugPrint('Fresh FCM token obtained: ${token != null ? "yes" : "no"}');
      }
      
      if (token != null && token.isNotEmpty) {
        debugPrint('Registering FCM token with backend...');
        final success = await _apiService.registerFCMToken(token);
        if (success) {
          debugPrint('✓ FCM token registered successfully');
        } else {
          debugPrint('✗ Failed to register FCM token with backend');
        }
      } else {
        debugPrint('✗ No FCM token available to register');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
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

/// Helper class to track pending commands for optimistic UI
class _PendingCommand {
  final String type; // 'toggle', 'fan', 'temp', 'hum'
  final bool? expectedRun;
  final int? expectedFanSpeed;
  final double? expectedTemp;
  final double? expectedHum;
  final DateTime timestamp;

  _PendingCommand({
    required this.type,
    this.expectedRun,
    this.expectedFanSpeed,
    this.expectedTemp,
    this.expectedHum,
    required this.timestamp,
  });
}
