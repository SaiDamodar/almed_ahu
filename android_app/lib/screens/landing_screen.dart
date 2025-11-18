import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'user_auth_screen.dart';

/// Landing screen with Admin and Hospital User options
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.05,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ALMED Logo
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: screenWidth * 0.5,
                      maxHeight: screenHeight * 0.2,
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
                                fontSize: screenWidth * 0.12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AHU Control System',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                  SizedBox(height: screenHeight * 0.08),

                  // User Type Selection Cards
                  _UserTypeCard(
                    title: 'Admin',
                    icon: Icons.admin_panel_settings_rounded,
                    description: 'Full system access and control',
                    color: AppTheme.info,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  _UserTypeCard(
                    title: 'Hospital User',
                    icon: Icons.local_hospital_rounded,
                    description: 'Coming Soon',
                    color: AppTheme.success,
                    isComingSoon: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UserAuthScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.05),

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

class _UserTypeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final Color color;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.color,
    this.isComingSoon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: InkWell(
        onTap: isComingSoon ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.06),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isComingSoon
                  ? [
                      Colors.grey.shade300,
                      Colors.grey.shade200,
                    ]
                  : isDark
                      ? [
                          color.withOpacity(0.2),
                          color.withOpacity(0.1),
                        ]
                      : [
                          color.withOpacity(0.1),
                          color.withOpacity(0.05),
                        ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isComingSoon
                  ? Colors.grey.shade400
                  : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: isComingSoon
                      ? Colors.grey.shade400
                      : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isComingSoon ? Colors.grey.shade700 : color,
                  size: screenWidth * 0.08,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontSize: screenWidth * 0.06,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (isComingSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.lightOnSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isComingSoon
                    ? Colors.grey.shade600
                    : color,
                size: screenWidth * 0.06,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

