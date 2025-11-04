import 'package:amazon_cognito_identity_dart_2/cognito_user_pool.dart';
import 'package:amazon_cognito_identity_dart_2/cognito_user.dart';
import 'package:amazon_cognito_identity_dart_2/amazon_cognito_identity_dart_2.dart';

/// AWS Cognito Service (Replaces Firebase Auth)
/// 
/// Setup:
/// 1. Add to pubspec.yaml:
///    dependencies:
///      amazon_cognito_identity_dart_2: ^2.0.0
/// 
/// 2. Get User Pool ID and Client ID from AWS Console:
///    AWS Console → Cognito → User Pools → Your Pool → App clients
class CognitoService {
  late CognitoUserPool _userPool;
  CognitoUser? _currentUser;
  
  // Configuration - Replace with your values from AWS Console
  static const String userPoolId = 'ap-south-1_LSTShtM9R'; // Your User Pool ID
  static const String clientId = '5iegqp1lv7umgmk609b03kjqhp'; // Your Client ID
  static const String region = 'ap-south-1';
  
  CognitoService() {
    _userPool = CognitoUserPool(
      userPoolId,
      clientId,
    );
  }
  
  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null;
  
  /// Get current user
  CognitoUser? get currentUser => _currentUser;
  
  /// Sign in with email and password
  Future<CognitoUserSession?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _currentUser = CognitoUser(email, _userPool);
      
      final authDetails = AuthenticationDetails(
        username: email,
        password: password,
      );
      
      final session = await _currentUser!.authenticateUser(authDetails);
      
      if (session != null) {
        print('CognitoService: Signed in successfully');
        return session;
      } else {
        print('CognitoService: Sign in failed - no session');
        return null;
      }
    } catch (e) {
      print('CognitoService: Sign in error - $e');
      return null;
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    try {
      if (_currentUser != null) {
        await _currentUser!.signOut();
        _currentUser = null;
        print('CognitoService: Signed out');
      }
    } catch (e) {
      print('CognitoService: Sign out error - $e');
    }
  }
  
  /// Get user attributes (email, role, etc.)
  Future<Map<String, String>?> getUserAttributes() async {
    try {
      if (_currentUser == null) return null;
      
      final attributes = await _currentUser!.getUserAttributes();
      
      final Map<String, String> result = {};
      for (final attr in attributes) {
        result[attr.getName()] = attr.getValue();
      }
      
      return result;
    } catch (e) {
      print('CognitoService: Get attributes error - $e');
      return null;
    }
  }
  
  /// Get user role from custom attribute
  Future<String?> getUserRole() async {
    try {
      final attributes = await getUserAttributes();
      return attributes?['custom:custom:role'] ?? attributes?['custom:role'] ?? 'user';
    } catch (e) {
      print('CognitoService: Get role error - $e');
      return null;
    }
  }
  
  /// Get assigned devices from custom attribute
  Future<List<String>> getAssignedDevices() async {
    try {
      final attributes = await getUserAttributes();
      final devicesStr = attributes?['custom:custom:assigned_devs'] ?? attributes?['custom:assigned_devs'] ?? attributes?['custom:assigned_devices'] ?? '';
      if (devicesStr.isEmpty) return [];
      return devicesStr.split(',');
    } catch (e) {
      print('CognitoService: Get assigned devices error - $e');
      return [];
    }
  }
  
  /// Refresh session token
  Future<CognitoUserSession?> refreshSession() async {
    try {
      if (_currentUser == null) return null;
      
      final session = await _currentUser!.getSession();
      return session;
    } catch (e) {
      print('CognitoService: Refresh session error - $e');
      return null;
    }
  }
  
  /// Get access token for API calls
  Future<String?> getAccessToken() async {
    try {
      final session = await refreshSession();
      return session?.getIdToken().getJwtToken();
    } catch (e) {
      print('CognitoService: Get access token error - $e');
      return null;
    }
  }
  
  /// Stream of auth state changes
  Stream<bool> get authStateChanges {
    // Cognito doesn't have built-in auth state stream
    // You can implement this using a StreamController that you update on sign in/out
    return Stream.value(isSignedIn);
  }
  
  // ========== ADMIN FUNCTIONS ==========
  // Note: These require AWS SDK or AWS CLI commands
  // The amazon_cognito_identity_dart package doesn't support admin operations
  
  /// Create a new user (Admin only)
  /// This requires AWS CLI or backend Lambda function
  /// 
  /// Example using AWS CLI:
  /// ```bash
  /// aws cognito-idp admin-create-user \
  ///   --user-pool-id ap-south-1_LSTShtM9R \
  ///   --username user@example.com \
  ///   --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  ///     Name=custom:role,Value=client Name=custom:assigned_devices,Value="ahu-01,ahu-02" \
  ///   --temporary-password TempPass123! \
  ///   --message-action SUPPRESS \
  ///   --region ap-south-1
  /// ```
  static Future<bool> createUserViaAWS({
    required String email,
    required String role, // 'admin' or 'client'
    required String tempPassword,
    List<String>? assignedDevices,
    String? displayName,
  }) async {
    print('CognitoService: User creation requires AWS CLI or Console');
    print('Run this command:');
    final devicesStr = assignedDevices?.join(',') ?? '';
    print('''
aws cognito-idp admin-create-user \\
  --user-pool-id $userPoolId \\
  --username $email \\
  --user-attributes Name=email,Value=$email Name=email_verified,Value=true \\
    Name=custom:role,Value=$role Name=custom:assigned_devices,Value="$devicesStr" \\
  --temporary-password $tempPassword \\
  --message-action SUPPRESS \\
  --region $region
    ''');
    return false; // Cannot create directly from Flutter
  }
  
  /// Admin info message
  String get adminMessage {
    return '''
AWS Cognito Admin Operations:

User management (create, update, delete) requires:
1. AWS CLI commands
2. AWS Console (https://console.aws.amazon.com/cognito)
3. Backend Lambda API

For now, use AWS Console:
1. Go to: https://console.aws.amazon.com/cognito/v2/idp/user-pools/
2. Select region: ap-south-1
3. Click on user pool: $userPoolId
4. Go to "Users" tab
5. Click "Create user"

Or use AWS CLI - see createUserViaAWS() method for example.
    ''';
  }
}

