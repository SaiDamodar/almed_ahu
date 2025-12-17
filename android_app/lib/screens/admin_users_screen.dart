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
  final TextEditingController _searchController = TextEditingController();
  List<User> _pendingUsers = [];
  List<User> _registeredUsers = [];
  List<User> _filteredPendingUsers = [];
  List<User> _filteredRegisteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchQuery.toLowerCase().trim();
    
    if (query.isEmpty) {
      _filteredPendingUsers = List.from(_pendingUsers);
      _filteredRegisteredUsers = List.from(_registeredUsers);
    } else {
      _filteredPendingUsers = _pendingUsers.where((user) {
        return user.username.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query) ||
               user.hospitalName.toLowerCase().contains(query) ||
               user.phoneNumber.toLowerCase().contains(query);
      }).toList();
      
      _filteredRegisteredUsers = _registeredUsers.where((user) {
        return user.username.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query) ||
               user.hospitalName.toLowerCase().contains(query) ||
               user.phoneNumber.toLowerCase().contains(query);
      }).toList();
    }
    setState(() {});
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
      _filterUsers();
    }
  }

  Future<void> _approveUser(User user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Approve User',
      message: 'Approve registration for ${user.username}?',
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
      message: 'Reject registration for ${user.username}?',
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

  void _showUserDetails(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailsSheet(user: user),
    );
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
        // Search bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            ScreenUtils.getPadding(context, 16),
            ScreenUtils.getPadding(context, 12),
            ScreenUtils.getPadding(context, 16),
            ScreenUtils.getPadding(context, 8),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              _searchQuery = value;
              _filterUsers();
            },
            decoration: InputDecoration(
              hintText: 'Search by name, email, hospital, phone...',
              hintStyle: TextStyle(
                fontSize: ScreenUtils.getFontSize(context, 14),
                color: Theme.of(context).hintColor,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: ScreenUtils.getIconSize(context, 22),
                color: AppTheme.lightPrimary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: ScreenUtils.getIconSize(context, 20),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _filterUsers();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
                borderSide: const BorderSide(color: AppTheme.lightPrimary, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: ScreenUtils.getPadding(context, 16),
                vertical: ScreenUtils.getPadding(context, 12),
              ),
            ),
            style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 14)),
          ),
        ),
        // Tab bar header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ScreenUtils.getPadding(context, 16),
            vertical: ScreenUtils.getPadding(context, 4),
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
                    _TabItem(label: 'Pending', count: _filteredPendingUsers.length, color: AppTheme.info),
                    _TabItem(label: 'Registered', count: _filteredRegisteredUsers.length, color: AppTheme.success),
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
                    // Pending Users
                    _CompactUserList(
                      users: _filteredPendingUsers,
                      emptyIcon: Icons.pending_outlined,
                      emptyMessage: _searchQuery.isEmpty 
                          ? 'No pending registrations' 
                          : 'No matching users found',
                      onApprove: _approveUser,
                      onReject: _rejectUser,
                      onTap: _showUserDetails,
                      isPending: true,
                      onRefresh: _loadUsers,
                    ),
                    // Registered Users
                    _CompactUserList(
                      users: _filteredRegisteredUsers,
                      emptyIcon: Icons.people_outlined,
                      emptyMessage: _searchQuery.isEmpty 
                          ? 'No registered users' 
                          : 'No matching users found',
                      onAssignAhus: _assignAhus,
                      onTap: _showUserDetails,
                      isPending: false,
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

class _CompactUserList extends StatelessWidget {
  final List<User> users;
  final IconData emptyIcon;
  final String emptyMessage;
  final Function(User)? onApprove;
  final Function(User)? onReject;
  final Function(User)? onAssignAhus;
  final Function(User) onTap;
  final bool isPending;
  final VoidCallback onRefresh;

  const _CompactUserList({
    required this.users,
    required this.emptyIcon,
    required this.emptyMessage,
    this.onApprove,
    this.onReject,
    this.onAssignAhus,
    required this.onTap,
    required this.isPending,
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
        padding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.getPadding(context, 16),
          vertical: ScreenUtils.getPadding(context, 8),
        ),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return _CompactUserCard(
            user: user,
            onApprove: onApprove,
            onReject: onReject,
            onAssignAhus: onAssignAhus,
            onTap: () => onTap(user),
            isPending: isPending,
          );
        },
      ),
    );
  }
}

class _CompactUserCard extends StatelessWidget {
  final User user;
  final Function(User)? onApprove;
  final Function(User)? onReject;
  final Function(User)? onAssignAhus;
  final VoidCallback onTap;
  final bool isPending;

  const _CompactUserCard({
    required this.user,
    this.onApprove,
    this.onReject,
    this.onAssignAhus,
    required this.onTap,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 8)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 12)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ScreenUtils.getPadding(context, 12),
            vertical: ScreenUtils.getPadding(context, 10),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: ScreenUtils.getIconSize(context, 40),
                height: ScreenUtils.getIconSize(context, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.lightPrimary.withOpacity(0.2),
                      AppTheme.lightPrimary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: AppTheme.lightPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: ScreenUtils.getFontSize(context, 16),
                  ),
                ),
              ),
              SizedBox(width: ScreenUtils.getPadding(context, 12)),
              // Username and hospital hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      user.hospitalName,
                      style: TextStyle(
                        fontSize: ScreenUtils.getFontSize(context, 11),
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Actions
              if (isPending) ...[
                // Approve button
                IconButton(
                  onPressed: onApprove != null ? () => onApprove!(user) : null,
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.success,
                    size: ScreenUtils.getIconSize(context, 24),
                  ),
                  tooltip: 'Approve',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.all(ScreenUtils.getPadding(context, 8)),
                ),
                // Reject button
                IconButton(
                  onPressed: onReject != null ? () => onReject!(user) : null,
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: AppTheme.error,
                    size: ScreenUtils.getIconSize(context, 24),
                  ),
                  tooltip: 'Reject',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.all(ScreenUtils.getPadding(context, 8)),
                ),
              ] else ...[
                // Assign AHUs button
                TextButton.icon(
                  onPressed: onAssignAhus != null ? () => onAssignAhus!(user) : null,
                  icon: Icon(
                    Icons.assignment,
                    size: ScreenUtils.getIconSize(context, 16),
                  ),
                  label: Text(
                    user.assignedAhuIds.isNotEmpty 
                        ? 'AHUs (${user.assignedAhuIds.length})' 
                        : 'Assign',
                    style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 12)),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenUtils.getPadding(context, 12),
                      vertical: ScreenUtils.getPadding(context, 6),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
              // Info icon
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).textTheme.bodySmall?.color,
                size: ScreenUtils.getIconSize(context, 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDetailsSheet extends StatelessWidget {
  final User user;

  const _UserDetailsSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ScreenUtils.getBorderRadius(context, 24)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: ScreenUtils.getPadding(context, 12)),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(ScreenUtils.getPadding(context, 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: ScreenUtils.getIconSize(context, 56),
                      height: ScreenUtils.getIconSize(context, 56),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.lightPrimary.withOpacity(0.2),
                            AppTheme.lightPrimary.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(ScreenUtils.getBorderRadius(context, 14)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: AppTheme.lightPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: ScreenUtils.getFontSize(context, 24),
                        ),
                      ),
                    ),
                    SizedBox(width: ScreenUtils.getPadding(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: TextStyle(
                              fontSize: ScreenUtils.getFontSize(context, 20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user.status == UserStatus.active)
                            Container(
                              margin: EdgeInsets.only(top: ScreenUtils.getSpacing(context, 6)),
                              padding: EdgeInsets.symmetric(
                                horizontal: ScreenUtils.getPadding(context, 8),
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: ScreenUtils.getFontSize(context, 11),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ScreenUtils.getSpacing(context, 20)),
                // Details
                _DetailItem(icon: Icons.email_outlined, label: 'Email', value: user.email),
                _DetailItem(icon: Icons.phone_outlined, label: 'Phone', value: user.phoneNumber),
                _DetailItem(icon: Icons.local_hospital_outlined, label: 'Hospital', value: user.hospitalName),
                if (user.assignedAhuIds.isNotEmpty) ...[
                  SizedBox(height: ScreenUtils.getSpacing(context, 12)),
                  Text(
                    'Assigned AHUs (${user.assignedAhuIds.length})',
                    style: TextStyle(
                      fontSize: ScreenUtils.getFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightPrimary,
                    ),
                  ),
                  SizedBox(height: ScreenUtils.getSpacing(context, 8)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.assignedAhuIds.map((id) => Chip(
                      avatar: Icon(Icons.ac_unit, size: 14, color: AppTheme.lightPrimary),
                      label: Text(id, style: TextStyle(fontSize: ScreenUtils.getFontSize(context, 12))),
                      backgroundColor: AppTheme.lightPrimary.withOpacity(0.1),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
                SizedBox(height: ScreenUtils.getSpacing(context, 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ScreenUtils.getSpacing(context, 12)),
      child: Row(
        children: [
          Icon(
            icon,
            size: ScreenUtils.getIconSize(context, 20),
            color: AppTheme.lightPrimary,
          ),
          SizedBox(width: ScreenUtils.getPadding(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 11),
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ScreenUtils.getFontSize(context, 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
