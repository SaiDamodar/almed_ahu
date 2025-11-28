import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../models/ahu_unit.dart';
import '../models/ahu_telemetry.dart';
import '../models/ahu_state.dart';
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
                ? const [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
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
              // Top bar
              _DashboardTopBar(isDark: isDark),
              // AHU Cards
              Expanded(
                child: _AhuCardsList(isDark: isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  final bool isDark;
  
  const _DashboardTopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Reduced padding for 7-inch Pi display (1024x600)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            color: theme.dividerColor.withOpacity(0.3),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 4),
                const _ConnectionStatus(),
              ],
            ),
          ),
          // Action buttons
          _ActionButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 12),
          const _ThemeToggleButton(),
          const SizedBox(width: 12),
          const _AdminSettingsButton(),
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, bool>(
      selector: (_, provider) => provider.isConnected,
      builder: (context, isConnected, _) {
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
        ),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return Selector<ThemeProvider, bool>(
      selector: (_, provider) => provider.isDarkMode,
      builder: (context, isDarkMode, _) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
        );
      },
    );
  }
}

class _AdminSettingsButton extends StatelessWidget {
  const _AdminSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, UserRole?>(
      selector: (_, provider) => provider.currentRole,
      builder: (context, role, _) {
        if (role != UserRole.admin) {
          return const SizedBox.shrink();
        }
        
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AdminScreen()),
              );
            },
          ),
        );
      },
    );
  }
}

class _AhuCardsList extends StatelessWidget {
  final bool isDark;
  
  const _AhuCardsList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<AhuUnit>>(
      selector: (_, provider) => provider.ahuUnits,
      builder: (context, ahus, _) {
        if (ahus.isEmpty) {
          return _EmptyState(isDark: isDark);
        }

        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: ahus.map((ahu) => _ModernAhuCard(ahu: ahu)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
}

/// Data class for AHU card to enable efficient rebuilds
@immutable
class _AhuCardData {
  final AhuTelemetry? telemetry;
  final AhuState? state;
  final String? status;

  const _AhuCardData({
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
  int get hashCode => Object.hash(telemetry, state, status);
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
      builder: (context, data, _) {
        final isOnline = data.status == 'online';
        final isRunning = data.state?.run ?? false;
        final theme = Theme.of(context);

        // Optimized for 7-inch 1024x600 Pi display - fits 2 cards side by side
        return SizedBox(
          width: 320,
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
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status
                    _CardHeader(ahu: ahu, isOnline: isOnline),
                    const SizedBox(height: 16),
                    // Sensors
                    _SensorRow(data: data),
                    const SizedBox(height: 12),
                    // Status chips
                    _StatusChips(data: data, isRunning: isRunning),
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

class _CardHeader extends StatelessWidget {
  final AhuUnit ahu;
  final bool isOnline;
  
  const _CardHeader({required this.ahu, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = isOnline ? AppTheme.success : AppTheme.error;
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ahu.name,
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                '${ahu.room.toUpperCase()} • ${ahu.site}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SensorRow extends StatelessWidget {
  final _AhuCardData data;
  
  const _SensorRow({required this.data});

  @override
  Widget build(BuildContext context) {
    // Always show just temp and humidity on the AHU list (hospital page)
    // This keeps the cards clean and consistent for 7-inch Pi display
    return Row(
      children: [
        Expanded(
          child: _SensorDisplay(
            icon: Icons.thermostat_rounded,
            value: data.telemetry?.temp?.toStringAsFixed(1) ?? '--',
            unit: '°C',
            color: AppTheme.temperature,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SensorDisplay(
            icon: Icons.water_drop_rounded,
            value: data.telemetry?.hum?.toStringAsFixed(1) ?? '--',
            unit: '%',
            color: AppTheme.humidity,
          ),
        ),
      ],
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
        color: color.withOpacity(0.1),
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
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final _AhuCardData data;
  final bool isRunning;
  
  const _StatusChips({required this.data, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
    );
  }
  
  String _getFanLabel(int fanSpeed) {
    switch (fanSpeed) {
      case 0: return 'Fan OFF';
      case 1: return 'Fan LOW';
      case 2: return 'Fan MID';
      case 3: return 'Fan HIGH';
      default: return 'Fan';
    }
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
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color : theme.dividerColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive ? color : theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}
