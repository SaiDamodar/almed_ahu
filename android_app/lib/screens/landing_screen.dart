import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_utils.dart';
import 'login_screen.dart';
import 'user_auth_screen.dart';

/// Landing screen with Admin and Hospital User options
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

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
                  SizedBox(height: ScreenUtils.getSpacing(context, 20)),
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

    return Card(
      margin: EdgeInsets.symmetric(horizontal: ScreenUtils.getPadding(context, 8)),
      child: InkWell(
        onTap: isComingSoon ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 20)),
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
            borderRadius: BorderRadius.circular(18),
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
                padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
                decoration: BoxDecoration(
                  color: isComingSoon
                      ? Colors.grey.shade400
                      : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isComingSoon ? Colors.grey.shade700 : color,
                  size: ScreenUtils.getIconSize(context, 32),
                ),
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 16)),
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
                                  fontSize: ScreenUtils.getFontSize(context, 18),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (isComingSoon)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ScreenUtils.getPadding(context, 6),
                              vertical: ScreenUtils.getSpacing(context, 3),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Soon',
                              style: TextStyle(
                                fontSize: ScreenUtils.getFontSize(context, 10),
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: ScreenUtils.getFontSize(context, 12),
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
                size: ScreenUtils.getIconSize(context, 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

