import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';

class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const EditUserDialog({
    super.key,
    required this.userData,
    required this.userId,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool? _isActive;
  List<String> _selectedDevices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userData['displayName'] ?? '';
    _accessKeyController.text = widget.userData['accessKey'] ?? '';
    _isActive = widget.userData['isActive'] ?? true;
    _selectedDevices = List<String>.from(
      (widget.userData['assignedDevices'] as List<dynamic>?) ?? [],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accessKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.userData['role'] ?? 'client';
    final isClient = role == 'client';
    
    return AlertDialog(
      title: Text('Edit User: ${widget.userData['email'] ?? ''}'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Active Status
                SwitchListTile(
                  title: const Text('Active Account'),
                  subtitle: Text(_isActive == true 
                      ? 'User can sign in' 
                      : 'User account is deactivated'),
                  value: _isActive ?? true,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Access Key (for clients)
                if (isClient) ...[
                  TextFormField(
                    controller: _accessKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Access Key',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Device Assignment
                  Consumer<AppProvider>(
                    builder: (context, provider, child) {
                      final devices = provider.ahuUnits;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned Devices',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: devices.isEmpty
                                ? const Center(
                                    child: Text('No devices available'),
                                  )
                                : ListView.builder(
                                    itemCount: devices.length,
                                    itemBuilder: (context, index) {
                                      final device = devices[index];
                                      final isSelected = 
                                          _selectedDevices.contains(device.id);
                                      
                                      return CheckboxListTile(
                                        title: Text(device.name),
                                        subtitle: Text(device.id),
                                        value: isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedDevices.add(device.id);
                                            } else {
                                              _selectedDevices.remove(device.id);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                          if (isClient && _selectedDevices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'At least one device is required for clients',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateUser,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateUser() async {
    final role = widget.userData['role'] ?? 'client';
    final isClient = role == 'client';
    
    if (isClient && _selectedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one device is required for client accounts'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _firebaseService.updateUser(
        email: widget.userData['email'] ?? widget.userId,
        displayName: _nameController.text.trim().isEmpty 
            ? null 
            : _nameController.text.trim(),
        accessKey: isClient && _accessKeyController.text.trim().isNotEmpty
            ? _accessKeyController.text.trim()
            : null,
        assignedDevices: isClient ? _selectedDevices : null,
        isActive: _isActive,
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}


