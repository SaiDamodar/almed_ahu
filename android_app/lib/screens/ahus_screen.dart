import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';
import 'ahu_control_screen.dart';

/// AHUs list screen for a specific hospital
class AhusScreen extends StatelessWidget {
  final Hospital hospital;

  const AhusScreen({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAhus = hospital.allAhus;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
                      size: screenWidth * 0.2,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Text(
                      'No AHU units found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: screenWidth * 0.04,
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
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.02,
                  ),
                  itemCount: allAhus.length,
                  itemBuilder: (context, index) {
                    final ahu = allAhus[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: screenHeight * 0.02),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AhuControlScreen(deviceId: ahu.id, deviceName: ahu.name),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
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
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.bold,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          '${ahu.room.toUpperCase()} • ${hospital.name}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: screenWidth * 0.032,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.03,
                      vertical: screenHeight * 0.008,
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
                          width: screenWidth * 0.015,
                          height: screenWidth * 0.015,
                          decoration: BoxDecoration(
                            color: isOnline ? AppTheme.success : AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.015),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.w600,
                            color: isOnline ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.025),

              // Sensors - Responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 400) {
                    // Stack vertically on small screens
                    return Column(
                      children: [
                        _SensorDisplay(
                          icon: Icons.thermostat_rounded,
                          value: temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
                          color: AppTheme.temperature,
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        _SensorDisplay(
                          icon: Icons.water_drop_rounded,
                          value: hum != null ? '${hum.toStringAsFixed(1)}%' : '--',
                          color: AppTheme.humidity,
                        ),
                      ],
                    );
                  } else {
                    // Side by side on larger screens
                    return Row(
                      children: [
                        Expanded(
                          child: _SensorDisplay(
                            icon: Icons.thermostat_rounded,
                            value: temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
                            color: AppTheme.temperature,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: _SensorDisplay(
                            icon: Icons.water_drop_rounded,
                            value: hum != null ? '${hum.toStringAsFixed(1)}%' : '--',
                            color: AppTheme.humidity,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: screenHeight * 0.02),

              // Status chips
              Wrap(
                spacing: screenWidth * 0.02,
                runSpacing: screenWidth * 0.02,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: screenWidth * 0.07),
          SizedBox(height: screenHeight * 0.01),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.05,
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenWidth * 0.015,
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
          fontSize: screenWidth * 0.03,
          fontWeight: FontWeight.w600,
          color: isActive ? color : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

