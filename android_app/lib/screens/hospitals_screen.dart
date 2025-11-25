import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';
import '../utils/screen_utils.dart';
import 'ahus_screen.dart';
import 'welcome_screen.dart';
import 'admin_users_screen.dart';

/// Hospitals list screen
class HospitalsScreen extends StatelessWidget {
  const HospitalsScreen({super.key});

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
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(isDark: isDark),
              const Expanded(child: _HospitalsList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isDark;

  const _TopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final padding = ScreenUtils.getPadding(context, 16);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
            decoration: BoxDecoration(
              color: AppTheme.lightPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                ScreenUtils.getBorderRadius(context, 12),
              ),
            ),
            child: Text(
              'ALMED',
              style: TextStyle(
                fontFamily: 'Verdana',
                fontSize: ScreenUtils.getFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: AppTheme.lightPrimary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 12)),
          Expanded(child: _TitleSection(isDark: isDark)),
          _ActionButton(
            icon: Icons.people_rounded,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
              );
            },
            tooltip: 'Users Management',
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 8)),
          _ActionButton(
            icon: Icons.logout_rounded,
            onPressed: () async {
              await appProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 8)),
          const _ThemeToggleButton(),
        ],
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  final bool isDark;

  const _TitleSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hospitals',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 2)),
        Selector<AppProvider, int>(
          selector: (_, provider) => provider.hospitalsList.fold(0, (sum, h) => sum + h.totalAhus),
          builder: (context, totalAhus, child) {
            return Text(
              '$totalAhus AHU units',
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 12),
                color: AppTheme.lightPrimary,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: ScreenUtils.getIconSize(context, 22)),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
        constraints: const BoxConstraints(),
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
      builder: (context, isDarkMode, child) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: ScreenUtils.getIconSize(context, 22),
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
            constraints: const BoxConstraints(),
          ),
        );
      },
    );
  }
}

class _HospitalsList extends StatelessWidget {
  const _HospitalsList();

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
    final totalAhus = hospital.totalAhus;
    final onlineAhus = hospital.allAhus.where((ahu) => ahu.isOnline).length;
    final offlineAhus = totalAhus - onlineAhus;
    final borderRadius = ScreenUtils.getBorderRadius(context, 20);

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
          child: Row(
            children: [
              _HospitalIcon(),
              SizedBox(width: ScreenUtils.getPadding(context, 16)),
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
                    SizedBox(height: ScreenUtils.getSpacing(context, 10)),
                    Wrap(
                      spacing: ScreenUtils.getPadding(context, 10),
                      runSpacing: ScreenUtils.getSpacing(context, 6),
                      children: [
                        _StatBadge(
                          icon: Icons.air_rounded,
                          label: '$totalAhus',
                          color: AppTheme.info,
                        ),
                        _StatBadge(
                          icon: Icons.check_circle,
                          label: '$onlineAhus',
                          color: AppTheme.success,
                        ),
                        if (offlineAhus > 0)
                          _StatBadge(
                            icon: Icons.error,
                            label: '$offlineAhus',
                            color: AppTheme.error,
                          ),
                      ],
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
        ),
      ),
    );
  }
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

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: ScreenUtils.getIconSize(context, 14), color: color),
        SizedBox(width: ScreenUtils.getPadding(context, 4)),
        Text(
          label,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
