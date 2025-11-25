import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';
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
        );
      },
      builder: (context, data, child) {
        return Container(
          height: buttonHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: data.isRunning
                  ? [AppTheme.error, const Color(0xFFDC2626)]
                  : [AppTheme.success, const Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: data.isOnline
                  ? () => context.read<AppProvider>().toggleAhu(deviceId)
                  : null,
              borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    data.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: ScreenUtils.getIconSize(context, 20),
                  ),
                  SizedBox(width: ScreenUtils.getPadding(context, 8)),
                  Text(
                    data.isRunning ? 'Stop' : 'Start',
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

  _StartStopData({required this.isRunning, required this.isOnline});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StartStopData &&
          isRunning == other.isRunning &&
          isOnline == other.isOnline;

  @override
  int get hashCode => isRunning.hashCode ^ isOnline.hashCode;
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
            _SensorControl(
              icon: Icons.thermostat_rounded,
              label: 'Temperature',
              actual: status.telemetry?.temp?.toStringAsFixed(1) ?? '--',
              setpoint: status.tempSetpoint,
              unit: '°C',
              color: AppTheme.temperature,
              min: 15,
              max: 30,
              onChanged: (value) {
                context.read<AppProvider>().setTemperature(deviceId, value);
              },
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 14)),
            _SensorControl(
              icon: Icons.water_drop_rounded,
              label: 'Humidity',
              actual: status.telemetry?.hum?.toStringAsFixed(1) ?? '--',
              setpoint: status.humSetpoint,
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
    final borderRadius = ScreenUtils.getBorderRadius(context, 18);
    final padding = ScreenUtils.getPadding(context, 18);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [color.withOpacity(0.15), color.withOpacity(0.08)]
              : [Colors.white, color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                _SensorHeader(icon: icon, label: label, color: color),
                SizedBox(height: ScreenUtils.getSpacing(context, 14)),
                _ActualValue(actual: actual, unit: unit, color: color),
                SizedBox(height: ScreenUtils.getSpacing(context, 16)),
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
                onPressed: setpoint > min ? () => onChanged(setpoint - 0.5) : null,
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 14)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtils.getPadding(context, 14),
                  vertical: ScreenUtils.getSpacing(context, 8),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
                ),
                child: Text(
                  '${setpoint.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 14)),
              _ControlButton(
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

    return Selector<AppProvider, DeviceStatus?>(
      selector: (_, provider) => provider.getDeviceStatus(deviceId),
      builder: (context, status, child) {
        if (status == null) return const SizedBox.shrink();

        final state = status.state;
        final isOnline = status.isOnline;
        final isRunning = status.isRunning;

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
                      onTap: (isOnline && isRunning)
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
    final width = ScreenUtils.getPadding(context, 90);
    final borderRadius = ScreenUtils.getBorderRadius(context, 12);

    return Container(
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
              size: ScreenUtils.getIconSize(context, 18),
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
