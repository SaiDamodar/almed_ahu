import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Authentication Service for Google Sign-In
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID token
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  /// Sign in with Google
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return GoogleSignInResult(
          success: false,
          error: 'Sign-in canceled',
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        return GoogleSignInResult(
          success: false,
          error: 'Failed to sign in with Google',
        );
      }

      // Reload user to get fresh data (including email)
      await user.reload();
      // Small delay to ensure data is refreshed
      await Future.delayed(const Duration(milliseconds: 500));
      final refreshedUser = _auth.currentUser;
      
      // Get email from multiple sources (prioritize Firebase user, fallback to Google account)
      // GoogleSignInAccount.email is the most reliable source
      String? email = googleUser.email ?? 
                     refreshedUser?.email ?? 
                     user.email;
      
      // Get display name from multiple sources
      String? displayName = googleUser.displayName ?? 
                           refreshedUser?.displayName ?? 
                           user.displayName ?? '';
      
      // Get photo URL from multiple sources
      String? photoUrl = googleUser.photoUrl ?? 
                        refreshedUser?.photoURL ?? 
                        user.photoURL;

      print('Firebase Auth - Email from googleUser: ${googleUser.email}');
      print('Firebase Auth - Email from refreshedUser: ${refreshedUser?.email}');
      print('Firebase Auth - Email from user: ${user.email}');
      print('Firebase Auth - Final email: $email');
      print('Firebase Auth - Final displayName: $displayName');

      // Get ID token for backend verification
      final idToken = await (refreshedUser ?? user).getIdToken();

      if (email == null || email.isEmpty) {
        return GoogleSignInResult(
          success: false,
          error: 'Email not available from Google account. Please ensure your Google account has an email address.',
        );
      }

      return GoogleSignInResult(
        success: true,
        user: refreshedUser ?? user,
        googleId: (refreshedUser ?? user).uid,
        email: email,
        displayName: displayName ?? '',
        photoUrl: photoUrl,
        idToken: idToken,
      );
    } on FirebaseAuthException catch (e) {
      return GoogleSignInResult(
        success: false,
        error: e.message ?? 'Firebase authentication failed',
      );
    } catch (e) {
      return GoogleSignInResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;
}

/// Result of Google Sign-In attempt
class GoogleSignInResult {
  final bool success;
  final User? user;
  final String? googleId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;
  final String? error;

  GoogleSignInResult({
    required this.success,
    this.user,
    this.googleId,
    this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
    this.error,
  });
}

