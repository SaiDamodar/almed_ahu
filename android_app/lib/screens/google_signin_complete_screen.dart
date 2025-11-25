import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_utils.dart';
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

    if (widget.email.isEmpty) {
      _showError('Email is missing. Please try signing in with Google again.');
      return;
    }

    setState(() => _isLoading = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    final success = await appProvider.registerWithGoogle(
      googleId: widget.googleId,
      email: widget.email,
      username: _usernameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      hospitalName: _hospitalController.text.trim(),
      profileImageUrl: widget.photoUrl,
      idToken: widget.idToken,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      _showError(appProvider.errorMessage ?? 'Registration failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
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
        title: Text(
          'Complete Registration',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [AppTheme.darkBackground, AppTheme.darkSurface, Color(0xFF334155)]
                : [Colors.white, Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: ScreenUtils.getScreenPadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GoogleAccountCard(
                      displayName: widget.displayName,
                      email: widget.email,
                      photoUrl: widget.photoUrl,
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 24)),
                    _SectionHeader(isDark: isDark),
                    SizedBox(height: ScreenUtils.getSpacing(context, 20)),
                    _FormFields(
                      usernameController: _usernameController,
                      phoneController: _phoneController,
                      hospitalController: _hospitalController,
                      validateRequired: _validateRequired,
                      validatePhone: _validatePhone,
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 28)),
                    _SubmitButton(
                      isLoading: _isLoading,
                      onPressed: _handleCompleteRegistration,
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 20)),
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

class _GoogleAccountCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;

  const _GoogleAccountCard({
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
      ),
      child: Padding(
        padding: ScreenUtils.getCardPadding(context),
        child: Row(
          children: [
            _Avatar(displayName: displayName, photoUrl: photoUrl),
            SizedBox(width: ScreenUtils.getPadding(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                  Text(
                    email.isNotEmpty ? email : 'Email not available',
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 12),
                      color: email.isEmpty ? AppTheme.error : null,
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 8)),
                  _GoogleBadge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String displayName;
  final String? photoUrl;

  const _Avatar({required this.displayName, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final size = ScreenUtils.getIconSize(context, 28);

    if (photoUrl != null) {
      return CircleAvatar(
        radius: size,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }

    return CircleAvatar(
      radius: size,
      backgroundColor: AppTheme.lightPrimary.withOpacity(0.1),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
        style: TextStyle(
          color: AppTheme.lightPrimary,
          fontWeight: FontWeight.bold,
          fontSize: ScreenUtils.getFontSize(context, 18),
        ),
      ),
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 8),
        vertical: ScreenUtils.getSpacing(context, 4),
      ),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: ScreenUtils.getIconSize(context, 14),
            color: AppTheme.success,
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 4)),
          Text(
            'Google Account',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 10),
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final bool isDark;

  const _SectionHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 6)),
        Text(
          'Please provide the following details to complete your registration',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 13),
            color: isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FormFields extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController phoneController;
  final TextEditingController hospitalController;
  final String? Function(String?, String) validateRequired;
  final String? Function(String?) validatePhone;

  const _FormFields({
    required this.usernameController,
    required this.phoneController,
    required this.hospitalController,
    required this.validateRequired,
    required this.validatePhone,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 12);
    final fieldSpacing = ScreenUtils.getSpacing(context, 14);

    return Column(
      children: [
        _buildField(
          context,
          controller: usernameController,
          label: 'Username',
          icon: Icons.person_outlined,
          validator: (v) => validateRequired(v, 'Username'),
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildField(
          context,
          controller: phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: validatePhone,
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildField(
          context,
          controller: hospitalController,
          label: 'Hospital Name',
          icon: Icons.local_hospital_outlined,
          validator: (v) => validateRequired(v, 'Hospital name'),
          borderRadius: borderRadius,
        ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required double borderRadius,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 15)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, 16),
          vertical: ScreenUtils.getSpacing(context, 14),
        ),
      ),
      validator: validator,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ScreenUtils.getButtonHeight(context),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
          ),
          backgroundColor: AppTheme.lightPrimary,
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Complete Registration',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
