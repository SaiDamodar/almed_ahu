import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Touch-friendly passcode dialog for Admin access
class PasscodeDialog extends StatefulWidget {
  const PasscodeDialog({super.key});

  @override
  State<PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<PasscodeDialog> with SingleTickerProviderStateMixin {
  static const String adminPasscode = '1234'; // Default passcode
  String _enteredPasscode = '';
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_enteredPasscode.length < 4) {
      setState(() {
        _enteredPasscode += number;
        _isError = false;
      });

      // Auto-verify when 4 digits entered
      if (_enteredPasscode.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), _verifyPasscode);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPasscode.isNotEmpty) {
      setState(() {
        _enteredPasscode = _enteredPasscode.substring(0, _enteredPasscode.length - 1);
        _isError = false;
      });
    }
  }

  void _verifyPasscode() {
    if (_enteredPasscode == adminPasscode) {
      Navigator.of(context).pop(true); // Success
    } else {
      // Show error and shake animation
      setState(() {
        _isError = true;
      });
      _shakeController.forward(from: 0).then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            _enteredPasscode = '';
            _isError = false;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50,
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.lightPrimary,
                      AppTheme.lightPrimary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.lightPrimary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Admin Access',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter 4-digit passcode',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              
              // Passcode dots display with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * (_shakeController.status == AnimationStatus.forward ? 1 : -1), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError
                            ? AppTheme.error
                            : index < _enteredPasscode.length
                                ? AppTheme.lightPrimary
                                : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                        border: Border.all(
                          color: _isError
                              ? AppTheme.error
                              : AppTheme.lightPrimary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),
              
              // Numeric keypad
              _NumericKeypad(
                onNumberPressed: _onNumberPressed,
                onBackspace: _onBackspace,
                isDark: isDark,
              ),
              
              const SizedBox(height: 16),
              
              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Touch-friendly numeric keypad widget
class _NumericKeypad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback onBackspace;
  final bool isDark;

  const _NumericKeypad({
    required this.onNumberPressed,
    required this.onBackspace,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: 1 2 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadButton('1', onNumberPressed, isDark),
            const SizedBox(width: 16),
            _KeypadButton('2', onNumberPressed, isDark),
            const SizedBox(width: 16),
            _KeypadButton('3', onNumberPressed, isDark),
          ],
        ),
        const SizedBox(height: 16),
        
        // Row 2: 4 5 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadButton('4', onNumberPressed, isDark),
            const SizedBox(width: 16),
            _KeypadButton('5', onNumberPressed, isDark),
            const SizedBox(width: 16),
            _KeypadButton('6', onNumberPressed, isDark),
          ],
        ),
        const SizedBox(height: 16),
        
        // Row 3: 7 8 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadButton('7', onNumberPressed, isDark),
            const SizedBox(width: 16),
            _KeypadButton('8', onNumberPressed, isDark),
            const SizedBox(width: 16),
            _KeypadButton('9', onNumberPressed, isDark),
          ],
        ),
        const SizedBox(height: 16),
        
        // Row 4: - 0 backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty space
            const SizedBox(width: 80, height: 80),
            const SizedBox(width: 16),
            _KeypadButton('0', onNumberPressed, isDark),
            const SizedBox(width: 16),
            // Backspace button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBackspace,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.backspace_rounded,
                    size: 28,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual keypad button
class _KeypadButton extends StatelessWidget {
  final String number;
  final Function(String) onPressed;
  final bool isDark;

  const _KeypadButton(this.number, this.onPressed, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPressed(number),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.lightPrimary.withValues(alpha: 0.8),
                AppTheme.lightPrimary,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.lightPrimary.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

