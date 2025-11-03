import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase service for authentication and user management
class FirebaseService {
  // Lazy initialization - only access when Firebase is ready
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Check if Firebase is initialized
  bool get isFirebaseInitialized {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Current user (safe - returns null if Firebase not ready)
  User? get currentUser {
    try {
      return isFirebaseInitialized ? _auth.currentUser : null;
    } catch (e) {
      return null;
    }
  }

  /// Stream of auth state changes (safe - returns empty stream if not ready)
  Stream<User?> get authStateChanges {
    try {
      return isFirebaseInitialized ? _auth.authStateChanges() : Stream.value(null);
    } catch (e) {
      return Stream.value(null);
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (!isFirebaseInitialized) {
        print('FirebaseService: Firebase not initialized');
        return null;
      }
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      print('FirebaseService: Sign in error - $e');
      return null;
    }
  }

  /// Sign in with Google
  /// Returns UserCredential if successful, null if cancelled or error
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (!isFirebaseInitialized) {
        print('FirebaseService: Firebase not initialized');
        return null;
      }
      print('FirebaseService: Starting Google Sign-In flow...');
      
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('FirebaseService: User cancelled Google Sign-In');
        return null; // User cancelled
      }

      print('FirebaseService: Google user authenticated - ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      print('FirebaseService: Firebase authentication successful');
      return userCredential;
    } catch (e) {
      print('FirebaseService: Google Sign-In error - $e');
      return null;
    }
  }

  /// Verify client access (requires access key)
  /// Throws exception if verification fails
  Future<Map<String, dynamic>> verifyClientAccess({
    required String accessKey,
  }) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated. Please sign in first.');
      }

      final email = _auth.currentUser!.email;
      if (email == null) {
        throw Exception('User email not available');
      }

      print('FirebaseService: Verifying client access for $email');

      final userDoc = await _firestore.collection('users').doc(email).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found in system. Please contact administrator.');
      }

      final userData = userDoc.data()!;

      // Verify role
      if (userData['role'] != 'client') {
        throw Exception('This account is not authorized for client access.');
      }

      // Verify access key
      final storedAccessKey = userData['accessKey'] as String?;
      if (storedAccessKey == null || storedAccessKey != accessKey.trim()) {
        throw Exception('Invalid access key. Please contact administrator.');
      }

      // Verify account is active
      if (userData['isActive'] != true) {
        throw Exception('Your account has been deactivated. Please contact administrator.');
      }

      // Update last login
      await _firestore.collection('users').doc(email).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print('FirebaseService: Client access verified successfully');
      return userData;
    } catch (e) {
      print('FirebaseService: Client verification error - $e');
      rethrow;
    }
  }

  /// Verify admin access
  /// Throws exception if verification fails
  Future<Map<String, dynamic>> verifyAdminAccess() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated. Please sign in first.');
      }

      final email = _auth.currentUser!.email;
      if (email == null) {
        throw Exception('User email not available');
      }

      print('FirebaseService: Verifying admin access for $email');

      final userDoc = await _firestore.collection('users').doc(email).get();
      
      if (!userDoc.exists) {
        throw Exception('User not found in system. Admin privileges required.');
      }

      final userData = userDoc.data()!;

      // Verify role
      if (userData['role'] != 'admin') {
        throw Exception('Access Denied. Admin privileges required.');
      }

      // Verify account is active
      if (userData['isActive'] != true) {
        throw Exception('Your account has been deactivated. Please contact administrator.');
      }

      // Update last login
      await _firestore.collection('users').doc(email).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      print('FirebaseService: Admin access verified successfully');
      return userData;
    } catch (e) {
      print('FirebaseService: Admin verification error - $e');
      rethrow;
    }
  }

  /// Get assigned devices for current user
  Future<List<String>> getAssignedDevices([String? userId]) async {
    try {
      final email = userId ?? _auth.currentUser?.email;
      if (email == null) return [];

      final userDoc = await _firestore.collection('users').doc(email).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final devices = userData['assignedDevices'] as List<dynamic>?;
      return devices?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      print('FirebaseService: Error getting devices - $e');
      return [];
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData([String? userId]) async {
    try {
      final email = userId ?? _auth.currentUser?.email;
      if (email == null) return null;

      final userDoc = await _firestore.collection('users').doc(email).get();
      return userDoc.data();
    } catch (e) {
      print('FirebaseService: Error getting user data - $e');
      return null;
    }
  }

  /// Create new user (admin only)
  /// Used by admin to create client or admin accounts
  Future<void> createUser({
    required String email,
    required String role,
    String? accessKey,
    List<String>? assignedDevices,
    String? displayName,
  }) async {
    try {
      if (!isFirebaseInitialized) {
        throw Exception('Firebase not initialized. Please wait or refresh the page.');
      }
      
      if (role == 'client' && accessKey == null) {
        throw Exception('Access key is required for client accounts');
      }

      if (role == 'client' && (assignedDevices == null || assignedDevices.isEmpty)) {
        throw Exception('At least one assigned device is required for client accounts');
      }

      final userData = <String, dynamic>{
        'email': email,
        'role': role,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
      };

      if (accessKey != null) {
        userData['accessKey'] = accessKey;
      }

      if (assignedDevices != null) {
        userData['assignedDevices'] = assignedDevices;
      }

      if (displayName != null) {
        userData['displayName'] = displayName;
      }

      await _firestore.collection('users').doc(email).set(userData);
      print('FirebaseService: User created successfully - $email');
    } catch (e) {
      print('FirebaseService: Error creating user - $e');
      rethrow;
    }
  }

  /// Update user account (admin only)
  Future<void> updateUser({
    required String email,
    String? accessKey,
    List<String>? assignedDevices,
    bool? isActive,
    String? displayName,
  }) async {
    try {
      if (!isFirebaseInitialized) {
        throw Exception('Firebase not initialized. Please wait or refresh the page.');
      }
      
      final updateData = <String, dynamic>{};

      if (accessKey != null) {
        updateData['accessKey'] = accessKey;
      }

      if (assignedDevices != null) {
        updateData['assignedDevices'] = assignedDevices;
      }

      if (isActive != null) {
        updateData['isActive'] = isActive;
      }

      if (displayName != null) {
        updateData['displayName'] = displayName;
      }

      await _firestore.collection('users').doc(email).update(updateData);
      print('FirebaseService: User updated successfully - $email');
    } catch (e) {
      print('FirebaseService: Error updating user - $e');
      rethrow;
    }
  }

  /// Get all users (admin only)
  Stream<QuerySnapshot> getAllUsers() {
    try {
      if (!isFirebaseInitialized) {
        print('FirebaseService: Firebase not initialized - returning empty stream');
        return Stream.empty();
      }
      return _firestore.collection('users').snapshots();
    } catch (e) {
      print('FirebaseService: Error getting users - $e');
      return Stream.empty();
    }
  }

  /// Delete user (admin only)
  Future<void> deleteUser(String email) async {
    try {
      if (!isFirebaseInitialized) {
        throw Exception('Firebase not initialized. Please wait or refresh the page.');
      }
      await _firestore.collection('users').doc(email).delete();
      print('FirebaseService: User deleted successfully - $email');
    } catch (e) {
      print('FirebaseService: Error deleting user - $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!isFirebaseInitialized) {
        print('FirebaseService: Firebase not initialized');
        return;
      }
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('FirebaseService: User signed out successfully');
    } catch (e) {
      print('FirebaseService: Sign out error - $e');
      rethrow;
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<String?> initializeMessaging() async {
    try {
      if (!isFirebaseInitialized) {
        print('FirebaseService: Firebase not initialized');
        return null;
      }
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('FirebaseService: User granted notification permission');
        
        // Get FCM token
        String? token = await _messaging.getToken();
        print('FirebaseService: FCM Token - $token');
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          print('FirebaseService: FCM Token refreshed - $newToken');
          // TODO: Send token to your backend/Firestore
        });

        return token;
      } else {
        print('FirebaseService: User declined notification permission');
        return null;
      }
    } catch (e) {
      print('FirebaseService: Error initializing messaging - $e');
      return null;
    }
  }

  // Note: Background message handler must be top-level function
  // Defined in main.dart as firebaseMessagingBackgroundHandler
}


