import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';
import 'ahus_screen.dart';
import 'login_screen.dart';

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
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
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
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hospitals',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 28,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Logout button
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.1),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () {
                          Provider.of<AppProvider>(context, listen: false).logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        tooltip: 'Logout',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Theme toggle
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              themeProvider.isDarkMode
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                            onPressed: () => themeProvider.toggleTheme(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Hospitals list
              Expanded(
                child: Consumer<AppProvider>(
                  builder: (context, appProvider, child) {
                    if (appProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final hospitals = appProvider.hospitalsList;

                    if (hospitals.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_hospital_rounded,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hospitals found',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => appProvider.loadHospitals(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => appProvider.loadHospitals(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: hospitals.length,
                        itemBuilder: (context, index) {
                          final hospital = hospitals[index];
                          return _HospitalCard(hospital: hospital);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AhusScreen(hospital: hospital),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Hospital icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: AppTheme.info,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              // Hospital info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 20,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.air_rounded,
                          size: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalAhus AHU${totalAhus != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$onlineAhus online',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.success,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

