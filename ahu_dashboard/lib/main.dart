import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('FirebaseService: Handling background message - ${message.messageId}');
  // TODO: Handle background notification
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase only on mobile platforms
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      print('Firebase: Initialized successfully');
      
      // Setup background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('Firebase: Initialization error - $e');
      print('Firebase: Continuing without Firebase (may need config files)');
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
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}
