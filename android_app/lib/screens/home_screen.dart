import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../models/device_status.dart';
import 'ahu_control_screen.dart';
import 'landing_screen.dart';

/// Home screen for hospital users showing status and assigned AHUs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Check user status and load device statuses when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
      _loadDeviceStatuses();
    });
  }

  Future<void> _checkUserStatus() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.checkUserStatus();
  }

  Future<void> _loadDeviceStatuses() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final user = appProvider.currentUser;
    if (user != null && user.assignedAhuIds.isNotEmpty) {
      // Load status for all assigned AHUs
      for (final ahuId in user.assignedAhuIds) {
        await appProvider.loadDeviceStatus(ahuId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ALMED AHU'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkUserStatus,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              appProvider.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: appProvider.currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context, appProvider.currentUser!, isDark),
    );
  }

  Widget _buildContent(BuildContext context, User user, bool isDark) {
    // Show status message based on user status
    if (user.status == UserStatus.pending) {
      return _buildStatusMessage(
        context,
        'Waiting for Verification',
        'Your registration is pending admin approval. Please wait while we verify your account.',
        Icons.pending_outlined,
        AppTheme.info,
        isDark,
      );
    }

    if (user.status == UserStatus.rejected) {
      return _buildStatusMessage(
        context,
        'Registration Rejected',
        'Your registration request has been rejected. Please contact support for more information.',
        Icons.cancel_outlined,
        AppTheme.error,
        isDark,
      );
    }

    if (user.status == UserStatus.approved) {
      return _buildStatusMessage(
        context,
        'Waiting for AHU Assignment',
        'Your account has been approved. Please wait while the admin assigns AHU units to your hospital.',
        Icons.schedule_outlined,
        AppTheme.info,
        isDark,
      );
    }

    if (user.status == UserStatus.suspended) {
      return _buildStatusMessage(
        context,
        'Account Suspended',
        'Your account has been temporarily suspended. Please contact support for assistance.',
        Icons.block_outlined,
        AppTheme.error,
        isDark,
      );
    }

    // User is active - show assigned AHUs
    if (user.assignedAhuIds.isEmpty) {
      return _buildStatusMessage(
        context,
        'No AHUs Assigned',
        'You don\'t have any AHU units assigned yet. Please contact the admin to assign AHUs to your hospital.',
        Icons.devices_outlined,
        AppTheme.info,
        isDark,
      );
    }

    // Show list of assigned AHUs
    return _buildAhuList(context, user, isDark);
  }

  Widget _buildStatusMessage(
    BuildContext context,
    String title,
    String message,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark
                        ? AppTheme.darkOnSurfaceVariant
                        : AppTheme.lightOnSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAhuList(BuildContext context, User user, bool isDark) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        await _checkUserStatus();
        // Refresh device statuses for assigned AHUs
        for (final ahuId in user.assignedAhuIds) {
          await appProvider.loadDeviceStatus(ahuId);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.lightPrimary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: AppTheme.lightPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.hospitalName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppTheme.darkOnSurfaceVariant
                                    : AppTheme.lightOnSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Assigned AHUs Section
          Row(
            children: [
              Text(
                'Assigned AHU Units',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                '${user.assignedAhuIds.length} unit${user.assignedAhuIds.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AHU List with status
          ...user.assignedAhuIds.map((ahuId) {
            final status = appProvider.getDeviceStatus(ahuId);
            final isOnline = status?.isOnline ?? false;
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AhuControlScreen(
                        deviceId: ahuId,
                        deviceName: 'AHU Unit $ahuId',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Status indicator
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.success : AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.ac_unit,
                          color: AppTheme.lightPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AHU Unit $ahuId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (status != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    isOnline ? Icons.check_circle : Icons.error,
                                    size: 14,
                                    color: isOnline ? AppTheme.success : AppTheme.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOnline ? AppTheme.success : AppTheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (status.telemetry != null && status.telemetry!.hasSensorData) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      status.telemetry!.tempDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.temperature,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      status.telemetry!.humDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.humidity,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.lightPrimary),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

