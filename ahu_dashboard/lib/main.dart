import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'dart:async' show TimeoutException;
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

  // Skip Firebase on web for now (UI-only mode)
  if (kIsWeb) {
    print('Web platform: Skipping Firebase initialization - running in UI demo mode');
    // Firebase initialization skipped - all Firebase features will show "not initialized" errors
    // This allows the UI to work instantly without waiting for Firebase connection
  } else {
    // Mobile initialization
    try {
      await Firebase.initializeApp();
      if (Platform.isAndroid || Platform.isIOS) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
    } catch (e) {
      print('Firebase mobile init error: $e');
    }
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

