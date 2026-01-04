import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';

/// Client Home Screen - Shows online AHUs overview
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final appProvider = context.read<AppProvider>();
        
        // First, refresh user data (catches new AHU assignments, access level changes)
        await appProvider.refreshUserData();
        
        // Then refresh device statuses
        final user = appProvider.currentUser;
        if (user != null && user.assignedAhuIds.isNotEmpty) {
          await Future.wait(
            user.assignedAhuIds.map((id) => appProvider.loadDeviceStatus(id)),
          );
        }
      },
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
        final user = provider.currentUser;
        int totalAhus = user?.assignedAhuIds.length ?? 0;
        int onlineAhus = 0;
        int runningAhus = 0;

        if (user != null) {
          for (final ahuId in user.assignedAhuIds) {
            final status = provider.getDeviceStatus(ahuId);
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
                    icon: Icons.air_rounded,
                    label: 'Total AHUs',
                    value: '${stats.totalAhus}',
                    color: AppTheme.lightPrimary,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 12)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.wifi_rounded,
                    label: 'Online',
                    value: '${stats.onlineAhus}',
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 12)),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.play_circle_rounded,
                    label: 'Running',
                    value: '${stats.runningAhus}',
                    color: AppTheme.warning,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 12)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.pause_circle_rounded,
                    label: 'Standby',
                    value: '${stats.onlineAhus - stats.runningAhus}',
                    color: AppTheme.info,
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

  _StatsData({
    required this.totalAhus,
    required this.onlineAhus,
    required this.runningAhus,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StatsData &&
          runtimeType == other.runtimeType &&
          totalAhus == other.totalAhus &&
          onlineAhus == other.onlineAhus &&
          runningAhus == other.runningAhus;

  @override
  int get hashCode =>
      totalAhus.hashCode ^
      onlineAhus.hashCode ^
      runningAhus.hashCode;
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
        final user = provider.currentUser;
        if (user == null) return [];
        
        final onlineAhus = <_OnlineAhuData>[];
        for (final ahuId in user.assignedAhuIds) {
          final status = provider.getDeviceStatus(ahuId);
          if (status?.isOnline ?? false) {
            onlineAhus.add(_OnlineAhuData(
              ahuId: ahuId,
              status: status!,
            ));
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
                    ahuId: data.ahuId,
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
  final String ahuId;
  final DeviceStatus status;

  _OnlineAhuData({
    required this.ahuId,
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
  final String ahuId;
  final DeviceStatus status;

  const _OnlineAhuCard({
    required this.ahuId,
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
                deviceId: ahuId,
                deviceName: 'AHU $ahuId',
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
                      'AHU $ahuId',
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                    Text(
                      isRunning ? 'Running' : 'Standby',
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 12),
                        color: isRunning ? AppTheme.success : AppTheme.warning,
                        fontWeight: FontWeight.w500,
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
