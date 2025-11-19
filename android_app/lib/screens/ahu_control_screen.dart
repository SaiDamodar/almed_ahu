import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'admin_screen.dart';

/// AHU Control Screen - Main control interface
class AhuControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const AhuControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<AhuControlScreen> createState() => _AhuControlScreenState();
}

class _AhuControlScreenState extends State<AhuControlScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context);

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
          child: Column(
            children: [
              // Top bar - Optimized for 393x873
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtils.getPadding(context, 16),
                  vertical: ScreenUtils.getSpacing(context, 12),
                ),
                child: Column(
                  children: [
                    // First row: Back button and title
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                            iconSize: ScreenUtils.getIconSize(context, 24),
                            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 8)),
                          ),
                        ),
                        SizedBox(width: ScreenUtils.getPadding(context, 12)),
                        Expanded(
                          child: Consumer<AppProvider>(
                            builder: (context, provider, child) {
                              final status = provider.getDeviceStatus(widget.deviceId);
                              final isOnline = status?.isOnline ?? false;
                              final isRunning = status?.isRunning ?? false;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.deviceName,
                                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                          fontSize: ScreenUtils.getFontSize(context, 20),
                                          fontWeight: FontWeight.bold,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                                  Wrap(
                                    spacing: ScreenUtils.getPadding(context, 8),
                                    runSpacing: ScreenUtils.getSpacing(context, 4),
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isOnline ? AppTheme.success : AppTheme.error,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: ScreenUtils.getPadding(context, 6)),
                                          Text(
                                            isOnline ? 'Online' : 'Offline',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontSize: ScreenUtils.getFontSize(context, 12),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ScreenUtils.getPadding(context, 10),
                                          vertical: ScreenUtils.getSpacing(context, 4),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isRunning
                                              ? AppTheme.success.withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isRunning ? AppTheme.success : Colors.grey.shade400,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isRunning ? Icons.power_rounded : Icons.power_off_rounded,
                                              size: ScreenUtils.getIconSize(context, 14),
                                              color: isRunning ? AppTheme.success : Colors.grey.shade600,
                                            ),
                                            SizedBox(width: ScreenUtils.getPadding(context, 4)),
                                            Text(
                                              isRunning ? 'RUNNING' : 'STOPPED',
                                              style: TextStyle(
                                                fontSize: ScreenUtils.getFontSize(context, 11),
                                                fontWeight: FontWeight.bold,
                                                color: isRunning ? AppTheme.success : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 12)),
                    // Second row: Action buttons
                    Row(
                      children: [
                        // Start/Stop button
                        Expanded(
                          child: Consumer<AppProvider>(
                            builder: (context, provider, child) {
                              final status = provider.getDeviceStatus(widget.deviceId);
                              final isRunning = status?.isRunning ?? false;
                              final isOnline = status?.isOnline ?? false;

                              return Container(
                                height: ScreenUtils.getButtonHeight(context),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isRunning
                                        ? [AppTheme.error, const Color(0xFFDC2626)]
                                        : [AppTheme.success, const Color(0xFF059669)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isOnline
                                        ? () => provider.toggleAhu(widget.deviceId)
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: ScreenUtils.getIconSize(context, 20),
                                        ),
                                        SizedBox(width: ScreenUtils.getPadding(context, 8)),
                                        Flexible(
                                          child: Text(
                                            isRunning ? 'Stop' : 'Start',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: ScreenUtils.getFontSize(context, 16),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: ScreenUtils.getPadding(context, 12)),
                        // Admin settings button
                        Container(
                          height: ScreenUtils.getButtonHeight(context),
                          width: ScreenUtils.getButtonHeight(context),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AdminScreen(deviceId: widget.deviceId),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Icon(
                                Icons.settings_rounded,
                                size: ScreenUtils.getIconSize(context, 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.getPadding(context, 16),
                    vertical: ScreenUtils.getSpacing(context, 16),
                  ),
                  child: Column(
                    children: [
                      // Temperature & Humidity Controls
                      _SensorControls(deviceId: widget.deviceId),
                      SizedBox(height: ScreenUtils.getSpacing(context, 20)),

                      // Component Status
                      _ComponentStatus(deviceId: widget.deviceId),
                      SizedBox(height: ScreenUtils.getSpacing(context, 20)),
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

class _SensorControls extends StatelessWidget {
  final String deviceId;

  const _SensorControls({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final status = provider.getDeviceStatus(deviceId);
        if (status == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Always use column layout for narrow screens (393px)
        return Column(
          children: [
            _SensorControl(
              icon: Icons.thermostat_rounded,
              label: 'Temperature',
              actual: status.telemetry?.temp?.toStringAsFixed(1) ?? '--',
              setpoint: status.tempSetpoint,
              unit: '°C',
              color: AppTheme.temperature,
              min: 15,
              max: 30,
              onChanged: (value) => provider.setTemperature(deviceId, value),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 16)),
            _SensorControl(
              icon: Icons.water_drop_rounded,
              label: 'Humidity',
              actual: status.telemetry?.hum?.toStringAsFixed(1) ?? '--',
              setpoint: status.humSetpoint,
              unit: '%',
              color: AppTheme.humidity,
              min: 30,
              max: 80,
              onChanged: (value) => provider.setHumidity(deviceId, value),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 20)),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 28)),
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 12)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  ),
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ).createShader(bounds),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actual,
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 40),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: ScreenUtils.getSpacing(context, 8)),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: ScreenUtils.getFontSize(context, 16),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 20)),
                Container(
                  padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SETPOINT',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 10),
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: ScreenUtils.getSpacing(context, 10)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlButton(
                            icon: Icons.remove,
                            color: color,
                            onPressed: setpoint > min ? () => onChanged(setpoint - 0.5) : null,
                          ),
                          SizedBox(width: ScreenUtils.getPadding(context, 16)),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ScreenUtils.getPadding(context, 16),
                                vertical: ScreenUtils.getSpacing(context, 8),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${setpoint.toStringAsFixed(1)}$unit',
                                style: TextStyle(
                                  fontSize: ScreenUtils.getFontSize(context, 18),
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          SizedBox(width: ScreenUtils.getPadding(context, 16)),
                          _ControlButton(
                            icon: Icons.add,
                            color: color,
                            onPressed: setpoint < max ? () => onChanged(setpoint + 0.5) : null,
                          ),
                        ],
                      ),
                    ],
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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final buttonSize = ScreenUtils.getButtonHeight(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: buttonSize,
          height: buttonSize,
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
          ),
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey,
            size: ScreenUtils.getIconSize(context, 20),
          ),
        ),
      ),
    );
  }
}

class _ComponentStatus extends StatelessWidget {
  final String deviceId;

  const _ComponentStatus({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final status = provider.getDeviceStatus(deviceId);
        if (status == null) {
          return const SizedBox.shrink();
        }

        final state = status.state;
        final isOnline = status.isOnline;
        final isRunning = status.isRunning;

        return Container(
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Component Status',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: ScreenUtils.getFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 16)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusIndicator(
                      icon: Icons.water_rounded,
                      label: 'Motor 1',
                      isActive: state?.m1 ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 10)),
                    _StatusIndicator(
                      icon: Icons.cleaning_services_rounded,
                      label: 'Motor 2',
                      isActive: state?.m2 ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 10)),
                    _StatusIndicator(
                      icon: Icons.ac_unit_rounded,
                      label: 'Compressor',
                      isActive: state?.cp ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 10)),
                    _StatusIndicator(
                      icon: Icons.whatshot_rounded,
                      label: 'Heater',
                      isActive: state?.heater ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 10)),
                    GestureDetector(
                      onTap: (isOnline && isRunning)
                          ? () {
                              final currentSpeed = state?.fanSpeed ?? 0;
                              final newSpeed = (currentSpeed + 1) % 4;
                              provider.setFanSpeed(deviceId, newSpeed);
                            }
                          : null,
                      child: _StatusIndicator(
                        icon: Icons.air_rounded,
                        label: state?.fanSpeedDisplay ?? 'Fan',
                        isActive: state?.fan ?? false,
                        color: AppTheme.success,
                        isClickable: isOnline && isRunning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

    return Container(
      width: 100,
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? color.withOpacity(0.5) : Theme.of(context).dividerColor.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 8)),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? color : (isDark ? Colors.white.withOpacity(0.4) : Colors.black54),
              size: ScreenUtils.getIconSize(context, 20),
            ),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 6)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 9),
              fontWeight: FontWeight.w700,
              color: isActive ? color : (isDark ? Colors.white.withOpacity(0.7) : Colors.black87),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 4)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ScreenUtils.getPadding(context, 6),
              vertical: ScreenUtils.getSpacing(context, 2),
            ),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isActive ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 8),
                fontWeight: FontWeight.bold,
                color: isActive ? color : Colors.grey.shade600,
              ),
            ),
          ),
          if (isClickable) ...[
            SizedBox(height: ScreenUtils.getSpacing(context, 4)),
            Icon(
              Icons.touch_app,
              size: ScreenUtils.getIconSize(context, 12),
              color: AppTheme.info.withOpacity(0.6),
            ),
          ],
        ],
      ),
    );
  }
}

