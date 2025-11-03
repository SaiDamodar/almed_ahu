import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedRole = 'client';
  List<String> _selectedDevices = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _accessKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New User'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Invalid email format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Display Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'John Doe',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (value) => null,
                ),
                const SizedBox(height: 16),
                
                // Role
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    prefixIcon: Icon(Icons.work_rounded),
                  ),
                  items: ['admin', 'client'].map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                      if (_selectedRole == 'admin') {
                        _selectedDevices.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Access Key (required for client)
                if (_selectedRole == 'client') ...[
                  TextFormField(
                    controller: _accessKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Access Key *',
                      hintText: 'Enter access key',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    validator: (value) {
                      if (_selectedRole == 'client' && 
                          (value == null || value.isEmpty)) {
                        return 'Access key is required for client accounts';
                      }
                      return null;
                    },
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
                            'Assigned Devices *',
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
                          if (_selectedRole == 'client' && 
                              _selectedDevices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'At least one device is required',
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
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check Firebase first
    if (!_firebaseService.isFirebaseInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firebase not initialized. Please wait or refresh the page.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (_selectedRole == 'client' && _selectedDevices.isEmpty) {
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
      await _firebaseService.createUser(
        email: _emailController.text.trim(),
        role: _selectedRole,
        accessKey: _selectedRole == 'client' 
            ? _accessKeyController.text.trim() 
            : null,
        assignedDevices: _selectedRole == 'client' ? _selectedDevices : null,
        displayName: _nameController.text.trim().isEmpty 
            ? null 
            : _nameController.text.trim(),
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User created successfully'),
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


