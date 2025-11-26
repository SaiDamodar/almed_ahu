import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';

/// Client AHUs Screen - Shows all assigned AHUs in a flat list
class ClientAhusScreen extends StatelessWidget {
  const ClientAhusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, List<String>>(
      selector: (_, provider) => provider.currentUser?.assignedAhuIds ?? [],
      builder: (context, ahuIds, child) {
        if (ahuIds.isEmpty) {
          return _EmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            final appProvider = context.read<AppProvider>();
            await appProvider.checkUserStatus();
            await Future.wait(
              ahuIds.map((id) => appProvider.loadDeviceStatus(id)),
            );
          },
          child: ListView.builder(
            padding: ScreenUtils.getScreenPadding(context),
            itemCount: ahuIds.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(count: ahuIds.length);
              }
              return _AhuCard(ahuId: ahuIds[index - 1]);
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int count;

  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My AHU Units',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 4)),
              Text(
                '$count unit${count != 1 ? 's' : ''} assigned',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 13),
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          // Online/Offline summary
          Selector<AppProvider, _StatusCounts>(
            selector: (_, provider) {
              int online = 0;
              int offline = 0;
              final user = provider.currentUser;
              if (user != null) {
                for (final id in user.assignedAhuIds) {
                  final status = provider.getDeviceStatus(id);
                  if (status?.isOnline ?? false) {
                    online++;
                  } else {
                    offline++;
                  }
                }
              }
              return _StatusCounts(online: online, offline: offline);
            },
            builder: (context, counts, child) {
              return Row(
                children: [
                  _StatusBadge(
                    count: counts.online,
                    label: 'Online',
                    color: AppTheme.success,
                  ),
                  SizedBox(width: ScreenUtils.getPadding(context, 8)),
                  _StatusBadge(
                    count: counts.offline,
                    label: 'Offline',
                    color: AppTheme.error,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusCounts {
  final int online;
  final int offline;

  _StatusCounts({required this.online, required this.offline});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StatusCounts && online == other.online && offline == other.offline;

  @override
  int get hashCode => online.hashCode ^ offline.hashCode;
}

class _StatusBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 10),
        vertical: ScreenUtils.getPadding(context, 6),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 6)),
          Text(
            '$count',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 12),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
            size: ScreenUtils.getIconSize(context, 64),
            color: Colors.grey.shade400,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Text(
            'No AHUs assigned',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 18),
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 8)),
          Text(
            'Contact admin to assign AHU units',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 14),
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AhuCard extends StatelessWidget {
  final String ahuId;

  const _AhuCard({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, DeviceStatus?>(
      selector: (_, provider) => provider.getDeviceStatus(ahuId),
      builder: (context, status, child) {
        final isOnline = status?.isOnline ?? false;
        final isRunning = status?.isRunning ?? false;
        final temp = status?.telemetry?.temp;
        final hum = status?.telemetry?.hum;
        final tempSet = status?.tempSetpoint ?? 22.0;
        final humSet = status?.humSetpoint ?? 55.0;

        return Card(
          elevation: 3,
          margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 12)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 18)),
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
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 18)),
            child: Padding(
              padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      // AHU Icon with status
                      Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.lightPrimary.withOpacity(0.15),
                                  AppTheme.lightPrimary.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                ScreenUtils.getBorderRadius(context, 14),
                              ),
                            ),
                            child: Icon(
                              Icons.ac_unit_rounded,
                              color: AppTheme.lightPrimary,
                              size: ScreenUtils.getIconSize(context, 28),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isOnline ? AppTheme.success : AppTheme.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).cardColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: ScreenUtils.getPadding(context, 14)),
                      // Title and status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AHU $ahuId',
                              style: TextStyle(
                                fontSize: ScreenUtils.getFontSize(context, 18),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                            Row(
                              children: [
                                _MiniStatusChip(
                                  label: isOnline ? 'Online' : 'Offline',
                                  color: isOnline ? AppTheme.success : AppTheme.error,
                                ),
                                if (isOnline) ...[
                                  SizedBox(width: ScreenUtils.getPadding(context, 8)),
                                  _MiniStatusChip(
                                    label: isRunning ? 'Running' : 'Standby',
                                    color: isRunning ? AppTheme.warning : Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.lightPrimary,
                        size: ScreenUtils.getIconSize(context, 28),
                      ),
                    ],
                  ),
                  // Divider
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: ScreenUtils.getSpacing(context, 14)),
                    child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                  ),
                  // Readings row
                  Row(
                    children: [
                      Expanded(
                        child: _ReadingTile(
                          icon: Icons.thermostat_rounded,
                          label: 'Temperature',
                          value: temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
                          subValue: 'Set: ${tempSet.toStringAsFixed(1)}°C',
                          color: AppTheme.error,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _ReadingTile(
                          icon: Icons.water_drop_rounded,
                          label: 'Humidity',
                          value: hum != null ? '${hum.toStringAsFixed(1)}%' : '--',
                          subValue: 'Set: ${humSet.toStringAsFixed(1)}%',
                          color: AppTheme.info,
                        ),
                      ),
                    ],
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

class _MiniStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 8),
        vertical: ScreenUtils.getPadding(context, 3),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ScreenUtils.getFontSize(context, 10),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subValue;
  final Color color;

  const _ReadingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ScreenUtils.getPadding(context, 8)),
      child: Row(
        children: [
          Icon(icon, color: color, size: ScreenUtils.getIconSize(context, 22)),
          SizedBox(width: ScreenUtils.getPadding(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 10),
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

