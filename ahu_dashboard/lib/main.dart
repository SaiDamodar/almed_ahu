import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('FirebaseService: Handling background message - ${message.messageId}');
  // TODO: Handle background notification
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase on all platforms
  try {
    if (kIsWeb) {
      // For web, Firebase is initialized via index.html script
      // Wait a bit for the script to load
      await Future.delayed(const Duration(milliseconds: 100));
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAEhD6G7resVDxTLqp3Ih0A9tbZqlvd-1Q",
          authDomain: "almed-ahu-cloud.firebaseapp.com",
          projectId: "almed-ahu-cloud",
          storageBucket: "almed-ahu-cloud.firebasestorage.app",
          messagingSenderId: "600445539105",
          appId: "1:600445539105:web:web_app_id",
        ),
      );
    } else {
      // For mobile, use default initialization
      await Firebase.initializeApp();
    }
    print('Firebase: Initialized successfully');

    // Setup background message handler (only on mobile)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e, stackTrace) {
    print('Firebase: Initialization error - $e');
    print('Firebase: Stack trace - $stackTrace');
    print('Firebase: Continuing without Firebase (may need config files)');
    // On web, try to continue even if Firebase init fails
  }

  runApp(const AhuDashboardApp());
}

class AhuDashboardApp extends StatelessWidget {
  const AhuDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'AHU Control Dashboard',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routes: {
              '/': (context) => _HomeWrapper(),
              '/login': (context) => const LoginScreen(),
              '/admin': (context) => const AdminDashboardScreen(),
            },
            initialRoute: '/',
          );
        },
      ),
    );
  }
}

/// Home wrapper that routes based on platform and auth state
class _HomeWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // On web, show admin dashboard directly (skip login for now)
    if (kIsWeb) {
      return const AdminDashboardScreen();
    }

    // On mobile, show login screen
    return const LoginScreen();
  }
}
