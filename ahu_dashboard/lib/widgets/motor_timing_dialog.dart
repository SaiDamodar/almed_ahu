import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/motor_timing_storage.dart';

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
  void initState() {
    super.initState();
    _loadTimings();
  }
  
  /// Load motor timings - priority: Local Storage > ESP32 State > Defaults
  Future<void> _loadTimings() async {
    // 1. Try to load from local storage (Raspberry Pi memory)
    final savedTimings = await MotorTimingStorage.loadTimings(widget.ahuId);
    
    if (savedTimings != null) {
      // Use locally saved timings (what user last configured)
      setState(() {
        _m1Start = savedTimings['m1_start']!;
        _m1Post = savedTimings['m1_post']!;
        _m2Interval = savedTimings['m2_wait']!;
        _m2Run = savedTimings['m2_run']!;
        _m2Delay = savedTimings['m2_delay']!;
      });
      print('MotorTimingDialog: Loaded from local storage');
      return;
    }
    
    // 2. Fall back to ESP32 state if no local storage
    if (mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final state = provider.getState(widget.ahuId);
      if (state != null && state.m1Start != null) {
        setState(() {
          _m1Start = state.m1Start ?? 10;
          _m1Post = state.m1Post ?? 10;
          _m2Interval = state.m2WaitTime;
          _m2Run = state.m2Run ?? 10;
          _m2Delay = state.m2Delay ?? 5;
        });
        print('MotorTimingDialog: Loaded from ESP32 state');
        return;
      }
    }
    
    // 3. Use defaults if nothing available
    print('MotorTimingDialog: Using default values');
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
              color: Colors.black.withOpacity( 0.3),
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
                    AppTheme.lightPrimary.withOpacity( 0.8),
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
                            color: Colors.white.withOpacity( 0.9),
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
                      unit: 's',
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
                      unit: 's',
                      color: AppTheme.lightPrimary,
                      onIncrement: () => setState(() => _m1Post = (_m1Post + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m1Post = (_m1Post - 1).clamp(1, 999)),
                      helpText: 'Duration Motor-1 runs during shutdown',
                    ),
                    const SizedBox(height: 16),
                    
                    // M2 Interval (Wait Time)
                    _TimingControl(
                      icon: Icons.refresh_rounded,
                      label: 'Motor-2 Wait Time',
                      value: _m2Interval,
                      unit: 's',
                      color: AppTheme.humidity,
                      onIncrement: () => setState(() => _m2Interval = (_m2Interval + 1).clamp(1, 999)),
                      onDecrement: () => setState(() => _m2Interval = (_m2Interval - 1).clamp(1, 999)),
                      helpText: 'Wait time between Motor-2 cycles',
                    ),
                    const SizedBox(height: 16),
                    
                    // M2 Run
                    _TimingControl(
                      icon: Icons.schedule_rounded,
                      label: 'Motor-2 Run Time',
                      value: _m2Run,
                      unit: 's',
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
                      unit: 's',
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
  
  Future<void> _saveTimings(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // 1. Save to local storage (Raspberry Pi memory) FIRST
    await MotorTimingStorage.saveTimings(
      widget.ahuId,
      m1Start: _m1Start,
      m1Post: _m1Post,
      m2WaitTime: _m2Interval,  // Save wait time
      m2Run: _m2Run,
      m2Delay: _m2Delay,
    );
    
    // 2. Send to ESP32 via MQTT
    // Note: _m2Interval is the WAIT TIME between cycles
    // AppProvider will add run time to calculate actual interval for ESP32
    provider.provisionMotorTimings(
      widget.ahuId,
      m1Start: _m1Start,
      m1Post: _m1Post,
      m2Interval: _m2Interval,  // Wait time (will be converted to actual interval)
      m2Run: _m2Run,
      m2Delay: _m2Delay,
    );
    
    if (context.mounted) {
      Navigator.of(context).pop();
      
      // Show simple success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Motor timings saved! Wait: ${_m2Interval}s, Run: ${_m2Run}s'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  color.withOpacity( 0.15),
                  color.withOpacity( 0.2),
                ]
              : [
                  color.withOpacity( 0.08),
                  color.withOpacity( 0.12),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity( 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity( 0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
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
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity( 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrement button - exactly like temperature control
              IconButton(
                onPressed: value > 1 ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_rounded),
                color: color,
                iconSize: 40,
              ),
              const SizedBox(width: 12),
              
              // Value display
              Text(
                '$value$unit',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              
              // Increment button - exactly like temperature control
              IconButton(
                onPressed: value < 999 ? onIncrement : null,
                icon: const Icon(Icons.add_circle_rounded),
                color: color,
                iconSize: 40,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


