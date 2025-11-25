import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/unified_login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/hospitals_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
              '/welcome': (context) => const WelcomeScreen(),
              '/login': (context) => const UnifiedLoginScreen(),
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
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.initializeAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        // Show loading while initializing auth state
        if (!appProvider.isInitialized) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                    const Color(0xFF334155),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // If not authenticated, show welcome screen
        if (!appProvider.isAuthenticated) {
          return const WelcomeScreen();
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

