import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../utils/screen_utils.dart';
import 'client_home_screen.dart';
import 'client_ahus_screen.dart';
import 'client_reports_screen.dart';
import 'welcome_screen.dart';

/// Client Dashboard with bottom navigation
class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.checkUserStatus();
    await _loadDeviceStatuses();
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

    return Selector<AppProvider, User?>(
      selector: (_, provider) => provider.currentUser,
      builder: (context, user, child) {
        // Show status screens for non-active users
        if (user == null) {
          return _buildLoadingScreen(isDark);
        }

        if (user.status != UserStatus.active || user.assignedAhuIds.isEmpty) {
          return _buildStatusScreen(user, isDark);
        }

        // Active user with assigned AHUs - show dashboard
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
                  _ClientTopBar(user: user, isDark: isDark),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: const [
                        ClientHomeScreen(),
                        ClientAhusScreen(),
                        ClientReportsScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(isDark),
        );
      },
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [AppTheme.darkBackground, AppTheme.darkSurface]
                : [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildStatusScreen(User user, bool isDark) {
    String title;
    String message;
    IconData icon;
    Color color;

    switch (user.status) {
      case UserStatus.pending:
        title = 'Waiting for Verification';
        message = 'Your registration is pending admin approval. Please wait while we verify your account.';
        icon = Icons.pending_outlined;
        color = AppTheme.info;
        break;
      case UserStatus.rejected:
        title = 'Registration Rejected';
        message = 'Your registration request has been rejected. Please contact support for more information.';
        icon = Icons.cancel_outlined;
        color = AppTheme.error;
        break;
      case UserStatus.approved:
        title = 'Waiting for AHU Assignment';
        message = 'Your account has been approved. Please wait while the admin assigns AHU units to your hospital.';
        icon = Icons.schedule_outlined;
        color = AppTheme.info;
        break;
      case UserStatus.suspended:
        title = 'Account Suspended';
        message = 'Your account has been temporarily suspended. Please contact support for assistance.';
        icon = Icons.block_outlined;
        color = AppTheme.error;
        break;
      case UserStatus.active:
        title = 'No AHUs Assigned';
        message = 'You don\'t have any AHU units assigned yet. Please contact the admin.';
        icon = Icons.devices_outlined;
        color = AppTheme.info;
        break;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [AppTheme.darkBackground, AppTheme.darkSurface, Color(0xFF334155)]
                : [Colors.white, Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _StatusTopBar(user: user, isDark: isDark),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: ScreenUtils.getScreenPadding(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 28)),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 64, color: color),
                        ),
                        SizedBox(height: ScreenUtils.getSpacing(context, 24)),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: ScreenUtils.getFontSize(context, 22),
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
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ScreenUtils.getSpacing(context, 32)),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final appProvider = Provider.of<AppProvider>(context, listen: false);
                            await appProvider.checkUserStatus();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Status'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ScreenUtils.getPadding(context, 8),
            vertical: ScreenUtils.getPadding(context, 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.air_rounded,
                label: 'AHUs',
                isSelected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.assessment_rounded,
                label: 'Reports',
                isSelected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.lightPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, isSelected ? 20 : 16),
          vertical: ScreenUtils.getPadding(context, 10),
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ScreenUtils.getIconSize(context, 24),
              color: isSelected ? primaryColor : Colors.grey,
            ),
            if (isSelected) ...[
              SizedBox(width: ScreenUtils.getPadding(context, 8)),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: ScreenUtils.getFontSize(context, 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClientTopBar extends StatelessWidget {
  final User user;
  final bool isDark;

  const _ClientTopBar({required this.user, required this.isDark});

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
              borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
            ),
            child: Text(
              'ALMED',
              style: TextStyle(
                fontFamily: 'Verdana',
                fontSize: ScreenUtils.getFontSize(context, 16),
                fontWeight: FontWeight.w600,
                color: AppTheme.lightPrimary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.hospitalName,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 16),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 2)),
                Text(
                  'Welcome, ${user.username}',
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 12),
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
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

class _StatusTopBar extends StatelessWidget {
  final User user;
  final bool isDark;

  const _StatusTopBar({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final padding = ScreenUtils.getPadding(context, 16);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 10)),
            decoration: BoxDecoration(
              color: AppTheme.lightPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
            ),
            child: Text(
              'ALMED',
              style: TextStyle(
                fontFamily: 'Verdana',
                fontSize: ScreenUtils.getFontSize(context, 16),
                fontWeight: FontWeight.w600,
                color: AppTheme.lightPrimary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 12)),
          Expanded(
            child: Text(
              user.hospitalName,
              style: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 16),
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        ],
      ),
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
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
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
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
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

