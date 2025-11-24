import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../models/hospital.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve User'),
        content: Text('Approve registration for ${user.username} (${user.email})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final success = await appProvider.approveUser(user.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'User approved successfully' : 'Failed to approve user'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
      if (success) _loadUsers();
    }
  }

  Future<void> _rejectUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User'),
        content: Text('Reject registration for ${user.username} (${user.email})? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final success = await appProvider.rejectUser(user.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'User rejected' : 'Failed to reject user'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
      if (success) _loadUsers();
    }
  }

  Future<void> _assignAhus(User user) async {
    // Get available AHUs from hospitals
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final hospitals = appProvider.hospitalsList;
    
    final allAhus = <String>[];
    for (final hospital in hospitals) {
      for (final ahu in hospital.allAhus) {
        allAhus.add(ahu.id);
      }
    }

    if (allAhus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No AHU units available'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final selectedAhus = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _AhuSelectionDialog(
        availableAhus: allAhus,
        selectedAhus: user.assignedAhuIds.toSet(),
      ),
    );

    if (selectedAhus == null) return;

    final success = await appProvider.assignAhusToUser(user.id, selectedAhus.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'AHUs assigned successfully' 
              : 'Failed to assign AHUs'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
      if (success) _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Users Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.lightPrimary,
          labelColor: AppTheme.lightPrimary,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (_pendingUsers.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.info,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingUsers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Registered'),
                  if (_registeredUsers.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_registeredUsers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingUsersList(),
                  _buildRegisteredUsersList(),
                ],
              ),
      ),
    );
  }

  Widget _buildPendingUsersList() {
    if (_pendingUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending registrations',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingUsers.length,
        itemBuilder: (context, index) {
          final user = _pendingUsers[index];
          return _UserCard(
            user: user,
            onApprove: () => _approveUser(user),
            onReject: () => _rejectUser(user),
            showActions: true,
          );
        },
      ),
    );
  }

  Widget _buildRegisteredUsersList() {
    if (_registeredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No registered users',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _registeredUsers.length,
        itemBuilder: (context, index) {
          final user = _registeredUsers[index];
          return _UserCard(
            user: user,
            onAssignAhus: () => _assignAhus(user),
            showActions: false,
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onAssignAhus;
  final bool showActions;

  const _UserCard({
    required this.user,
    this.onApprove,
    this.onReject,
    this.onAssignAhus,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.lightPrimary.withOpacity(0.2),
                        AppTheme.lightPrimary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: AppTheme.lightPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
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
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                    ],
                  ),
                ),
                if (user.status == UserStatus.active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.local_hospital, label: 'Hospital', value: user.hospitalName),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.phone, label: 'Phone', value: user.phoneNumber),
                ],
              ),
            ),
            if (user.assignedAhuIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Assigned AHUs (${user.assignedAhuIds.length})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.assignedAhuIds.map((ahuId) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.lightPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.lightPrimary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ac_unit,
                          size: 14,
                          color: AppTheme.lightPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ahuId,
                          style: TextStyle(
                            color: AppTheme.lightPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (showActions && (onApprove != null || onReject != null)) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onApprove != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                        ),
                      ),
                    ),
                  if (onApprove != null && onReject != null)
                    const SizedBox(width: 12),
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (!showActions && onAssignAhus != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAssignAhus,
                  icon: const Icon(Icons.assignment, size: 18),
                  label: const Text('Assign AHUs'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
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
                    onPressed: () {
                      setState(() {
                        _selectedAhus = Set.from(widget.availableAhus);
                      });
                    },
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedAhus.clear();
                      });
                    },
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

