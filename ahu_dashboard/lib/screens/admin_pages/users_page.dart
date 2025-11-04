import 'package:flutter/material.dart';
import '../../services/aws_admin_service.dart';
import '../../widgets/admin/create_user_dialog.dart';
import '../../widgets/admin/edit_user_dialog.dart';
import '../../widgets/admin/device_assignment_dialog.dart';

/// User Management Page
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final AWSAdminService _awsService = AWSAdminService();
  String _searchQuery = '';
  String? _filterRole;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    final result = await _awsService.listUsers();
    
    if (result['success'] == true && result['data'] != null) {
      final usersData = result['data']['Users'] as List?;
      if (usersData != null) {
        setState(() {
          _users = usersData.map((user) {
            // Parse AWS Cognito user format
            final attributes = (user['Attributes'] as List).fold<Map<String, String>>(
              {},
              (map, attr) => map..[attr['Name']] = attr['Value'],
            );
            
            return {
              'email': user['Username'],
              'displayName': attributes['name'] ?? attributes['email'] ?? 'Unknown',
              'role': attributes['custom:role'] ?? 'client',
              'assignedDevices': (attributes['custom:assigned_devices'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
              'enabled': user['Enabled'] ?? true,
              'status': user['UserStatus'] ?? 'UNKNOWN',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _users = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2640),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity( 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage users, roles, and device assignments',
                      style: TextStyle(
                        color: Colors.white.withOpacity( 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Search & Filter
              Container(
                width: 280,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity( 0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity( 0.4),
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withOpacity( 0.4),
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity( 0.1),
                    width: 1,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _filterRole,
                  hint: Text(
                    'All Roles',
                    style: TextStyle(
                      color: Colors.white.withOpacity( 0.6),
                    ),
                  ),
                  dropdownColor: const Color(0xFF1E2640),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: ['admin', 'client', null].map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role ?? 'All Roles'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterRole = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity( 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateUserDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          
        // Users List
        Expanded(
          child: Container(
            color: const Color(0xFF141B2D),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(48),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2640),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline_rounded,
                                    size: 64,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No users found',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create your first user to get started',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : () {
                        // Filter users
                        final filteredUsers = _users.where((user) {
                          final email = (user['email'] ?? '').toString().toLowerCase();
                          final role = (user['role'] ?? '').toString();

                          // Search filter
                          if (_searchQuery.isNotEmpty && !email.contains(_searchQuery)) {
                            return false;
                          }

                          // Role filter
                          if (_filterRole != null && role != _filterRole) {
                            return false;
                          }

                          return true;
                        }).toList();

                        return ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final userData = filteredUsers[index];
                            return _UserCard(
                              userData: userData,
                              userId: userData['email'],
                              onEdit: () => _showEditUserDialog(userData, userData['email']),
                              onDelete: () => _showDeleteConfirmDialog(userData['email'], userData['email']),
                              onAssignDevices: () => _showDeviceAssignmentDialog(userData, userData['email']),
                            );
                          },
                        );
                      }(),
          ),
        ),
      ],
    );
  }

  void _showCreateUserDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const CreateUserDialog(),
    );
    
    // Reload users if dialog returned true (user created)
    if (result == true) {
      _loadUsers();
    }
  }

  void _showEditUserDialog(Map<String, dynamic> userData, String userId) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        userData: userData,
        userId: userId,
      ),
    );
  }

  void _showDeviceAssignmentDialog(Map<String, dynamic> userData, String userId) {
    showDialog(
      context: context,
      builder: (context) => DeviceAssignmentDialog(
        userData: userData,
        userId: userId,
      ),
    );
  }

  void _showDeleteConfirmDialog(String userId, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user:\n\n$email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await _awsService.deleteUser(email);
                if (context.mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User deleted successfully')),
                    );
                    _loadUsers(); // Reload users list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${result['message']}')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignDevices;

  const _UserCard({
    required this.userData,
    required this.userId,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignDevices,
  });

  @override
  Widget build(BuildContext context) {
    final email = userData['email'] ?? '';
    final role = userData['role'] ?? 'client';
    final displayName = userData['displayName'] ?? email.split('@')[0];
    final isActive = userData['enabled'] ?? true;
    final assignedDevices = (userData['assignedDevices'] as List<dynamic>?) ?? [];
    final status = userData['status'] ?? 'UNKNOWN';
    
    final roleColor = role == 'admin' 
        ? const Color(0xFF3B82F6)
        : const Color(0xFF10B981);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2640),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity( 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                roleColor,
                roleColor.withOpacity( 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            role == 'admin' ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity( 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor.withOpacity( 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: roleColor.withOpacity( 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: roleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity( 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.devices_other_rounded,
                  size: 16,
                  color: Colors.white.withOpacity( 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${assignedDevices.length} device(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity( 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.white.withOpacity( 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity( 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF141B2D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity( 0.1),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: onEdit,
                tooltip: 'Edit User',
                color: Colors.white.withOpacity( 0.8),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF141B2D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity( 0.1),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.devices_rounded, size: 18),
                onPressed: onAssignDevices,
                tooltip: 'Assign Devices',
                color: Colors.white.withOpacity( 0.8),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF141B2D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity( 0.1),
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_rounded, size: 18),
                onPressed: onDelete,
                tooltip: 'Delete User',
                color: const Color(0xFFEF4444),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else {
      return 'Just now';
    }
  }
}


