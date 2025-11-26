import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';
import '../utils/screen_utils.dart';
import 'ahus_screen.dart';

/// Admin Hospitals Screen - Shows all hospitals with their AHUs
class AdminHospitalsScreen extends StatelessWidget {
  const AdminHospitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _HospitalsData>(
      selector: (_, provider) => _HospitalsData(
        isLoading: provider.isLoading,
        hospitals: provider.hospitalsList,
      ),
      builder: (context, data, child) {
        if (data.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (data.hospitals.isEmpty) {
          return _EmptyState();
        }

        return RefreshIndicator(
          onRefresh: () => context.read<AppProvider>().loadHospitals(),
          child: ListView.builder(
            padding: ScreenUtils.getScreenPadding(context),
            itemCount: data.hospitals.length,
            itemBuilder: (context, index) {
              return _HospitalCard(hospital: data.hospitals[index]);
            },
          ),
        );
      },
    );
  }
}

class _HospitalsData {
  final bool isLoading;
  final List<Hospital> hospitals;

  _HospitalsData({required this.isLoading, required this.hospitals});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HospitalsData &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          hospitals.length == other.hospitals.length;

  @override
  int get hashCode => isLoading.hashCode ^ hospitals.length.hashCode;
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital_rounded,
            size: ScreenUtils.getIconSize(context, 72),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 16)),
          Text(
            'No hospitals found',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 16),
            ),
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 12)),
          ElevatedButton.icon(
            onPressed: () => context.read<AppProvider>().loadHospitals(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;

  const _HospitalCard({required this.hospital});

  @override
  Widget build(BuildContext context) {
    return Selector<AppProvider, _HospitalStats>(
      selector: (_, provider) {
        int onlineCount = 0;
        int runningCount = 0;
        
        for (final ahu in hospital.allAhus) {
          final status = provider.getDeviceStatus(ahu.id);
          if (status?.isOnline ?? false) {
            onlineCount++;
            if (status?.isRunning ?? false) runningCount++;
          }
        }
        
        return _HospitalStats(
          totalAhus: hospital.totalAhus,
          onlineAhus: onlineCount,
          runningAhus: runningCount,
        );
      },
      builder: (context, stats, child) {
        final borderRadius = ScreenUtils.getBorderRadius(context, 20);
        final offlineAhus = stats.totalAhus - stats.onlineAhus;

        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 14)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AhusScreen(hospital: hospital)),
              );
            },
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HospitalIcon(),
                      SizedBox(width: ScreenUtils.getPadding(context, 14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hospital.name,
                              style: TextStyle(
                                fontSize: ScreenUtils.getFontSize(context, 18),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: ScreenUtils.getSpacing(context, 4)),
                            Text(
                              '${stats.totalAhus} AHU units • ${hospital.rooms.length} rooms',
                              style: TextStyle(
                                fontSize: ScreenUtils.getFontSize(context, 12),
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 8)),
                        decoration: BoxDecoration(
                          color: AppTheme.lightPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            ScreenUtils.getBorderRadius(context, 8),
                          ),
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.lightPrimary,
                          size: ScreenUtils.getIconSize(context, 22),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 14)),
                  // Stats row
                  Container(
                    padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.wifi_rounded,
                          label: 'Online',
                          value: '${stats.onlineAhus}',
                          color: AppTheme.success,
                        ),
                        _StatItem(
                          icon: Icons.play_circle_outline,
                          label: 'Running',
                          value: '${stats.runningAhus}',
                          color: AppTheme.warning,
                        ),
                        _StatItem(
                          icon: Icons.wifi_off_rounded,
                          label: 'Offline',
                          value: '$offlineAhus',
                          color: offlineAhus > 0 ? AppTheme.error : Colors.grey,
                        ),
                      ],
                    ),
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

class _HospitalStats {
  final int totalAhus;
  final int onlineAhus;
  final int runningAhus;

  _HospitalStats({
    required this.totalAhus,
    required this.onlineAhus,
    required this.runningAhus,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HospitalStats &&
          runtimeType == other.runtimeType &&
          totalAhus == other.totalAhus &&
          onlineAhus == other.onlineAhus &&
          runningAhus == other.runningAhus;

  @override
  int get hashCode =>
      totalAhus.hashCode ^ onlineAhus.hashCode ^ runningAhus.hashCode;
}

class _HospitalIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.info.withOpacity(0.2),
            AppTheme.info.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
      ),
      child: Icon(
        Icons.local_hospital_rounded,
        color: AppTheme.info,
        size: ScreenUtils.getIconSize(context, 28),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ScreenUtils.getIconSize(context, 18), color: color),
            SizedBox(width: ScreenUtils.getPadding(context, 6)),
            Text(
              value,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
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
    );
  }
}

