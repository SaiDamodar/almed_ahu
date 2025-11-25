import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_utils.dart';
import 'unified_login_screen.dart';
import 'register_screen.dart';

/// Welcome screen with Sign Up and Login options
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: ScreenUtils.getPadding(context, 24),
                vertical: ScreenUtils.getSpacing(context, 40),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ALMED Logo
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: ScreenUtils.getPadding(context, 200),
                      maxHeight: ScreenUtils.getSpacing(context, 150),
                    ),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/logo_light.png'
                          : 'assets/images/logo_dark.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to text logo if image not found
                        return Column(
                          children: [
                            Text(
                              'ALMED',
                              style: TextStyle(
                                fontFamily: 'Verdana',
                                fontSize: ScreenUtils.getFontSize(context, 48),
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: ScreenUtils.getSpacing(context, 8)),
                            Text(
                              'AHU Control System',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: ScreenUtils.getFontSize(context, 14),
                                    color: isDark
                                        ? AppTheme.darkOnSurfaceVariant
                                        : AppTheme.lightOnSurfaceVariant,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 60)),

                  // Welcome Text
                  Text(
                    'Welcome',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: ScreenUtils.getFontSize(context, 32),
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 8)),
                  Text(
                    'Sign in to your account or create a new one',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: ScreenUtils.getFontSize(context, 14),
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.lightOnSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 48)),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: ScreenUtils.getSpacing(context, 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppTheme.lightPrimary,
                      ),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 16)),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const UnifiedLoginScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: ScreenUtils.getSpacing(context, 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: AppTheme.lightPrimary,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 40)),

                  // Theme toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return IconButton(
                        icon: Icon(
                          themeProvider.isDarkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                        onPressed: () => themeProvider.toggleTheme(),
                        tooltip: 'Toggle theme',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

