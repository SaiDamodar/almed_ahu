import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';
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
        title: Text(hospital.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              Provider.of<AppProvider>(context, listen: false).refreshAllDevices();
            },
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
        child: allAhus.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.air_rounded,
                      size: ScreenUtils.getIconSize(context, 80),
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 16)),
                    Text(
                      'No AHU units found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: ScreenUtils.getFontSize(context, 16),
                          ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  final provider = Provider.of<AppProvider>(context, listen: false);
                  await provider.loadHospitals();
                  await provider.refreshAllDevices();
                },
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.getPadding(context, 16),
                    vertical: ScreenUtils.getSpacing(context, 12),
                  ),
                  itemCount: allAhus.length,
                  itemBuilder: (context, index) {
                    final ahu = allAhus[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 12)),
                      child: _AhuCard(ahu: ahu, hospital: hospital),
                    );
                  },
                ),
              ),
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
    final appProvider = Provider.of<AppProvider>(context);
    final status = appProvider.getDeviceStatus(ahu.id);
    final isOnline = status?.isOnline ?? ahu.isOnline;
    final isRunning = status?.isRunning ?? false;
    final temp = status?.temperature;
    final hum = status?.humidity;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AhuControlScreen(deviceId: ahu.id, deviceName: ahu.name),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ahu.name,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: ScreenUtils.getFontSize(context, 18),
                                fontWeight: FontWeight.bold,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                        Text(
                          '${ahu.room.toUpperCase()} • ${hospital.name}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: ScreenUtils.getFontSize(context, 12),
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ScreenUtils.getPadding(context, 12)),
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenUtils.getPadding(context, 10),
                      vertical: ScreenUtils.getSpacing(context, 6),
                    ),
                    decoration: BoxDecoration(
                      color: (isOnline ? AppTheme.success : AppTheme.error).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isOnline ? AppTheme.success : AppTheme.error).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
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
                            fontSize: ScreenUtils.getFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: isOnline ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 16)),

              // Sensors - Always column for narrow screens
              Column(
                children: [
                  _SensorDisplay(
                    icon: Icons.thermostat_rounded,
                    value: temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
                    color: AppTheme.temperature,
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 12)),
                  _SensorDisplay(
                    icon: Icons.water_drop_rounded,
                    value: hum != null ? '${hum.toStringAsFixed(1)}%' : '--',
                    color: AppTheme.humidity,
                  ),
                ],
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 12)),

              // Status chips
              Wrap(
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
                      isActive: status.state?.cp ?? false,
                      color: AppTheme.info,
                    ),
                    _StatusChip(
                      label: 'Heater',
                      isActive: status.state?.heater ?? false,
                      color: AppTheme.info,
                    ),
                    _StatusChip(
                      label: status.state?.fanSpeedDisplay ?? 'Fan',
                      isActive: status.state?.fan ?? false,
                      color: AppTheme.success,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 28)),
          SizedBox(height: ScreenUtils.getSpacing(context, 8)),
          Text(
            value,
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(10),
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

