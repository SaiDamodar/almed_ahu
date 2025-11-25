import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/passcode_dialog.dart';
import 'dashboard_screen.dart';

/// Modern, sleek login screen
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background
          _LoginBackground(isDark: isDark),
          
          // Theme toggle
          const Positioned(
            top: 48,
            right: 24,
            child: _ThemeToggle(),
          ),
          
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Company Logo
                    _LogoWidget(isDark: isDark),
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'AHU Control',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hospital Air Handling System',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 64),

                    // Role cards
                    const _ModernRoleCard(
                      role: UserRole.hospital,
                      icon: Icons.local_hospital_rounded,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _ModernRoleCard(
                      role: UserRole.admin,
                      icon: Icons.shield_rounded,
                      gradient: LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  final bool isDark;
  
  const _LoginBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                ]
              : [
                  Colors.white,
                  Colors.blue.shade50,
                  Colors.blue.shade100,
                ],
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  final bool isDark;
  
  const _LogoWidget({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Image.asset(
        isDark 
            ? 'assets/images/logo_light.png'
            : 'assets/images/logo_dark.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _FallbackLogo(isDark: isDark);
        },
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final bool isDark;
  
  const _FallbackLogo({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.lightPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.air,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ALMED',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w300,
            letterSpacing: 6,
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
      builder: (context, isDarkMode, _) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
        );
      },
    );
  }
}

class _ModernRoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final Gradient gradient;

  const _ModernRoleCard({
    required this.role,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withOpacity(0.1);
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectRole(context, role),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Icon with gradient
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 20),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.displayName,
                        style: theme.textTheme.displayMedium?.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectRole(BuildContext context, UserRole role) async {
    // Check if Admin role - show passcode dialog first
    if (role == UserRole.admin) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PasscodeDialog(),
      );
      
      if (result != true) return;
    }
    
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _LoadingDialog(),
      );
    }

    provider.setUserRole(role);
    final connected = await provider.initializeMqtt();
    provider.loadDefaultAhus();

    if (context.mounted) {
      Navigator.of(context).pop();

      if (connected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        _showConnectionError(context);
      }
    }
  }
  
  void _showConnectionError(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.error),
            SizedBox(width: 12),
            Text('Connection Failed'),
          ],
        ),
        content: const Text(
          'Could not connect to MQTT broker. Please check your network.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
