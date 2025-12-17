import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
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

  final List<Widget> _screens = const [
    ClientHomeScreen(),
    ClientAhusScreen(),
    ClientReportsScreen(),
  ];

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
              _ClientTopBar(isDark: isDark),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
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
                icon: Icons.support_agent_rounded,
                label: 'Support',
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
  final bool isDark;

  const _ClientTopBar({required this.isDark});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Selector<AppProvider, String>(
                  selector: (_, provider) => provider.currentUser?.hospitalName ?? 'Dashboard',
                  builder: (context, hospitalName, child) {
                    return Text(
                      hospitalName,
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 18),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 2)),
                Selector<AppProvider, int>(
                  selector: (_, provider) {
                    final user = provider.currentUser;
                    if (user == null) return 0;
                    int onlineCount = 0;
                    for (final ahuId in user.assignedAhuIds) {
                      final status = provider.getDeviceStatus(ahuId);
                      if (status?.isOnline ?? false) onlineCount++;
                    }
                    return onlineCount;
                  },
                  builder: (context, onlineCount, child) {
                    return Text(
                      '$onlineCount AHUs Online',
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 12),
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
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
