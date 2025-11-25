import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Screen to collect additional info after Google Sign-In
class GoogleSignInCompleteScreen extends StatefulWidget {
  final String googleId;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String idToken;

  const GoogleSignInCompleteScreen({
    super.key,
    required this.googleId,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.idToken,
  });

  @override
  State<GoogleSignInCompleteScreen> createState() =>
      _GoogleSignInCompleteScreenState();
}

class _GoogleSignInCompleteScreenState
    extends State<GoogleSignInCompleteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hospitalController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill username with display name if available
    if (widget.displayName.isNotEmpty) {
      _usernameController.text = widget.displayName;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate email is present
    if (widget.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email is missing. Please try signing in with Google again.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    print('Google Registration - Email: ${widget.email}, GoogleId: ${widget.googleId}');

    final success = await appProvider.registerWithGoogle(
      googleId: widget.googleId,
      email: widget.email,
      username: _usernameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      hospitalName: _hospitalController.text.trim(),
      profileImageUrl: widget.photoUrl,
      idToken: widget.idToken,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                appProvider.errorMessage ?? 'Registration failed'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Registration'),
        elevation: 0,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Google Account Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (widget.photoUrl != null)
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(widget.photoUrl!),
                            )
                          else
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  AppTheme.lightPrimary.withOpacity(0.1),
                              child: Text(
                                widget.displayName.isNotEmpty
                                    ? widget.displayName[0].toUpperCase()
                                    : 'G',
                                style: TextStyle(
                                  color: AppTheme.lightPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.email.isNotEmpty 
                                      ? widget.email 
                                      : 'Email not available',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: widget.email.isEmpty 
                                        ? AppTheme.error 
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: AppTheme.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Google Account',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Additional Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please provide the following details to complete your registration',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.lightOnSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        _validateRequired(value, 'Username'),
                  ),
                  const SizedBox(height: 16),

                  // Phone Number Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 16),

                  // Hospital Name Field
                  TextFormField(
                    controller: _hospitalController,
                    decoration: InputDecoration(
                      labelText: 'Hospital Name',
                      prefixIcon: const Icon(Icons.local_hospital_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        _validateRequired(value, 'Hospital name'),
                  ),
                  const SizedBox(height: 32),

                  // Complete Registration Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCompleteRegistration,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: AppTheme.lightPrimary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Complete Registration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

