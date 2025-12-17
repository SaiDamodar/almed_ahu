import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';
import '../models/ahu_telemetry.dart';
import '../utils/screen_utils.dart';
import 'admin_screen.dart';

/// AHU Control Screen - Main control interface
class AhuControlScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const AhuControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

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
          child: Column(
            children: [
              _TopBar(deviceId: deviceId, deviceName: deviceName),
              Expanded(
                child: SingleChildScrollView(
                  padding: ScreenUtils.getScreenPadding(context),
                  child: Column(
                    children: [
                      _SensorControls(deviceId: deviceId),
                      SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                      // Combo sensor sections (PM readings + HEPA)
                      _ComboSensorSection(deviceId: deviceId),
                      _ComponentStatus(deviceId: deviceId),
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

class _TopBar extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const _TopBar({required this.deviceId, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getHorizontalPadding(context),
        vertical: ScreenUtils.getSpacing(context, 10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _BackButton(),
              SizedBox(width: ScreenUtils.getPadding(context, 10)),
              Expanded(child: _DeviceInfo(deviceId: deviceId, deviceName: deviceName)),
            ],
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 10)),
          _ActionRow(deviceId: deviceId),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
        iconSize: ScreenUtils.getIconSize(context, 22),
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 8)),
        constraints: const BoxConstraints(),
      ),
    );
  }
}

class _DeviceInfo extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const _DeviceInfo({required this.deviceId, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _DeviceInfoData>(
      selector: (_, provider) {
        final status = provider.getDeviceStatus(deviceId);
        return _DeviceInfoData(
          isOnline: status?.isOnline ?? false,
          isRunning: status?.isRunning ?? false,
        );
      },
      builder: (context, data, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 18),
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
                _OnlineIndicator(isOnline: data.isOnline),
                _RunningBadge(isRunning: data.isRunning),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DeviceInfoData {
  final bool isOnline;
  final bool isRunning;

  _DeviceInfoData({required this.isOnline, required this.isRunning});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DeviceInfoData &&
          isOnline == other.isOnline &&
          isRunning == other.isRunning;

  @override
  int get hashCode => isOnline.hashCode ^ isRunning.hashCode;
}

class _OnlineIndicator extends StatelessWidget {
  final bool isOnline;

  const _OnlineIndicator({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Row(
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
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RunningBadge extends StatelessWidget {
  final bool isRunning;

  const _RunningBadge({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? AppTheme.success : Colors.grey.shade600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 10),
        vertical: ScreenUtils.getSpacing(context, 4),
      ),
      decoration: BoxDecoration(
        color: (isRunning ? AppTheme.success : Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 8)),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRunning ? Icons.power_rounded : Icons.power_off_rounded,
            size: ScreenUtils.getIconSize(context, 14),
            color: color,
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 4)),
          Text(
            isRunning ? 'RUNNING' : 'STOPPED',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 10),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String deviceId;

  const _ActionRow({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, provider) => provider.isAdmin,
      builder: (context, isAdmin, child) {
        return Row(
          children: [
            Expanded(child: _StartStopButton(deviceId: deviceId)),
            if (isAdmin) ...[
              SizedBox(width: ScreenUtils.getPadding(context, 10)),
              _SettingsButton(deviceId: deviceId),
            ],
          ],
        );
      },
    );
  }
}

class _StartStopButton extends StatelessWidget {
  final String deviceId;

  const _StartStopButton({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ScreenUtils.getButtonHeight(context);

    return Selector<AppProvider, _StartStopData>(
      selector: (_, provider) {
        final status = provider.getDeviceStatus(deviceId);
        return _StartStopData(
          isRunning: status?.isRunning ?? false,
          isOnline: status?.isOnline ?? false,
          isPending: provider.isCommandPending(deviceId, 'toggle'),
        );
      },
      builder: (context, data, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: buttonHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: data.isRunning
                  ? [AppTheme.error, const Color(0xFFDC2626)]
                  : [AppTheme.success, const Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
            boxShadow: data.isPending
                ? [
                    BoxShadow(
                      color: (data.isRunning ? AppTheme.error : AppTheme.success).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (data.isOnline && !data.isPending)
                  ? () => context.read<AppProvider>().toggleAhu(deviceId)
                  : null,
              borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (data.isPending)
                    SizedBox(
                      width: ScreenUtils.getIconSize(context, 18),
                      height: ScreenUtils.getIconSize(context, 18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      data.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: ScreenUtils.getIconSize(context, 20),
                    ),
                  SizedBox(width: ScreenUtils.getPadding(context, 8)),
                  Text(
                    data.isPending
                        ? (data.isRunning ? 'Starting...' : 'Stopping...')
                        : (data.isRunning ? 'Stop' : 'Start'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: ScreenUtils.getFontSize(context, 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartStopData {
  final bool isRunning;
  final bool isOnline;
  final bool isPending;

  _StartStopData({required this.isRunning, required this.isOnline, required this.isPending});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StartStopData &&
          isRunning == other.isRunning &&
          isOnline == other.isOnline &&
          isPending == other.isPending;

  @override
  int get hashCode => isRunning.hashCode ^ isOnline.hashCode ^ isPending.hashCode;
}

class _SettingsButton extends StatelessWidget {
  final String deviceId;

  const _SettingsButton({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ScreenUtils.getButtonHeight(context);

    return Container(
      height: buttonHeight,
      width: buttonHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
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
                builder: (context) => AdminScreen(deviceId: deviceId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
          child: Icon(
            Icons.settings_rounded,
            size: ScreenUtils.getIconSize(context, 20),
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
    return Selector<AppProvider, DeviceStatus?>(
      selector: (_, provider) => provider.getDeviceStatus(deviceId),
      builder: (context, status, child) {
        if (status == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _SmoothSensorControl(
              key: ValueKey('temp_$deviceId'),
              deviceId: deviceId,
              icon: Icons.thermostat_rounded,
              label: 'Temperature',
              actual: status.telemetry?.temp?.toStringAsFixed(1) ?? '--',
              initialSetpoint: status.tempSetpoint,
              unit: '°C',
              color: AppTheme.temperature,
              min: 15,
              max: 30,
              onChanged: (value) {
                context.read<AppProvider>().setTemperature(deviceId, value);
              },
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 14)),
            _SmoothSensorControl(
              key: ValueKey('hum_$deviceId'),
              deviceId: deviceId,
              icon: Icons.water_drop_rounded,
              label: 'Humidity',
              actual: status.telemetry?.hum?.toStringAsFixed(1) ?? '--',
              initialSetpoint: status.humSetpoint,
              unit: '%',
              color: AppTheme.humidity,
              min: 30,
              max: 80,
              onChanged: (value) {
                context.read<AppProvider>().setHumidity(deviceId, value);
              },
            ),
          ],
        );
      },
    );
  }
}

/// Smooth sensor control with local state for instant UI updates
class _SmoothSensorControl extends StatefulWidget {
  final String deviceId;
  final IconData icon;
  final String label;
  final String actual;
  final double initialSetpoint;
  final String unit;
  final Color color;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SmoothSensorControl({
    super.key,
    required this.deviceId,
    required this.icon,
    required this.label,
    required this.actual,
    required this.initialSetpoint,
    required this.unit,
    required this.color,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_SmoothSensorControl> createState() => _SmoothSensorControlState();
}

class _SmoothSensorControlState extends State<_SmoothSensorControl> {
  late double _localSetpoint;
  Timer? _debounceTimer;
  bool _isUserEditing = false;

  @override
  void initState() {
    super.initState();
    _localSetpoint = widget.initialSetpoint;
  }

  @override
  void didUpdateWidget(_SmoothSensorControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from provider if user is not actively editing
    if (!_isUserEditing && widget.initialSetpoint != oldWidget.initialSetpoint) {
      _localSetpoint = widget.initialSetpoint;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _updateSetpoint(double newValue) {
    if (newValue < widget.min || newValue > widget.max) return;
    
    setState(() {
      _localSetpoint = newValue;
      _isUserEditing = true;
    });

    // Debounce API call - wait 300ms after last tap
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(_localSetpoint);
      // Reset editing state after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isUserEditing = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = ScreenUtils.getBorderRadius(context, 18);
    final padding = ScreenUtils.getPadding(context, 18);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [widget.color.withOpacity(0.15), widget.color.withOpacity(0.08)]
              : [Colors.white, widget.color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: widget.color.withOpacity(0.3), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                _SensorHeader(icon: widget.icon, label: widget.label, color: widget.color),
                SizedBox(height: ScreenUtils.getSpacing(context, 14)),
                _ActualValue(actual: widget.actual, unit: widget.unit, color: widget.color),
                SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                _SmoothSetpointControls(
                  setpoint: _localSetpoint,
                  unit: widget.unit,
                  color: widget.color,
                  min: widget.min,
                  max: widget.max,
                  onIncrement: () => _updateSetpoint(_localSetpoint + 0.5),
                  onDecrement: () => _updateSetpoint(_localSetpoint - 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SensorHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SensorHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 24)),
        ),
        SizedBox(width: ScreenUtils.getPadding(context, 10)),
        Text(
          label,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 15),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ActualValue extends StatelessWidget {
  final String actual;
  final String unit;
  final Color color;

  const _ActualValue({
    required this.actual,
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
            actual,
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 36),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: ScreenUtils.getSpacing(context, 6)),
            child: Text(
              unit,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
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

/// Smooth setpoint controls with instant feedback
class _SmoothSetpointControls extends StatelessWidget {
  final double setpoint;
  final String unit;
  final Color color;
  final double min;
  final double max;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _SmoothSetpointControls({
    required this.setpoint,
    required this.unit,
    required this.color,
    required this.min,
    required this.max,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
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
                onPressed: setpoint > min ? onDecrement : null,
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 14)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtils.getPadding(context, 14),
                  vertical: ScreenUtils.getSpacing(context, 8),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: Text(
                    '${setpoint.toStringAsFixed(1)}$unit',
                    key: ValueKey(setpoint),
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 14)),
              _ControlButton(
                icon: Icons.add,
                color: color,
                onPressed: setpoint < max ? onIncrement : null,
              ),
            ],
          ),
        ],
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
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
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
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
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
    final borderRadius = ScreenUtils.getBorderRadius(context, 18);

    return Selector<AppProvider, _ComponentStatusData>(
      selector: (_, provider) {
        final status = provider.getDeviceStatus(deviceId);
        return _ComponentStatusData(
          status: status,
          isFanPending: provider.isCommandPending(deviceId, 'fan'),
        );
      },
      builder: (context, data, child) {
        if (data.status == null) return const SizedBox.shrink();

        final state = data.status!.state;
        final isOnline = data.status!.isOnline;
        final isRunning = data.status!.isRunning;

        return Container(
          padding: ScreenUtils.getCardPadding(context),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Component Status',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 15),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 14)),
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
                    SizedBox(width: ScreenUtils.getPadding(context, 8)),
                    _StatusIndicator(
                      icon: Icons.cleaning_services_rounded,
                      label: 'Motor 2',
                      isActive: state?.m2 ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 8)),
                    _StatusIndicator(
                      icon: Icons.ac_unit_rounded,
                      label: 'Compressor',
                      isActive: state?.cp ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 8)),
                    _StatusIndicator(
                      icon: Icons.whatshot_rounded,
                      label: 'Heater',
                      isActive: state?.heater ?? false,
                      color: AppTheme.info,
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 8)),
                    GestureDetector(
                      onTap: (isOnline && isRunning && !data.isFanPending)
                          ? () {
                              final currentSpeed = state?.fanSpeed ?? 0;
                              final newSpeed = (currentSpeed + 1) % 4;
                              context.read<AppProvider>().setFanSpeed(deviceId, newSpeed);
                            }
                          : null,
                      child: _StatusIndicator(
                        icon: Icons.air_rounded,
                        label: state?.fanSpeedDisplay ?? 'Fan',
                        isActive: state?.fan ?? false,
                        color: AppTheme.success,
                        isClickable: isOnline && isRunning,
                        isPending: data.isFanPending,
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

class _ComponentStatusData {
  final DeviceStatus? status;
  final bool isFanPending;

  _ComponentStatusData({required this.status, required this.isFanPending});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ComponentStatusData &&
          status == other.status &&
          isFanPending == other.isFanPending;

  @override
  int get hashCode => status.hashCode ^ isFanPending.hashCode;
}

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final bool isClickable;
  final bool isPending;

  const _StatusIndicator({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    this.isClickable = false,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = ScreenUtils.getPadding(context, 90);
    final borderRadius = ScreenUtils.getBorderRadius(context, 12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
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
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isActive ? color.withOpacity(0.5) : Theme.of(context).dividerColor.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isPending
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
            child: isPending
                ? SizedBox(
                    width: ScreenUtils.getIconSize(context, 18),
                    height: ScreenUtils.getIconSize(context, 18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    icon,
                    color: isActive ? color : (isDark ? Colors.white.withOpacity(0.4) : Colors.black54),
                    size: ScreenUtils.getIconSize(context, 18),
                  ),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 6)),
          Text(
            isPending ? 'Changing...' : label,
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
              borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 6)),
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
          if (isClickable && !isPending) ...[
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

// ============ COMBO SENSOR SECTION (SEN66 + SDP810) ============

class _ComboSensorSection extends StatelessWidget {
  final String deviceId;

  const _ComboSensorSection({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, AhuTelemetry?>(
      selector: (_, provider) => provider.getDeviceStatus(deviceId)?.telemetry,
      builder: (context, telemetry, _) {
        if (telemetry == null || !telemetry.isComboSensor) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // Air Quality / PM Readings
            if (telemetry.hasAirQualityData) ...[
              _AirQualityCard(telemetry: telemetry),
              SizedBox(height: ScreenUtils.getSpacing(context, 14)),
            ],
            // HEPA Filter Status
            if (telemetry.hasHepaData) ...[
              _HepaStatusCard(telemetry: telemetry),
              SizedBox(height: ScreenUtils.getSpacing(context, 14)),
            ],
          ],
        );
      },
    );
  }
}

/// Air Quality Card - uses only theme colors (blue/black or blue/white)
class _AirQualityCard extends StatelessWidget {
  final AhuTelemetry telemetry;

  const _AirQualityCard({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final borderRadius = ScreenUtils.getBorderRadius(context, 18);
    final padding = ScreenUtils.getPadding(context, 16);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Icon(Icons.air_rounded, color: primaryColor, size: 20),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                Text(
                  'Air Quality',
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 14),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                // AQI Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.getPadding(context, 10),
                    vertical: ScreenUtils.getSpacing(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'AQI ${telemetry.aqi ?? '--'}',
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 12),
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // PM Values Grid
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Row(
              children: [
                _PmValueBox(label: 'PM1.0', value: telemetry.pm1p0, isPrimary: false),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _PmValueBox(label: 'PM2.5', value: telemetry.pm2p5, isPrimary: true),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _PmValueBox(label: 'PM4.0', value: telemetry.pm4p0, isPrimary: false),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _PmValueBox(label: 'PM10', value: telemetry.pm10p0, isPrimary: false),
              ],
            ),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 12)),
          // VOC, NOx, CO2 Row
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: Row(
              children: [
                _GasValueBox(label: 'VOC', value: telemetry.voc, unit: 'index'),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _GasValueBox(label: 'NOx', value: telemetry.nox, unit: 'index'),
                SizedBox(width: ScreenUtils.getPadding(context, 8)),
                _GasValueBox(label: 'CO₂', value: telemetry.co2, unit: 'ppm'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PmValueBox extends StatelessWidget {
  final String label;
  final double? value;
  final bool isPrimary;

  const _PmValueBox({
    required this.label,
    required this.value,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ScreenUtils.getSpacing(context, 10),
          horizontal: ScreenUtils.getPadding(context, 6),
        ),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(isPrimary ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
          border: isPrimary
              ? Border.all(color: primaryColor.withOpacity(0.4), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 10),
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 4)),
            Text(
              value != null ? value!.round().toString() : '--',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, isPrimary ? 20 : 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'µg/m³',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 8),
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GasValueBox extends StatelessWidget {
  final String label;
  final int? value;
  final String unit;

  const _GasValueBox({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ScreenUtils.getSpacing(context, 10),
          horizontal: ScreenUtils.getPadding(context, 8),
        ),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 10),
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 2)),
            Text(
              value != null ? value.toString() : '--',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 8),
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HEPA Status Card - uses red/yellow/green for status
class _HepaStatusCard extends StatelessWidget {
  final AhuTelemetry telemetry;

  const _HepaStatusCard({required this.telemetry});

  Color _getHepaColor() {
    final status = telemetry.hepaStatus ?? '';
    if (status.contains('Normal')) return const Color(0xFF4CAF50); // Green
    if (status.contains('Clogging')) return const Color(0xFFFF9800); // Yellow/Orange
    return const Color(0xFFF44336); // Red
  }

  IconData _getHepaIcon() {
    final status = telemetry.hepaStatus ?? '';
    if (status.contains('Normal')) return Icons.check_circle_rounded;
    if (status.contains('Clogging')) return Icons.warning_rounded;
    return Icons.error_rounded;
  }

  String _getStatusText() {
    final status = telemetry.hepaStatus ?? 'Unknown';
    if (status.contains('Normal')) return 'Normal';
    if (status.contains('Clogging')) return 'Clogging';
    if (status.contains('Replace')) return 'Replace!';
    if (status.contains('Weak') || status.contains('Leak')) return 'Weak Airflow';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hepaColor = _getHepaColor();
    final health = telemetry.hepaHealth ?? 0;
    final pressure = telemetry.diffPressure;
    final borderRadius = ScreenUtils.getBorderRadius(context, 16);
    final padding = ScreenUtils.getPadding(context, 16);

    return GestureDetector(
      onTap: () => _showHepaDetails(context),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: hepaColor.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            // HEPA Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [hepaColor, hepaColor.withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(color: hepaColor.withOpacity(0.3), blurRadius: 8),
                ],
              ),
              child: Icon(_getHepaIcon(), color: Colors.white, size: 26),
            ),
            SizedBox(width: ScreenUtils.getPadding(context, 14)),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'HEPA Filter',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 14),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(width: ScreenUtils.getPadding(context, 8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ScreenUtils.getPadding(context, 8),
                          vertical: ScreenUtils.getSpacing(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: hepaColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: ScreenUtils.getFontSize(context, 10),
                            fontWeight: FontWeight.bold,
                            color: hepaColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 8)),
                  // Health bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: health / 100,
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(hepaColor),
                          ),
                        ),
                      ),
                      SizedBox(width: ScreenUtils.getPadding(context, 10)),
                      Text(
                        '$health%',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 14),
                          fontWeight: FontWeight.bold,
                          color: hepaColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                  Text(
                    'ΔP: ${pressure?.toStringAsFixed(1) ?? '--'} Pa',
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 11),
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: hepaColor.withOpacity(0.6),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showHepaDetails(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hepaColor = _getHepaColor();
    final health = telemetry.hepaHealth ?? 0;
    final pressure = telemetry.diffPressure;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'HEPA Filter Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            // Large icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [hepaColor, hepaColor.withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(color: hepaColor.withOpacity(0.4), blurRadius: 16),
                ],
              ),
              child: Icon(_getHepaIcon(), color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hepaColor,
              ),
            ),
            const SizedBox(height: 24),
            // Health bar
            Text(
              'Filter Health',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: health / 100,
                minHeight: 12,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(hepaColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$health%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: hepaColor,
              ),
            ),
            const SizedBox(height: 24),
            // Details
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Differential Pressure',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pressure?.toStringAsFixed(1) ?? '--'} Pa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Normal Range',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '9-25 Pa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Legend
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS LEGEND',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.black54,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LegendItem(color: const Color(0xFFF44336), text: 'Weak Airflow: < 9 Pa'),
                  const SizedBox(height: 8),
                  _LegendItem(color: const Color(0xFF4CAF50), text: 'Normal: 9-25 Pa'),
                  const SizedBox(height: 8),
                  _LegendItem(color: const Color(0xFFFF9800), text: 'Clogging: 25-40 Pa'),
                  const SizedBox(height: 8),
                  _LegendItem(color: const Color(0xFFF44336), text: 'Replace: > 40 Pa'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
