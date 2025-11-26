import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart'; // Contains Hospital and AhuDevice
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';

/// Admin Home Screen - Shows online AHUs overview
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<AppProvider>().loadHospitals(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ScreenUtils.getScreenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StatsOverview(),
            SizedBox(height: ScreenUtils.getSpacing(context, 20)),
            const _OnlineAhusSection(),
          ],
        ),
      ),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _StatsData>(
      selector: (_, provider) {
        int totalAhus = 0;
        int onlineAhus = 0;
        int runningAhus = 0;

        for (final hospital in provider.hospitalsList) {
          for (final ahu in hospital.allAhus) {
            totalAhus++;
            final status = provider.getDeviceStatus(ahu.id);
            if (status?.isOnline ?? false) {
              onlineAhus++;
              if (status?.isRunning ?? false) runningAhus++;
            }
          }
        }

        return _StatsData(
          totalAhus: totalAhus,
          onlineAhus: onlineAhus,
          runningAhus: runningAhus,
          hospitals: provider.hospitalsList.length,
        );
      },
      builder: (context, stats, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 12)),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_hospital_rounded,
                    label: 'Hospitals',
                    value: '${stats.hospitals}',
                    color: AppTheme.info,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 12)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.air_rounded,
                    label: 'Total AHUs',
                    value: '${stats.totalAhus}',
                    color: AppTheme.lightPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 12)),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.wifi_rounded,
                    label: 'Online',
                    value: '${stats.onlineAhus}',
                    color: AppTheme.success,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 12)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.play_circle_rounded,
                    label: 'Running',
                    value: '${stats.runningAhus}',
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatsData {
  final int totalAhus;
  final int onlineAhus;
  final int runningAhus;
  final int hospitals;

  _StatsData({
    required this.totalAhus,
    required this.onlineAhus,
    required this.runningAhus,
    required this.hospitals,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StatsData &&
          runtimeType == other.runtimeType &&
          totalAhus == other.totalAhus &&
          onlineAhus == other.onlineAhus &&
          runningAhus == other.runningAhus &&
          hospitals == other.hospitals;

  @override
  int get hashCode =>
      totalAhus.hashCode ^
      onlineAhus.hashCode ^
      runningAhus.hashCode ^
      hospitals.hashCode;
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
              ),
              child: Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 24)),
            ),
            SizedBox(width: ScreenUtils.getPadding(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 22),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 12),
                      color: Theme.of(context).textTheme.bodySmall?.color,
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
}

class _OnlineAhusSection extends StatelessWidget {
  const _OnlineAhusSection();

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<_OnlineAhuData>>(
      selector: (_, provider) {
        final onlineAhus = <_OnlineAhuData>[];

        for (final hospital in provider.hospitalsList) {
          for (final ahu in hospital.allAhus) {
            final status = provider.getDeviceStatus(ahu.id);
            if (status?.isOnline ?? false) {
              onlineAhus.add(_OnlineAhuData(
                ahu: ahu,
                hospitalName: hospital.name,
                status: status!,
              ));
            }
          }
        }

        return onlineAhus;
      },
      builder: (context, onlineAhus, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Online AHUs',
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.getPadding(context, 12),
                    vertical: ScreenUtils.getPadding(context, 6),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: ScreenUtils.getPadding(context, 6)),
                      Text(
                        '${onlineAhus.length} Online',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 12)),
            if (onlineAhus.isEmpty)
              _EmptyOnlineState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: onlineAhus.length,
                itemBuilder: (context, index) {
                  final data = onlineAhus[index];
                  return _OnlineAhuCard(
                    ahu: data.ahu,
                    hospitalName: data.hospitalName,
                    status: data.status,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _OnlineAhuData {
  final AhuDevice ahu;
  final String hospitalName;
  final DeviceStatus status;

  _OnlineAhuData({
    required this.ahu,
    required this.hospitalName,
    required this.status,
  });
}

class _EmptyOnlineState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 32)),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: ScreenUtils.getIconSize(context, 48),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 12)),
            Text(
              'No AHUs online',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 16),
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 4)),
            Text(
              'All devices are currently offline',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 12),
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineAhuCard extends StatelessWidget {
  final AhuDevice ahu;
  final String hospitalName;
  final DeviceStatus status;

  const _OnlineAhuCard({
    required this.ahu,
    required this.hospitalName,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = status.isRunning;
    final temp = status.telemetry?.temp;
    final hum = status.telemetry?.hum;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 10)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
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
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
        child: Padding(
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
          child: Row(
            children: [
              // Status indicator
              Container(
                padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRunning
                        ? [AppTheme.success.withOpacity(0.2), AppTheme.success.withOpacity(0.1)]
                        : [AppTheme.warning.withOpacity(0.2), AppTheme.warning.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                ),
                child: Icon(
                  isRunning ? Icons.play_circle_rounded : Icons.pause_circle_rounded,
                  color: isRunning ? AppTheme.success : AppTheme.warning,
                  size: ScreenUtils.getIconSize(context, 28),
                ),
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 14)),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ahu.name,
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                    Text(
                      hospitalName,
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 12),
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Readings
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thermostat_rounded,
                        size: ScreenUtils.getIconSize(context, 16),
                        color: AppTheme.error,
                      ),
                      SizedBox(width: ScreenUtils.getPadding(context, 4)),
                      Text(
                        temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.water_drop_rounded,
                        size: ScreenUtils.getIconSize(context, 16),
                        color: AppTheme.info,
                      ),
                      SizedBox(width: ScreenUtils.getPadding(context, 4)),
                      Text(
                        hum != null ? '${hum.toStringAsFixed(1)}%' : '--',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 8)),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: ScreenUtils.getIconSize(context, 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

