import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';

/// Client Home Screen - Shows overview of assigned AHUs
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final appProvider = context.read<AppProvider>();
        await appProvider.checkUserStatus();
        final user = appProvider.currentUser;
        if (user != null) {
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
          children: const [
            _StatsOverview(),
            SizedBox(height: 20),
            _OnlineAhusSection(),
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
        if (user == null) return _StatsData(total: 0, online: 0, running: 0, avgTemp: 0, avgHum: 0);

        int online = 0;
        int running = 0;
        double totalTemp = 0;
        double totalHum = 0;
        int tempCount = 0;
        int humCount = 0;

        for (final ahuId in user.assignedAhuIds) {
          final status = provider.getDeviceStatus(ahuId);
          if (status?.isOnline ?? false) {
            online++;
            if (status?.isRunning ?? false) running++;
            if (status?.telemetry?.temp != null) {
              totalTemp += status!.telemetry!.temp!;
              tempCount++;
            }
            if (status?.telemetry?.hum != null) {
              totalHum += status!.telemetry!.hum!;
              humCount++;
            }
          }
        }

        return _StatsData(
          total: user.assignedAhuIds.length,
          online: online,
          running: running,
          avgTemp: tempCount > 0 ? totalTemp / tempCount : 0,
          avgHum: humCount > 0 ? totalHum / humCount : 0,
        );
      },
      builder: (context, stats, child) {
        final uptime = stats.total > 0 ? (stats.online / stats.total * 100).round() : 0;
        
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
            // First row - AHU counts
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.air_rounded,
                    label: 'Total',
                    value: '${stats.total}',
                    color: AppTheme.lightPrimary,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 10)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.wifi_rounded,
                    label: 'Online',
                    value: '${stats.online}',
                    color: AppTheme.success,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 10)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.play_circle_rounded,
                    label: 'Running',
                    value: '${stats.running}',
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 10)),
            // Second row - Quick stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.speed_rounded,
                    label: 'Uptime',
                    value: '$uptime%',
                    color: AppTheme.info,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 10)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Avg Temp',
                    value: stats.avgTemp > 0 ? '${stats.avgTemp.toStringAsFixed(1)}°' : '--',
                    color: AppTheme.error,
                  ),
                ),
                SizedBox(width: ScreenUtils.getPadding(context, 10)),
                Expanded(
                  child: _StatCard(
                    icon: Icons.water_drop_rounded,
                    label: 'Avg Hum',
                    value: stats.avgHum > 0 ? '${stats.avgHum.toStringAsFixed(1)}%' : '--',
                    color: AppTheme.humidity,
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
  final int total;
  final int online;
  final int running;
  final double avgTemp;
  final double avgHum;

  _StatsData({
    required this.total,
    required this.online,
    required this.running,
    required this.avgTemp,
    required this.avgHum,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StatsData &&
          total == other.total &&
          online == other.online &&
          running == other.running &&
          avgTemp == other.avgTemp &&
          avgHum == other.avgHum;

  @override
  int get hashCode =>
      total.hashCode ^
      online.hashCode ^
      running.hashCode ^
      avgTemp.hashCode ^
      avgHum.hashCode;
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
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
              ),
              child: Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 22)),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 10)),
            Text(
              value,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 24),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 2)),
            Text(
              label,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 11),
                color: Theme.of(context).textTheme.bodySmall?.color,
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
    return Selector<AppProvider, List<_AhuStatusData>>(
      selector: (_, provider) {
        final user = provider.currentUser;
        if (user == null) return [];

        final ahuList = <_AhuStatusData>[];
        for (final ahuId in user.assignedAhuIds) {
          final status = provider.getDeviceStatus(ahuId);
          if (status?.isOnline ?? false) {
            ahuList.add(_AhuStatusData(ahuId: ahuId, status: status!));
          }
        }
        return ahuList;
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
                  return _OnlineAhuCard(ahuId: data.ahuId, status: data.status);
                },
              ),
          ],
        );
      },
    );
  }
}

class _AhuStatusData {
  final String ahuId;
  final DeviceStatus status;

  _AhuStatusData({required this.ahuId, required this.status});
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
              'All your AHU units are currently offline',
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

  const _OnlineAhuCard({required this.ahuId, required this.status});

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
                  size: ScreenUtils.getIconSize(context, 26),
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

