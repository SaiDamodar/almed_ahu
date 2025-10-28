import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Motor timing adjustment dialog - similar to temperature/humidity controls
class MotorTimingDialog extends StatefulWidget {
  final String ahuId;
  final String motorLabel;

  const MotorTimingDialog({
    super.key,
    required this.ahuId,
    required this.motorLabel,
  });

  @override
  State<MotorTimingDialog> createState() => _MotorTimingDialogState();
}

class _MotorTimingDialogState extends State<MotorTimingDialog> {
  int _m1Start = 10;
  int _m1Post = 10;
  int _m2Interval = 30;
  int _m2Run = 10;
  int _m2Delay = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightPrimary,
                    AppTheme.lightPrimary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Motor Timing Configuration',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.motorLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // M1 Start
                    _TimingControl(
                      icon: Icons.play_circle_rounded,
                      label: 'Motor-1 Start Run',
                      value: _m1Start,
                      unit: 'seconds',
                      color: AppTheme.lightPrimary,
                      onIncrement: () => setState(() => _m1Start = (_m1Start + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m1Start = (_m1Start - 1).clamp(1, 999)),
                      helpText: 'Duration Motor-1 runs after system starts',
                    ),
                    const SizedBox(height: 16),
                    
                    // M1 Post
                    _TimingControl(
                      icon: Icons.stop_circle_rounded,
                      label: 'Motor-1 Post Run',
                      value: _m1Post,
                      unit: 'seconds',
                      color: AppTheme.lightPrimary,
                      onIncrement: () => setState(() => _m1Post = (_m1Post + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m1Post = (_m1Post - 1).clamp(1, 999)),
                      helpText: 'Duration Motor-1 runs during shutdown',
                    ),
                    const SizedBox(height: 16),
                    
                    // M2 Interval
                    _TimingControl(
                      icon: Icons.refresh_rounded,
                      label: 'Motor-2 Interval',
                      value: _m2Interval,
                      unit: 'seconds',
                      color: AppTheme.humidity,
                      onIncrement: () => setState(() => _m2Interval = (_m2Interval + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m2Interval = (_m2Interval - 1).clamp(1, 999)),
                      helpText: 'Time between Motor-2 clean cycles',
                    ),
                    const SizedBox(height: 16),
                    
                    // M2 Run
                    _TimingControl(
                      icon: Icons.schedule_rounded,
                      label: 'Motor-2 Run Time',
                      value: _m2Run,
                      unit: 'seconds',
                      color: AppTheme.humidity,
                      onIncrement: () => setState(() => _m2Run = (_m2Run + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m2Run = (_m2Run - 1).clamp(1, 999)),
                      helpText: 'Duration Motor-2 runs each cycle',
                    ),
                    const SizedBox(height: 16),
                    
                    // M2 Delay
                    _TimingControl(
                      icon: Icons.hourglass_empty_rounded,
                      label: 'Motor-2 Delay',
                      value: _m2Delay,
                      unit: 'seconds',
                      color: AppTheme.info,
                      onIncrement: () => setState(() => _m2Delay = (_m2Delay + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m2Delay = (_m2Delay - 1).clamp(1, 999)),
                      helpText: 'Delay after Motor-1 stops',
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _m1Start = 10;
                          _m1Post = 10;
                          _m2Interval = 30;
                          _m2Run = 10;
                          _m2Delay = 5;
                        });
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.lightPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveTimings(context),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Timings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _saveTimings(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.provisionMotorTimings(
      widget.ahuId,
      m1Start: _m1Start,
      m1Post: _m1Post,
      m2Interval: _m2Interval,
      m2Run: _m2Run,
      m2Delay: _m2Delay,
    );
    
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Motor timings saved! M1: ${_m1Start}s, M2: ${_m2Run}s'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Individual timing control widget (like temperature control)
class _TimingControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String unit;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final String helpText;

  const _TimingControl({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
    required this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            helpText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Decrement button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDecrement,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.8),
                          color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              
              // Value display
              Column(
                children: [
                  Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              
              // Increment button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onIncrement,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.8),
                          color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

