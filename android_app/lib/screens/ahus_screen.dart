import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';

/// AHUs list screen for a specific hospital
class AhusScreen extends StatelessWidget {
  final Hospital hospital;

  const AhusScreen({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAhus = hospital.allAhus;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          hospital.name,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<AppProvider>().refreshAllDevices(),
            tooltip: 'Refresh',
          ),
        ],
      ),
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
        child: allAhus.isEmpty
            ? _EmptyState()
            : RefreshIndicator(
                onRefresh: () async {
                  final provider = context.read<AppProvider>();
                  await provider.loadHospitals();
                  await provider.refreshAllDevices();
                },
                child: ListView.builder(
                  padding: ScreenUtils.getScreenPadding(context),
                  itemCount: allAhus.length,
                  itemBuilder: (context, index) {
                    final ahu = allAhus[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: ScreenUtils.getSpacing(context, 12),
                      ),
                      child: _AhuCard(ahu: ahu, hospital: hospital),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.air_rounded,
            size: ScreenUtils.getIconSize(context, 72),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Text(
            'No AHU units found',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _AhuCard extends StatelessWidget {
  final AhuDevice ahu;
  final Hospital hospital;

  const _AhuCard({required this.ahu, required this.hospital});

  @override
  Widget build(BuildContext context) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 18);

    return Selector<AppProvider, DeviceStatus?>(
      selector: (_, provider) => provider.getDeviceStatus(ahu.id),
      builder: (context, status, child) {
        final isOnline = status?.isOnline ?? ahu.isOnline;
        final isRunning = status?.isRunning ?? false;
        final temp = status?.temperature;
        final hum = status?.humidity;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AhuControlScreen(
                    deviceId: ahu.id,
                    deviceName: ahu.name,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: ScreenUtils.getCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(
                    ahu: ahu,
                    hospital: hospital,
                    isOnline: isOnline,
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 14)),
                  _SensorRow(temp: temp, hum: hum),
                  SizedBox(height: ScreenUtils.getSpacing(context, 12)),
                  _StatusChips(isRunning: isRunning, status: status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardHeader extends StatelessWidget {
  final AhuDevice ahu;
  final Hospital hospital;
  final bool isOnline;

  const _CardHeader({
    required this.ahu,
    required this.hospital,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ahu.name,
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 17),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 4)),
              Text(
                '${ahu.room.toUpperCase()} • ${hospital.name}',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 12),
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        SizedBox(width: ScreenUtils.getPadding(context, 10)),
        _StatusBadge(isOnline: isOnline),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOnline;

  const _StatusBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppTheme.success : AppTheme.error;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 10),
        vertical: ScreenUtils.getSpacing(context, 6),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 6)),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 11),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final double? temp;
  final double? hum;

  const _SensorRow({required this.temp, required this.hum});

  @override
  Widget build(BuildContext context) {
    final tempValue = temp;
    final humValue = hum;
    
    return Row(
      children: [
        Expanded(
          child: _SensorDisplay(
            icon: Icons.thermostat_rounded,
            value: tempValue != null ? '${tempValue.toStringAsFixed(1)}°C' : '--',
            color: AppTheme.temperature,
          ),
        ),
        SizedBox(width: ScreenUtils.getPadding(context, 10)),
        Expanded(
          child: _SensorDisplay(
            icon: Icons.water_drop_rounded,
            value: humValue != null ? '${humValue.toStringAsFixed(1)}%' : '--',
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
  final Color color;

  const _SensorDisplay({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 24)),
          SizedBox(width: ScreenUtils.getPadding(context, 8)),
          Text(
            value,
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final bool isRunning;
  final DeviceStatus? status;

  const _StatusChips({required this.isRunning, required this.status});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ScreenUtils.getPadding(context, 8),
      runSpacing: ScreenUtils.getSpacing(context, 8),
      children: [
        _StatusChip(
          label: 'Running',
          isActive: isRunning,
          color: AppTheme.success,
        ),
        if (status != null) ...[
          _StatusChip(
            label: 'CP',
            isActive: status!.state?.cp ?? false,
            color: AppTheme.info,
          ),
          _StatusChip(
            label: 'Heater',
            isActive: status!.state?.heater ?? false,
            color: AppTheme.info,
          ),
          _StatusChip(
            label: status!.state?.fanSpeedDisplay ?? 'Fan',
            isActive: status!.state?.fan ?? false,
            color: AppTheme.success,
          ),
        ],
      ],
    );
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
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 10),
        vertical: ScreenUtils.getSpacing(context, 6),
      ),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
        border: Border.all(
          color: isActive ? color : Theme.of(context).dividerColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ScreenUtils.getFontSize(context, 11),
          fontWeight: FontWeight.w600,
          color: isActive ? color : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}
