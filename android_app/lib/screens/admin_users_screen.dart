import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../utils/screen_utils.dart';

/// Admin Users Management Screen
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _pendingUsers = [];
  List<User> _registeredUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    final pending = await appProvider.getPendingUsers();
    final registered = await appProvider.getRegisteredUsers();
    
    if (mounted) {
      setState(() {
        _pendingUsers = pending;
        _registeredUsers = registered;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveUser(User user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Approve User',
      message: 'Approve registration for ${user.username} (${user.email})?',
      confirmText: 'Approve',
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<AppProvider>().approveUser(user.id);
    
    if (mounted) {
      _showResultSnackBar(
        success ? 'User approved successfully' : 'Failed to approve user',
        success,
      );
      if (success) _loadUsers();
    }
  }

  Future<void> _rejectUser(User user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Reject User',
      message: 'Reject registration for ${user.username} (${user.email})? This action cannot be undone.',
      confirmText: 'Reject',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<AppProvider>().rejectUser(user.id);

    if (mounted) {
      _showResultSnackBar(
        success ? 'User rejected' : 'Failed to reject user',
        success,
      );
      if (success) _loadUsers();
    }
  }

  Future<void> _assignAhus(User user) async {
    final appProvider = context.read<AppProvider>();
    final hospitals = appProvider.hospitalsList;
    
    final allAhus = <String>[];
    for (final hospital in hospitals) {
      for (final ahu in hospital.allAhus) {
        allAhus.add(ahu.id);
      }
    }

    if (allAhus.isEmpty) {
      _showResultSnackBar('No AHU units available', false);
      return;
    }

    final selectedAhus = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _AhuSelectionDialog(
        availableAhus: allAhus,
        selectedAhus: user.assignedAhuIds.toSet(),
      ),
    );

    if (selectedAhus == null || !mounted) return;

    final success = await appProvider.assignAhusToUser(user.id, selectedAhus.toList());

    if (mounted) {
      _showResultSnackBar(
        success ? 'AHUs assigned successfully' : 'Failed to assign AHUs',
        success,
      );
      if (success) _loadUsers();
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? ElevatedButton.styleFrom(backgroundColor: AppTheme.error)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showResultSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ScreenUtils.getPadding(context, 16),
            vertical: ScreenUtils.getPadding(context, 8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.lightPrimary,
                  labelColor: AppTheme.lightPrimary,
                  unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                  labelStyle: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 13),
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    _TabItem(label: 'Pending', count: _pendingUsers.length, color: AppTheme.info),
                    _TabItem(label: 'Registered', count: _registeredUsers.length, color: AppTheme.success),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUsers,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _UserList(
                      users: _pendingUsers,
                      emptyIcon: Icons.pending_outlined,
                      emptyMessage: 'No pending registrations',
                      onApprove: _approveUser,
                      onReject: _rejectUser,
                      showActions: true,
                      onRefresh: _loadUsers,
                    ),
                    _UserList(
                      users: _registeredUsers,
                      emptyIcon: Icons.people_outlined,
                      emptyMessage: 'No registered users',
                      onAssignAhus: _assignAhus,
                      showActions: false,
                      onRefresh: _loadUsers,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TabItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            SizedBox(width: ScreenUtils.getPadding(context, 6)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ScreenUtils.getPadding(context, 8),
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ScreenUtils.getFontSize(context, 10),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<User> users;
  final IconData emptyIcon;
  final String emptyMessage;
  final Function(User)? onApprove;
  final Function(User)? onReject;
  final Function(User)? onAssignAhus;
  final bool showActions;
  final VoidCallback onRefresh;

  const _UserList({
    required this.users,
    required this.emptyIcon,
    required this.emptyMessage,
    this.onApprove,
    this.onReject,
    this.onAssignAhus,
    required this.showActions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: ScreenUtils.getIconSize(context, 60),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            SizedBox(height: ScreenUtils.getSpacing(context, 14)),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 15)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: ScreenUtils.getScreenPadding(context),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserCard(
            user: user,
            onApprove: onApprove,
            onReject: onReject,
            onAssignAhus: onAssignAhus,
            showActions: showActions,
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final Function(User)? onApprove;
  final Function(User)? onReject;
  final Function(User)? onAssignAhus;
  final bool showActions;

  const _UserCard({
    required this.user,
    this.onApprove,
    this.onReject,
    this.onAssignAhus,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = ScreenUtils.getBorderRadius(context, 16);

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      child: Padding(
        padding: EdgeInsets.all(ScreenUtils.getPadding(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UserHeader(user: user),
            SizedBox(height: ScreenUtils.getSpacing(context, 14)),
            _UserInfo(user: user),
            if (user.assignedAhuIds.isNotEmpty) ...[
              SizedBox(height: ScreenUtils.getSpacing(context, 14)),
              _AssignedAhus(ahuIds: user.assignedAhuIds),
            ],
            if (showActions && (onApprove != null || onReject != null)) ...[
              SizedBox(height: ScreenUtils.getSpacing(context, 14)),
              _ActionButtons(
                onApprove: onApprove != null ? () => onApprove!(user) : null,
                onReject: onReject != null ? () => onReject!(user) : null,
              ),
            ],
            if (!showActions && onAssignAhus != null) ...[
              SizedBox(height: ScreenUtils.getSpacing(context, 14)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onAssignAhus!(user),
                  icon: Icon(Icons.assignment, size: ScreenUtils.getIconSize(context, 18)),
                  label: Text(
                    'Assign AHUs',
                    style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final User user;

  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.lightPrimary.withOpacity(0.2),
                AppTheme.lightPrimary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
          ),
          child: Text(
            user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
            style: TextStyle(
              color: AppTheme.lightPrimary,
              fontWeight: FontWeight.bold,
              fontSize: ScreenUtils.getFontSize(context, 18),
            ),
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
                  fontSize: ScreenUtils.getFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ScreenUtils.getSpacing(context, 3)),
              Text(
                user.email,
                style: TextStyle(
                  fontSize: ScreenUtils.getFontSize(context, 12),
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        if (user.status == UserStatus.active) _ActiveBadge(),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 10),
        vertical: ScreenUtils.getSpacing(context, 5),
      ),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.15),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 5)),
          Text(
            'Active',
            style: TextStyle(
              color: AppTheme.success,
              fontSize: ScreenUtils.getFontSize(context, 11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfo extends StatelessWidget {
  final User user;

  const _UserInfo({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenUtils.getPadding(context, 12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.local_hospital, label: 'Hospital', value: user.hospitalName),
          SizedBox(height: ScreenUtils.getSpacing(context, 10)),
          _InfoRow(icon: Icons.phone, label: 'Phone', value: user.phoneNumber),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: ScreenUtils.getIconSize(context, 16), color: Theme.of(context).textTheme.bodySmall?.color),
        SizedBox(width: ScreenUtils.getPadding(context, 8)),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 12)),
          ),
        ),
      ],
    );
  }
}

class _AssignedAhus extends StatelessWidget {
  final List<String> ahuIds;

  const _AssignedAhus({required this.ahuIds});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned AHUs (${ahuIds.length})',
          style: TextStyle(
            fontSize: ScreenUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: AppTheme.lightPrimary,
          ),
        ),
        SizedBox(height: ScreenUtils.getSpacing(context, 8)),
        Wrap(
          spacing: ScreenUtils.getPadding(context, 8),
          runSpacing: ScreenUtils.getSpacing(context, 8),
          children: ahuIds.map((id) => _AhuChip(ahuId: id)).toList(),
        ),
      ],
    );
  }
}

class _AhuChip extends StatelessWidget {
  final String ahuId;

  const _AhuChip({required this.ahuId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenUtils.getPadding(context, 10),
        vertical: ScreenUtils.getSpacing(context, 5),
      ),
      decoration: BoxDecoration(
        color: AppTheme.lightPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 8)),
        border: Border.all(color: AppTheme.lightPrimary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ac_unit, size: ScreenUtils.getIconSize(context, 14), color: AppTheme.lightPrimary),
          SizedBox(width: ScreenUtils.getPadding(context, 5)),
          Text(
            ahuId,
            style: TextStyle(
              color: AppTheme.lightPrimary,
              fontSize: ScreenUtils.getFontSize(context, 11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ActionButtons({this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onApprove != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: Icon(Icons.check, size: ScreenUtils.getIconSize(context, 18)),
              label: Text(
                'Approve',
                style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 13)),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            ),
          ),
        if (onApprove != null && onReject != null)
          SizedBox(width: ScreenUtils.getPadding(context, 10)),
        if (onReject != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: Icon(Icons.close, size: ScreenUtils.getIconSize(context, 18)),
              label: Text(
                'Reject',
                style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 13)),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
              ),
            ),
          ),
      ],
    );
  }
}

class _AhuSelectionDialog extends StatefulWidget {
  final List<String> availableAhus;
  final Set<String> selectedAhus;

  const _AhuSelectionDialog({
    required this.availableAhus,
    required this.selectedAhus,
  });

  @override
  State<_AhuSelectionDialog> createState() => _AhuSelectionDialogState();
}

class _AhuSelectionDialogState extends State<_AhuSelectionDialog> {
  late Set<String> _selectedAhus;

  @override
  void initState() {
    super.initState();
    _selectedAhus = Set.from(widget.selectedAhus);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign AHU Units'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 16)),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _selectedAhus = Set.from(widget.availableAhus)),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedAhus.clear()),
                    child: const Text('Deselect All'),
                  ),
                ],
              ),
              const Divider(),
              ...widget.availableAhus.map((ahuId) {
                return CheckboxListTile(
                  title: Text(ahuId),
                  value: _selectedAhus.contains(ahuId),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedAhus.add(ahuId);
                      } else {
                        _selectedAhus.remove(ahuId);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedAhus),
          child: Text('Assign (${_selectedAhus.length})'),
        ),
      ],
    );
  }
}
