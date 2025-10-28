import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
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
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
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
              // Top bar
              Padding(
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
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<AppProvider>(
                      builder: (context, provider, child) {
                        final ahu = provider.ahuUnits.firstWhere((a) => a.id == widget.ahuId);
                        final status = provider.getStatus(widget.ahuId);
                        final isOnline = status == 'online';
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ahu.name,
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: 22,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOnline ? AppTheme.success : AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Start/Stop toggle
                  Selector<AppProvider, bool>(
                    selector: (_, provider) => provider.getState(widget.ahuId)?.run ?? false,
                    builder: (context, isRunning, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isRunning
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF10B981), const Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final provider = Provider.of<AppProvider>(context, listen: false);
                              provider.toggleAhu(widget.ahuId);
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
                  ),
                ],
              ),
            ),

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
                    Consumer<AppProvider>(
                      builder: (context, provider, child) {
                        if (provider.currentRole == UserRole.admin) {
                          return Column(
                            children: [
                              _LogsSection(
                                ahuId: widget.ahuId,
                                isExpanded: _showLogs,
                                onToggle: () => setState(() => _showLogs = !_showLogs),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
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
      builder: (context, data, child) {
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
                  final provider = Provider.of<AppProvider>(context, listen: false);
                  provider.setTemperature(ahuId, value);
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
                  final provider = Provider.of<AppProvider>(context, listen: false);
                  provider.setHumidity(ahuId, value);
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          // Actual value
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                actual,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Actual',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 20),
          // Setpoint controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Setpoint',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: setpoint > min ? () => onChanged(setpoint - 0.5) : null,
                      icon: const Icon(Icons.remove_circle_rounded),
                      color: color,
                      iconSize: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${setpoint.toStringAsFixed(1)}$unit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: setpoint < max ? () => onChanged(setpoint + 0.5) : null,
                      icon: const Icon(Icons.add_circle_rounded),
                      color: color,
                      iconSize: 28,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentStatus extends StatelessWidget {
  final String ahuId;

  const _ComponentStatus({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _ComponentData>(
      selector: (_, provider) => _ComponentData(state: provider.getState(ahuId)),
      builder: (context, data, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Component Status',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final isAdmin = provider.currentRole == UserRole.admin;
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
                          icon: Icons.water_rounded,
                          label: 'Motor 1 (Drain)',
                          isActive: data.state?.m1 ?? false,
                          color: const Color(0xFF3B82F6),
                          isClickable: isAdmin,
                        ),
                      );
                    },
                  ),
                  Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final isAdmin = provider.currentRole == UserRole.admin;
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
                          icon: Icons.cleaning_services_rounded,
                          label: 'Motor 2 (Filter)',
                          isActive: data.state?.m2 ?? false,
                          color: const Color(0xFF60A5FA),
                          isClickable: isAdmin,
                        ),
                      );
                    },
                  ),
                  _StatusIndicator(
                    icon: Icons.ac_unit_rounded,
                    label: 'Compressor',
                    isActive: data.state?.cp ?? false,
                    color: const Color(0xFF2563EB),
                  ),
                  _StatusIndicator(
                    icon: Icons.whatshot_rounded,
                    label: 'Heater',
                    isActive: data.state?.heater ?? false,
                    color: const Color(0xFF1E40AF),
                  ),
                ],
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
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                icon,
                color: isActive ? color : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                size: 28,
              ),
              if (isClickable)
                Icon(
                  Icons.settings_rounded,
                  size: 14,
                  color: AppTheme.info.withValues(alpha: 0.7),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? color : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isActive ? 'ACTIVE' : 'IDLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? color : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
          ),
          if (isClickable)
            const SizedBox(height: 2),
          if (isClickable)
            Text(
              'Tap to configure',
              style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                color: AppTheme.info.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
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
                    Icon(
                      Icons.article_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'System Logs',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 18),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Selector<AppProvider, List>(
              selector: (_, provider) => provider.getLogs(ahuId),
              builder: (context, logs, child) {
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
                                        : log.lvl == 'WARN'
                                            ? AppTheme.info
                                            : AppTheme.info,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.formattedTime,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      log.msg,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SensorData {
  final telemetry;
  final state;

  _SensorData({required this.telemetry, required this.state});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SensorData &&
          runtimeType == other.runtimeType &&
          telemetry == other.telemetry &&
          state == other.state;

  @override
  int get hashCode => telemetry.hashCode ^ state.hashCode;
}

class _ComponentData {
  final state;

  _ComponentData({required this.state});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ComponentData &&
          runtimeType == other.runtimeType &&
          state == other.state;

  @override
  int get hashCode => state.hashCode;
}

