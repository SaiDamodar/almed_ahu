import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../models/ahu_unit.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'ahu_control_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';

/// Modern dashboard with centered AHU cards
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 1,
                      height: 30,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Selector<AppProvider, bool>(
                            selector: (_, provider) => provider.isConnected,
                            builder: (context, isConnected, child) {
                              return Row(
                                children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isConnected ? AppTheme.success : AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isConnected ? 'Connected' : 'Disconnected',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Logout button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      tooltip: 'Logout',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Theme toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            themeProvider.isDarkMode
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                          onPressed: () => themeProvider.toggleTheme(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Admin settings
                  Selector<AppProvider, UserRole?>(
                    selector: (_, provider) => provider.currentRole,
                    builder: (context, role, child) {
                      if (role == UserRole.admin) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.settings_rounded),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AdminScreen(),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),

            // AHU Cards - Centered
            Expanded(
              child: Selector<AppProvider, List<AhuUnit>>(
                selector: (_, provider) => provider.ahuUnits,
                builder: (context, ahus, child) {
                  if (ahus.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ALMED Logo
                          Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Opacity(
                              opacity: 0.3,
                              child: Image.asset(
                                isDark 
                                    ? 'assets/images/logo_light.png'
                                    : 'assets/images/logo_dark.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.air_rounded,
                                    size: 80,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No AHU units configured',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: ahus.map((ahu) => _ModernAhuCard(ahu: ahu)).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernAhuCard extends StatelessWidget {
  final AhuUnit ahu;

  const _ModernAhuCard({required this.ahu});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _AhuCardData>(
      selector: (_, provider) => _AhuCardData(
        telemetry: provider.getTelemetry(ahu.id),
        state: provider.getState(ahu.id),
        status: provider.getStatus(ahu.id),
      ),
      builder: (context, data, child) {
        final isOnline = data.status == 'online';
        final isRunning = data.state?.run ?? false;

        return SizedBox(
          width: 380,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AhuControlScreen(ahuId: ahu.id),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ahu.name,
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ahu.room.toUpperCase()} • ${ahu.site}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isOnline ? AppTheme.success : AppTheme.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOnline ? AppTheme.success : AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sensors
                    Row(
                      children: [
                        Expanded(
                          child: _SensorDisplay(
                            icon: Icons.thermostat_rounded,
                            value: data.telemetry?.temp?.toStringAsFixed(1) ?? '--',
                            unit: '°C',
                            color: AppTheme.temperature,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SensorDisplay(
                            icon: Icons.water_drop_rounded,
                            value: data.telemetry?.hum?.toStringAsFixed(1) ?? '--',
                            unit: '%',
                            color: AppTheme.humidity,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Status chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: 'Running',
                          isActive: isRunning,
                          color: AppTheme.success,
                        ),
                        _StatusChip(
                          label: 'CP',
                          isActive: data.state?.cp ?? false,
                          color: AppTheme.info,
                        ),
                        _StatusChip(
                          label: 'Heater',
                          isActive: data.state?.heater ?? false,
                          color: AppTheme.info,
                        ),
                        _StatusChip(
                          label: _getFanLabel(data.state?.fanSpeed ?? 0),
                          isActive: data.state?.fan ?? false,
                          color: AppTheme.success,
                        ),
                      ],
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

class _SensorDisplay extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;

  const _SensorDisplay({
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _getFanLabel(int? fanSpeed) {
  switch (fanSpeed ?? 1) {  // Default to 1 (LOW) instead of 0 (OFF)
    case 1:
      return 'Fan LOW';
    case 2:
      return 'Fan MID';
    case 3:
      return 'Fan HIGH';
    default:
      return 'Fan LOW';  // Default to LOW (no OFF mode)
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? color : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class _AhuCardData {
  final telemetry;
  final state;
  final String? status;

  _AhuCardData({
    required this.telemetry,
    required this.state,
    required this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AhuCardData &&
          runtimeType == other.runtimeType &&
          telemetry == other.telemetry &&
          state == other.state &&
          status == other.status;

  @override
  int get hashCode => telemetry.hashCode ^ state.hashCode ^ status.hashCode;
}

