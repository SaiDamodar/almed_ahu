import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Firebase service for authentication and user management
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
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

  /// Sign in with Google (requires additional setup)
  Future<UserCredential?> signInWithGoogle() async {
    // TODO: Implement Google Sign-In
    // Requires google_sign_in package and OAuth setup
    print('FirebaseService: Google Sign-In not yet implemented');
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get user's assigned devices from Firestore
  Future<List<String>> getAssignedDevices(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final devices = data?['assignedDevices'] as List<dynamic>?;
        return devices?.map((e) => e.toString()).toList() ?? [];
      }
      return [];
    } catch (e) {
      print('FirebaseService: Error getting assigned devices - $e');
      return [];
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      print('FirebaseService: Error getting user data - $e');
      return null;
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<String?> initializeMessaging() async {
    try {
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

