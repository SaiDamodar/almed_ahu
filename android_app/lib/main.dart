import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/user_login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/hospitals_screen.dart';

void main() {
  runApp(const AlmedAhuApp());
}

class AlmedAhuApp extends StatelessWidget {
  const AlmedAhuApp({super.key});

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
            title: 'ALMED AHU',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            routes: {
              '/landing': (context) => const LandingScreen(),
              '/admin-login': (context) => const LoginScreen(),
              '/user-login': (context) => const UserLoginScreen(),
              '/admin-dashboard': (context) => const HospitalsScreen(),
              '/user-home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Wrapper to check authentication state and route accordingly
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        // If not authenticated, show landing screen
        if (!appProvider.isAuthenticated) {
          return const LandingScreen();
        }

        // If authenticated as admin, show admin dashboard
        if (appProvider.isAdmin) {
          return const HospitalsScreen();
        }

        // If authenticated as hospital user, show home screen
        return const HomeScreen();
      },
    );
  }
}

