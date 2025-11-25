import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../models/ahu_telemetry.dart';
import '../models/ahu_state.dart';
import '../models/ahu_log.dart';
import '../widgets/motor_timing_dialog.dart';

/// Modern AHU control screen
class AhuControlScreen extends StatefulWidget {
  final String ahuId;

  const AhuControlScreen({super.key, required this.ahuId});

  @override
  State<AhuControlScreen> createState() => _AhuControlScreenState();
}

class _AhuControlScreenState extends State<AhuControlScreen> {
  bool _showLogs = false;

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
                ? const [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF334155),
                  ]
                : [Colors.white, Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              _TopBar(ahuId: widget.ahuId, isDark: isDark),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Temperature & Humidity
                      _SensorControls(ahuId: widget.ahuId),
                      const SizedBox(height: 20),
                      // Component Status
                      _ComponentStatus(ahuId: widget.ahuId),
                      const SizedBox(height: 20),
                      // Logs (collapsible) - ADMIN ONLY
                      _LogsWrapper(
                        ahuId: widget.ahuId,
                        isExpanded: _showLogs,
                        onToggle: () => setState(() => _showLogs = !_showLogs),
                      ),
                    ],
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

class _TopBar extends StatelessWidget {
  final String ahuId;
  final bool isDark;
  
  const _TopBar({required this.ahuId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // ALMED Branding
          Text(
            'ALMED',
            style: TextStyle(
              fontFamily: 'Verdana',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 24,
            color: theme.dividerColor.withOpacity(0.3),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _AhuInfo(ahuId: ahuId)),
          // Start/Stop toggle
          _StartStopButton(ahuId: ahuId),
        ],
      ),
    );
  }
}

class _AhuInfo extends StatelessWidget {
  final String ahuId;
  
  const _AhuInfo({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Selector<AppProvider, ({String name, bool isOnline, bool isRunning})>(
      selector: (_, provider) {
        final ahu = provider.ahuUnits.firstWhere((a) => a.id == ahuId);
        final status = provider.getStatus(ahuId);
        final state = provider.getState(ahuId);
        return (
          name: ahu.name,
          isOnline: status == 'online',
          isRunning: state?.run ?? false,
        );
      },
      builder: (context, data, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.name,
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
            ),
            Row(
              children: [
                // Connection Status
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: data.isOnline ? AppTheme.success : AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  data.isOnline ? 'Online' : 'Offline',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                // System Running Status
                _RunningBadge(isRunning: data.isRunning),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RunningBadge extends StatelessWidget {
  final bool isRunning;
  
  const _RunningBadge({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? const Color(0xFF10B981) : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRunning ? color : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRunning ? Icons.power_rounded : Icons.power_off_rounded,
            size: 14,
            color: isRunning ? color : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            isRunning ? 'RUNNING' : 'STOPPED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isRunning ? color : Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  final String ahuId;
  
  const _StartStopButton({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, provider) => provider.getState(ahuId)?.run ?? false,
      builder: (context, isRunning, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isRunning
                  ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                  : const [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.read<AppProvider>().toggleAhu(ahuId);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning ? 'Stop' : 'Start',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Data class for sensor controls
@immutable
class _SensorData {
  final AhuTelemetry? telemetry;
  final AhuState? state;

  const _SensorData({required this.telemetry, required this.state});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SensorData &&
          runtimeType == other.runtimeType &&
          telemetry == other.telemetry &&
          state == other.state;

  @override
  int get hashCode => Object.hash(telemetry, state);
}

class _SensorControls extends StatelessWidget {
  final String ahuId;

  const _SensorControls({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _SensorData>(
      selector: (_, provider) => _SensorData(
        telemetry: provider.getTelemetry(ahuId),
        state: provider.getState(ahuId),
      ),
      builder: (context, data, _) {
        return Row(
          children: [
            // Temperature
            Expanded(
              child: _SensorControl(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                actual: data.telemetry?.temp?.toStringAsFixed(1) ?? '--',
                setpoint: data.state?.tempSet ?? 22.0,
                unit: '°C',
                color: AppTheme.temperature,
                min: 15,
                max: 30,
                onChanged: (value) {
                  context.read<AppProvider>().setTemperature(ahuId, value);
                },
              ),
            ),
            const SizedBox(width: 16),
            // Humidity
            Expanded(
              child: _SensorControl(
                icon: Icons.water_drop_rounded,
                label: 'Humidity',
                actual: data.telemetry?.hum?.toStringAsFixed(1) ?? '--',
                setpoint: data.state?.humSet ?? 55.0,
                unit: '%',
                color: AppTheme.humidity,
                min: 30,
                max: 80,
                onChanged: (value) {
                  context.read<AppProvider>().setHumidity(ahuId, value);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SensorControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final String actual;
  final double setpoint;
  final String unit;
  final Color color;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SensorControl({
    required this.icon,
    required this.label,
    required this.actual,
    required this.setpoint,
    required this.unit,
    required this.color,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withOpacity(0.15), color.withOpacity(0.08)]
              : [Colors.white, color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Icon with glow effect
                _GlowingIcon(icon: icon, color: color),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Large actual value
                _ActualValue(value: actual, unit: unit, color: color),
                const SizedBox(height: 6),
                _Badge(text: 'ACTUAL', color: color),
                const SizedBox(height: 20),
                // Setpoint controls
                _SetpointControls(
                  setpoint: setpoint,
                  unit: unit,
                  color: color,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  
  const _GlowingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _ActualValue extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;
  
  const _ActualValue({
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [color, color.withOpacity(0.7)],
      ).createShader(bounds),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              unit,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SetpointControls extends StatelessWidget {
  final double setpoint;
  final String unit;
  final Color color;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  
  const _SetpointControls({
    required this.setpoint,
    required this.unit,
    required this.color,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'SETPOINT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GlossyButton(
                icon: Icons.remove,
                color: color,
                onPressed: setpoint > min ? () => onChanged(setpoint - 0.5) : null,
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.2), blurRadius: 8),
                  ],
                ),
                child: Text(
                  '${setpoint.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _GlossyButton(
                icon: Icons.add,
                color: color,
                onPressed: setpoint < max ? () => onChanged(setpoint + 0.5) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlossyButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _GlossyButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
                  )
                : null,
            color: isEnabled ? null : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Data class for component status
@immutable
class _ComponentData {
  final AhuState? state;

  const _ComponentData({required this.state});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ComponentData &&
          runtimeType == other.runtimeType &&
          state == other.state;

  @override
  int get hashCode => state.hashCode;
}

class _ComponentStatus extends StatelessWidget {
  final String ahuId;

  const _ComponentStatus({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Selector<AppProvider, _ComponentData>(
      selector: (_, provider) => _ComponentData(state: provider.getState(ahuId)),
      builder: (context, data, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]
                  : [Colors.white, Colors.grey.shade50],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _ComponentHeader(isDark: isDark),
              const SizedBox(height: 20),
              _ComponentIndicators(ahuId: ahuId, data: data),
            ],
          ),
        );
      },
    );
  }
}

class _ComponentHeader extends StatelessWidget {
  final bool isDark;
  
  const _ComponentHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.info.withOpacity(0.2), AppTheme.info.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.dashboard_rounded, size: 20, color: AppTheme.info),
        ),
        const SizedBox(width: 12),
        Text(
          'Component Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ComponentIndicators extends StatelessWidget {
  final String ahuId;
  final _ComponentData data;
  
  const _ComponentIndicators({required this.ahuId, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MotorIndicator(
            ahuId: ahuId,
            icon: Icons.water_rounded,
            label: 'Motor 1 (Drain)',
            isActive: data.state?.m1 ?? false,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 12),
          _MotorIndicator(
            ahuId: ahuId,
            icon: Icons.cleaning_services_rounded,
            label: 'Motor 2 (Filter)',
            isActive: data.state?.m2 ?? false,
            color: const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 12),
          _StatusIndicator(
            icon: Icons.ac_unit_rounded,
            label: 'Compressor',
            isActive: data.state?.cp ?? false,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          _StatusIndicator(
            icon: Icons.whatshot_rounded,
            label: 'Heater',
            isActive: data.state?.heater ?? false,
            color: const Color(0xFF1E40AF),
          ),
          const SizedBox(width: 12),
          _FanIndicator(ahuId: ahuId, data: data),
        ],
      ),
    );
  }
}

class _MotorIndicator extends StatelessWidget {
  final String ahuId;
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  
  const _MotorIndicator({
    required this.ahuId,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, provider) => provider.currentRole == UserRole.admin,
      builder: (context, isAdmin, _) {
        return GestureDetector(
          onTap: isAdmin
              ? () => showDialog(
                  context: context,
                  builder: (context) => MotorTimingDialog(
                    ahuId: ahuId,
                    motorLabel: 'Motor 1 & 2 Timing',
                  ),
                )
              : null,
          child: _StatusIndicator(
            icon: icon,
            label: label,
            isActive: isActive,
            color: color,
            isClickable: isAdmin,
          ),
        );
      },
    );
  }
}

class _FanIndicator extends StatelessWidget {
  final String ahuId;
  final _ComponentData data;
  
  const _FanIndicator({required this.ahuId, required this.data});

  String _getFanLabel(int? fanSpeed) {
    switch (fanSpeed ?? 0) {
      case 0: return 'Fan (OFF)';
      case 1: return 'Fan (LOW)';
      case 2: return 'Fan (MID)';
      case 3: return 'Fan (HIGH)';
      default: return 'Fan (OFF)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, ({bool isOnline, bool isRunning})>(
      selector: (_, provider) => (
        isOnline: provider.getStatus(ahuId) == 'online',
        isRunning: data.state?.run ?? false,
      ),
      builder: (context, info, _) {
        final canToggle = info.isOnline && info.isRunning;
        return GestureDetector(
          onTap: canToggle ? () => context.read<AppProvider>().toggleFanSpeed(ahuId) : null,
          child: _StatusIndicator(
            icon: Icons.air_rounded,
            label: _getFanLabel(data.state?.fanSpeed),
            isActive: data.state?.fan ?? false,
            color: const Color(0xFF10B981),
            isClickable: canToggle,
          ),
        );
      },
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final bool isClickable;

  const _StatusIndicator({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.25), color.withOpacity(0.15)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]
                      : [Colors.white.withOpacity(0.9), Colors.grey.shade50],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.5)
                : Theme.of(context).dividerColor.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IndicatorIcon(icon: icon, isActive: isActive, color: color, isDark: isDark),
                  const SizedBox(height: 8),
                  _IndicatorLabel(label: label, isActive: isActive, color: color, isDark: isDark),
                  const SizedBox(height: 6),
                  _IndicatorBadge(isActive: isActive, color: color),
                  if (isClickable) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.touch_app, size: 10, color: AppTheme.info.withOpacity(0.6)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndicatorIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final bool isDark;
  
  const _IndicatorIcon({
    required this.icon,
    required this.isActive,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : Colors.transparent,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]
            : null,
      ),
      child: Icon(
        icon,
        color: isActive ? color : (isDark ? Colors.white.withOpacity(0.4) : Colors.black54),
        size: 22,
      ),
    );
  }
}

class _IndicatorLabel extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final bool isDark;
  
  const _IndicatorLabel({
    required this.label,
    required this.isActive,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: isActive ? color : (isDark ? Colors.white.withOpacity(0.7) : Colors.black87),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _IndicatorBadge extends StatelessWidget {
  final bool isActive;
  final Color color;
  
  const _IndicatorBadge({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Text(
        isActive ? 'ON' : 'OFF',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isActive ? color : Colors.grey.shade600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _LogsWrapper extends StatelessWidget {
  final String ahuId;
  final bool isExpanded;
  final VoidCallback onToggle;
  
  const _LogsWrapper({
    required this.ahuId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, provider) => provider.currentRole == UserRole.admin,
      builder: (context, isAdmin, _) {
        if (!isAdmin) return const SizedBox.shrink();
        
        return Column(
          children: [
            _LogsSection(
              ahuId: ahuId,
              isExpanded: isExpanded,
              onToggle: onToggle,
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _LogsSection extends StatelessWidget {
  final String ahuId;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _LogsSection({
    required this.ahuId,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.article_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'System Logs',
                        style: theme.textTheme.displayMedium?.copyWith(fontSize: 18),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) _LogsList(ahuId: ahuId),
        ],
      ),
    );
  }
}

class _LogsList extends StatelessWidget {
  final String ahuId;
  
  const _LogsList({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<AhuLog>>(
      selector: (_, provider) => provider.getLogs(ahuId),
      builder: (context, logs, _) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    'No logs available',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[logs.length - 1 - index];
                    return _LogItem(log: log);
                  },
                ),
        );
      },
    );
  }
}

class _LogItem extends StatelessWidget {
  final AhuLog log;
  
  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            log.lvl == 'ERROR'
                ? Icons.error_rounded
                : log.lvl == 'WARN'
                    ? Icons.warning_rounded
                    : Icons.info_rounded,
            size: 16,
            color: log.lvl == 'ERROR'
                ? AppTheme.error
                : AppTheme.info,
          ),
          const SizedBox(width: 8),
          Text(
            log.formattedTime,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.msg,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
