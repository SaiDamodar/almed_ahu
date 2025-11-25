import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../models/device_status.dart';
import '../utils/screen_utils.dart';
import 'ahu_control_screen.dart';
import 'welcome_screen.dart';

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
      await Future.wait(
        user.assignedAhuIds.map((id) => appProvider.loadDeviceStatus(id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ALMED AHU',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkUserStatus,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Selector<AppProvider, User?>(
        selector: (_, provider) => provider.currentUser,
        builder: (context, user, child) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(context, user, isDark);
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildContent(BuildContext context, User user, bool isDark) {
    switch (user.status) {
      case UserStatus.pending:
        return _StatusMessage(
          title: 'Waiting for Verification',
          message: 'Your registration is pending admin approval. Please wait while we verify your account.',
          icon: Icons.pending_outlined,
          color: AppTheme.info,
        );
      case UserStatus.rejected:
        return _StatusMessage(
          title: 'Registration Rejected',
          message: 'Your registration request has been rejected. Please contact support for more information.',
          icon: Icons.cancel_outlined,
          color: AppTheme.error,
        );
      case UserStatus.approved:
        return _StatusMessage(
          title: 'Waiting for AHU Assignment',
          message: 'Your account has been approved. Please wait while the admin assigns AHU units to your hospital.',
          icon: Icons.schedule_outlined,
          color: AppTheme.info,
        );
      case UserStatus.suspended:
        return _StatusMessage(
          title: 'Account Suspended',
          message: 'Your account has been temporarily suspended. Please contact support for assistance.',
          icon: Icons.block_outlined,
          color: AppTheme.error,
        );
      case UserStatus.active:
        if (user.assignedAhuIds.isEmpty) {
          return _StatusMessage(
            title: 'No AHUs Assigned',
            message: 'You don\'t have any AHU units assigned yet. Please contact the admin to assign AHUs to your hospital.',
            icon: Icons.devices_outlined,
            color: AppTheme.info,
          );
        }
        return _AhuList(user: user);
    }
  }
}

class _StatusMessage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const _StatusMessage({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: ScreenUtils.getScreenPadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ScreenUtils.getPadding(context, 24)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: ScreenUtils.getIconSize(context, 56),
                  color: color,
                ),
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 20)),
              Text(
                title,
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 12)),
              Text(
                message,
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 14),
                  color: isDark
                      ? AppTheme.darkOnSurfaceVariant
                      : AppTheme.lightOnSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AhuList extends StatelessWidget {
  final User user;

  const _AhuList({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return RefreshIndicator(
      onRefresh: () async {
        await appProvider.checkUserStatus();
        await Future.wait(
          user.assignedAhuIds.map((id) => appProvider.loadDeviceStatus(id)),
        );
      },
      child: ListView(
        padding: ScreenUtils.getScreenPadding(context),
        children: [
          _UserInfoCard(user: user, isDark: isDark),
          SizedBox(height: ScreenUtils.getSpacing(context, 20)),
          _SectionHeader(
            title: 'Assigned AHU Units',
            count: user.assignedAhuIds.length,
          ),
          SizedBox(height: ScreenUtils.getSpacing(context, 12)),
          ...user.assignedAhuIds.map((ahuId) => _AhuCard(ahuId: ahuId)),
        ],
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  final User user;
  final bool isDark;

  const _UserInfoCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 16);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: ScreenUtils.getCardPadding(context),
        child: Row(
          children: [
            CircleAvatar(
              radius: ScreenUtils.getIconSize(context, 28),
              backgroundColor: AppTheme.lightPrimary.withOpacity(0.1),
              child: Icon(
                Icons.person,
                color: AppTheme.lightPrimary,
                size: ScreenUtils.getIconSize(context, 26),
              ),
            ),
            SizedBox(width: ScreenUtils.getPadding(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 17),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 3)),
                  Text(
                    user.hospitalName,
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 13),
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 17),
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$count unit${count != 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 13),
            color: AppTheme.lightPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AhuCard extends StatelessWidget {
  final String ahuId;

  const _AhuCard({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 16);

    return Selector<AppProvider, DeviceStatus?>(
      selector: (_, provider) => provider.getDeviceStatus(ahuId),
      builder: (context, status, child) {
        final isOnline = status?.isOnline ?? false;

        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
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
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: ScreenUtils.getCardPadding(context),
              child: Row(
                children: [
                  _StatusDot(isOnline: isOnline),
                  SizedBox(width: ScreenUtils.getPadding(context, 12)),
                  _AhuIcon(),
                  SizedBox(width: ScreenUtils.getPadding(context, 14)),
                  Expanded(child: _AhuInfo(ahuId: ahuId, status: status)),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.lightPrimary,
                    size: ScreenUtils.getIconSize(context, 24),
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

class _StatusDot extends StatelessWidget {
  final bool isOnline;

  const _StatusDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.success : AppTheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AhuIcon extends StatelessWidget {
  const _AhuIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
      decoration: BoxDecoration(
        color: AppTheme.lightPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
      ),
      child: Icon(
        Icons.ac_unit,
        color: AppTheme.lightPrimary,
        size: ScreenUtils.getIconSize(context, 22),
      ),
    );
  }
}

class _AhuInfo extends StatelessWidget {
  final String ahuId;
  final DeviceStatus? status;

  const _AhuInfo({required this.ahuId, required this.status});

  @override
  Widget build(BuildContext context) {
    final isOnline = status?.isOnline ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AHU Unit $ahuId',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ScreenUtils.getFontSize(context, 15),
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 4)),
        if (status != null)
          Wrap(
            spacing: ScreenUtils.getPadding(context, 8),
            runSpacing: ScreenUtils.getSpacing(context, 4),
            children: [
              _InfoChip(
                icon: isOnline ? Icons.check_circle : Icons.error,
                text: isOnline ? 'Online' : 'Offline',
                color: isOnline ? AppTheme.success : AppTheme.error,
              ),
              if (status?.telemetry != null && status!.telemetry!.hasSensorData) ...[
                _InfoChip(
                  text: status!.telemetry!.tempDisplay,
                  color: AppTheme.temperature,
                ),
                _InfoChip(
                  text: status!.telemetry!.humDisplay,
                  color: AppTheme.humidity,
                ),
              ],
            ],
          )
        else
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: ScreenUtils.getFontSize(context, 11),
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;

  const _InfoChip({
    this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          SizedBox(width: ScreenUtils.getPadding(context, 3)),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 11),
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
