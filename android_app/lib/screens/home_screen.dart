import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
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
    // Check user status when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.checkUserStatus();
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
    return RefreshIndicator(
      onRefresh: _checkUserStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assigned AHUs Section
          Text(
            'Assigned AHU Units',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // AHU List
          ...user.assignedAhuIds.map((ahuId) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.ac_unit,
                    color: AppTheme.lightPrimary,
                  ),
                ),
                title: Text(
                  'AHU Unit $ahuId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Device ID: $ahuId'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to AHU control screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AhuControlScreen(
                        deviceId: ahuId,
                        deviceName: 'AHU Unit $ahuId',
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

