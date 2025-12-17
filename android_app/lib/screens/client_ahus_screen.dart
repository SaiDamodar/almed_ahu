import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';

/// Client AHUs Screen - Shows all assigned AHUs
class ClientAhusScreen extends StatelessWidget {
  const ClientAhusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final appProvider = context.read<AppProvider>();
        final user = appProvider.currentUser;
        if (user != null) {
          await Future.wait(
            user.assignedAhuIds.map((id) => appProvider.loadDeviceStatus(id)),
          );
        }
      },
      child: Selector<AppProvider, List<_AhuData>>(
        selector: (_, provider) {
          final user = provider.currentUser;
          if (user == null) return [];
          
          return user.assignedAhuIds.map((id) {
            final status = provider.getDeviceStatus(id);
            return _AhuData(ahuId: id, status: status);
          }).toList();
        },
        builder: (context, ahus, child) {
          if (ahus.isEmpty) {
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
                ],
              ),
            );
          }

          return ListView.builder(
            padding: ScreenUtils.getScreenPadding(context),
            itemCount: ahus.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(ahus: ahus);
              }
              final data = ahus[index - 1];
              return _AhuCard(ahuId: data.ahuId, status: data.status);
            },
          );
        },
      ),
    );
  }
}

class _AhuData {
  final String ahuId;
  final DeviceStatus? status;

  _AhuData({required this.ahuId, this.status});
}

class _Header extends StatelessWidget {
  final List<_AhuData> ahus;

  const _Header({required this.ahus});

  @override
  Widget build(BuildContext context) {
    final online = ahus.where((a) => a.status?.isOnline ?? false).length;
    final offline = ahus.length - online;

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
                '${ahus.length} unit${ahus.length != 1 ? 's' : ''} assigned',
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 13),
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _StatusBadge(count: online, color: AppTheme.success),
              SizedBox(width: ScreenUtils.getPadding(context, 8)),
              _StatusBadge(count: offline, color: AppTheme.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _StatusBadge({required this.count, required this.color});

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

class _AhuCard extends StatelessWidget {
  final String ahuId;
  final DeviceStatus? status;

  const _AhuCard({required this.ahuId, this.status});

  @override
  Widget build(BuildContext context) {
    final isOnline = status?.isOnline ?? false;
    final isRunning = status?.isRunning ?? false;
    final temp = status?.telemetry?.temp;
    final hum = status?.telemetry?.hum;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 12)),
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
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
          child: Row(
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
                      borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
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
                        _Chip(
                          label: isOnline ? 'Online' : 'Offline',
                          color: isOnline ? AppTheme.success : AppTheme.error,
                        ),
                        if (isOnline) ...[
                          SizedBox(width: ScreenUtils.getPadding(context, 8)),
                          _Chip(
                            label: isRunning ? 'Running' : 'Standby',
                            color: isRunning ? AppTheme.warning : Colors.grey,
                          ),
                        ],
                      ],
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
                      Icon(Icons.thermostat_rounded, size: 16, color: AppTheme.error),
                      SizedBox(width: 4),
                      Text(
                        temp != null ? '${temp.toStringAsFixed(1)}°' : '--',
                        style: TextStyle(
                          fontSize: ScreenUtils.getFontSize(context, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop_rounded, size: 16, color: AppTheme.info),
                      SizedBox(width: 4),
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
                color: AppTheme.lightPrimary,
                size: ScreenUtils.getIconSize(context, 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
