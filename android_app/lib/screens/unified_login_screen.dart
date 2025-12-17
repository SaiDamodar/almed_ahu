import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import '../utils/screen_utils.dart';
import 'admin_dashboard.dart';
import 'client_dashboard.dart';
import 'register_screen.dart';
import 'google_signin_complete_screen.dart';

/// Unified login screen for both admin and hospital users
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Check if admin credentials
    if (email.toLowerCase() == AppConfig.adminUsername.toLowerCase() && 
        password == AppConfig.adminPassword) {
      final success = await appProvider.login(AppConfig.adminUsername, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
          (route) => false,
        );
      } else {
        _showError(appProvider.errorMessage ?? 'Login failed');
      }
    } else {
      final success = await appProvider.userLogin(email, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ClientDashboard()),
          (route) => false,
        );
      } else {
        _showError(appProvider.errorMessage ?? 'Login failed');
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    try {
      final result = await appProvider.signInWithGoogle();

      if (!mounted) return;

      if (result.success && result.user != null) {
        final loginSuccess = await appProvider.userLoginWithGoogle(
          result.googleId ?? '',
          result.email ?? '',
          result.displayName ?? '',
          result.photoUrl,
          result.idToken ?? '',
        );

        if (!mounted) return;

        if (loginSuccess) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ClientDashboard()),
            (route) => false,
          );
        } else {
          final errorMessage = appProvider.errorMessage ?? '';
          if (errorMessage.contains('not found') || 
              errorMessage.contains('Please register') ||
              errorMessage.contains('404')) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GoogleSignInCompleteScreen(
                  googleId: result.googleId ?? '',
                  email: result.email ?? '',
                  displayName: result.displayName ?? '',
                  photoUrl: result.photoUrl,
                  idToken: result.idToken ?? '',
                ),
              ),
            );
          } else {
            _showError(errorMessage.isNotEmpty ? errorMessage : 'Google login failed');
          }
        }
      } else {
        _showError(result.error ?? 'Google Sign-In failed');
      }
    } catch (e) {
      if (mounted) {
        _showError('An unexpected error occurred: $e');
      }
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
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(context, isDark),
                      SizedBox(height: ScreenUtils.getSpacing(context, 32)),
                      _buildLoginCard(context, isDark),
                      SizedBox(height: ScreenUtils.getSpacing(context, 20)),
                      const _ThemeToggle(),
                    ],
                  ),
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
          style: TextStyle(
            fontFamily: 'Verdana',
            fontSize: ScreenUtils.getFontSize(context, 42),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 4)),
        Text(
          'Login',
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

  Widget _buildLoginCard(BuildContext context, bool isDark) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 24);
    final cardPadding = ScreenUtils.getPadding(context, 24);

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Login',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: ScreenUtils.getFontSize(context, 22),
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 24)),
          _buildEmailField(context),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          _buildPasswordField(context),
          SizedBox(height: ScreenUtils.getSpacing(context, 24)),
          _buildLoginButton(context),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          _buildDivider(context),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          _buildGoogleButton(context),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          _buildSignUpLink(context),
        ],
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 15)),
      decoration: InputDecoration(
        labelText: 'Email or Username',
        prefixIcon: const Icon(Icons.email_outlined, size: 20),
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, 16),
          vertical: ScreenUtils.getSpacing(context, 14),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter email or username';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 15)),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outlined, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, 16),
          vertical: ScreenUtils.getSpacing(context, 14),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter password';
        }
        return null;
      },
      onFieldSubmitted: (_) => _handleEmailLogin(),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final buttonHeight = ScreenUtils.getButtonHeight(context);

    return SizedBox(
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailLogin,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ScreenUtils.getBorderRadius(context, 14),
            ),
          ),
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
                'Login',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ScreenUtils.getPadding(context, 16),
          ),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 12),
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    final buttonHeight = ScreenUtils.getButtonHeight(context);

    return SizedBox(
      height: buttonHeight,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleLogin,
        icon: const Icon(Icons.g_mobiledata, size: 24),
        label: Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 15),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ScreenUtils.getBorderRadius(context, 14),
            ),
          ),
          side: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
      },
      child: Text(
        'Don\'t have an account? Sign Up',
        style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 13)),
      ),
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
          onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          tooltip: 'Toggle theme',
        );
      },
    );
  }
}
