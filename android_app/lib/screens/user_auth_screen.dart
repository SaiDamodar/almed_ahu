import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// User authentication page for hospital user registration
/// This is a placeholder for future hospital user setup
class UserAuthScreen extends StatelessWidget {
  const UserAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital User'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.06),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ALMED Logo
                Container(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth * 0.4,
                    maxHeight: screenHeight * 0.15,
                  ),
                  child: Image.asset(
                    isDark
                        ? 'assets/images/logo_light.png'
                        : 'assets/images/logo_dark.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.local_hospital_rounded,
                        size: screenWidth * 0.2,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      );
                    },
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                Text(
                  'Hospital User Registration',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: screenWidth * 0.06,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'This feature will allow admins to register and manage hospital users.\n\nHospital users will have access to view and monitor AHU units within their assigned hospital.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: screenWidth * 0.038,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.05),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: screenHeight * 0.02,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

