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
    final screenPadding = ScreenUtils.getScreenPadding(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                    Color(0xFF334155),
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
              padding: screenPadding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ALMED Logo
                    _LogoSection(isDark: isDark),
                    SizedBox(height: ScreenUtils.getSpacing(context, 48)),

                    // Welcome Text
                    _WelcomeText(isDark: isDark),
                    SizedBox(height: ScreenUtils.getSpacing(context, 40)),

                    // Buttons
                    _ActionButtons(isDark: isDark),
                    SizedBox(height: ScreenUtils.getSpacing(context, 32)),

                    // Theme toggle
                    const _ThemeToggle(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  final bool isDark;

  const _LogoSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: ScreenUtils.getPadding(context, 220),
        maxHeight: ScreenUtils.getSpacing(context, 160),
      ),
      child: Image.asset(
        isDark ? 'assets/images/logo_light.png' : 'assets/images/logo_dark.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisSize: MainAxisSize.min,
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
                style: TextStyle(
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
    );
  }
}

class _WelcomeText extends StatelessWidget {
  final bool isDark;

  const _WelcomeText({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 14),
            color: isDark
                ? AppTheme.darkOnSurfaceVariant
                : AppTheme.lightOnSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isDark;

  const _ActionButtons({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ScreenUtils.getButtonHeight(context);
    final borderRadius = ScreenUtils.getBorderRadius(context, 16);

    return Column(
      children: [
        // Sign Up Button
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              backgroundColor: AppTheme.lightPrimary,
              elevation: 2,
            ),
            child: Text(
              'Sign Up',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 16)),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UnifiedLoginScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              side: const BorderSide(color: AppTheme.lightPrimary, width: 2),
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
      ],
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    return Selector<ThemeProvider, bool>(
      selector: (_, provider) => provider.isDarkMode,
      builder: (context, isDarkMode, child) {
        return IconButton(
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          onPressed: () {
            context.read<ThemeProvider>().toggleTheme();
          },
          tooltip: 'Toggle theme',
        );
      },
    );
  }
}
