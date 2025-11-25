import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/hospitals_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
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
    return Selector<AppProvider, _AuthState>(
      selector: (_, provider) => _AuthState(
        isInitialized: provider.isInitialized,
        isAuthenticated: provider.isAuthenticated,
        isAdmin: provider.isAdmin,
      ),
      builder: (context, state, child) {
        // Show loading while initializing auth state
        if (!state.isInitialized) {
          return const _LoadingScreen();
        }

        // If not authenticated, show welcome screen
        if (!state.isAuthenticated) {
          return const WelcomeScreen();
        }

        // If authenticated as admin, show admin dashboard
        if (state.isAdmin) {
          return const HospitalsScreen();
        }

        // If authenticated as hospital user, show home screen
        return const HomeScreen();
      },
    );
  }
}

/// Immutable auth state for efficient comparisons
class _AuthState {
  final bool isInitialized;
  final bool isAuthenticated;
  final bool isAdmin;

  const _AuthState({
    required this.isInitialized,
    required this.isAuthenticated,
    required this.isAdmin,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AuthState &&
          runtimeType == other.runtimeType &&
          isInitialized == other.isInitialized &&
          isAuthenticated == other.isAuthenticated &&
          isAdmin == other.isAdmin;

  @override
  int get hashCode =>
      isInitialized.hashCode ^ isAuthenticated.hashCode ^ isAdmin.hashCode;
}

/// Loading screen widget
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                    const Color(0xFF334155),
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50,
                    Colors.blue.shade100,
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ALMED',
                style: TextStyle(
                  fontFamily: 'Verdana',
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
