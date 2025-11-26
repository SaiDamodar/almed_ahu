import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/register_request.dart';
import '../utils/screen_utils.dart';
import 'client_dashboard.dart';

/// Registration screen for hospital users
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _hospitalController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    final registerRequest = RegisterRequest(
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      hospitalName: _hospitalController.text.trim(),
      password: _passwordController.text,
    );

    final success = await appProvider.register(registerRequest);

    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ClientDashboard()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appProvider.errorMessage ?? 'Registration failed'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (value.length < 10) return 'Enter a valid phone number';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenPadding = ScreenUtils.getScreenPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Register',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
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
          child: SingleChildScrollView(
            padding: screenPadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, isDark),
                    SizedBox(height: ScreenUtils.getSpacing(context, 24)),
                    _buildFormFields(context),
                    SizedBox(height: ScreenUtils.getSpacing(context, 24)),
                    _buildRegisterButton(context),
                    SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                    _buildLoginLink(context),
                    SizedBox(height: ScreenUtils.getSpacing(context, 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      children: [
        Text(
          'ALMED',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Verdana',
            fontSize: ScreenUtils.getFontSize(context, 36),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 6)),
        Text(
          'Hospital User Registration',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 14),
            color: isDark
                ? AppTheme.darkOnSurfaceVariant
                : AppTheme.lightOnSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(BuildContext context) {
    final fieldSpacing = ScreenUtils.getSpacing(context, 14);
    final borderRadius = ScreenUtils.getBorderRadius(context, 12);

    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _usernameController,
          label: 'Username',
          icon: Icons.person_outlined,
          validator: (v) => _validateRequired(v, 'Username'),
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildTextField(
          controller: _hospitalController,
          label: 'Hospital Name',
          icon: Icons.local_hospital_outlined,
          validator: (v) => _validateRequired(v, 'Hospital name'),
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          validator: _validatePassword,
          borderRadius: borderRadius,
        ),
        SizedBox(height: fieldSpacing),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          obscure: _obscureConfirmPassword,
          onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          validator: _validateConfirmPassword,
          borderRadius: borderRadius,
        ),
      ],
    );
  }

  Widget _buildTextField({
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    required double borderRadius,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 15)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outlined, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
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

  Widget _buildRegisterButton(BuildContext context) {
    final buttonHeight = ScreenUtils.getButtonHeight(context);

    return SizedBox(
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ScreenUtils.getBorderRadius(context, 12),
            ),
          ),
          backgroundColor: AppTheme.lightPrimary,
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Register',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 13),
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Login',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
