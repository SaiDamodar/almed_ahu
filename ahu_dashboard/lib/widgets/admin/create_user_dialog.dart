import 'package:flutter/material.dart';
import '../../providers/app_provider.dart';
import '../../services/aws_admin_service.dart';
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
  final _tempPasswordController = TextEditingController();
  String _selectedRole = 'client';
  List<String> _selectedDevices = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _accessKeyController.dispose();
    _tempPasswordController.dispose();
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
                
                // Temporary Password (for AWS Cognito)
                TextFormField(
                  controller: _tempPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Temporary Password *',
                    hintText: 'TempPass123!',
                    prefixIcon: Icon(Icons.lock_rounded),
                    helperText: 'User will set permanent password on first login',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Temporary password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
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
      final awsService = AWSAdminService();
      final result = await awsService.createUser(
        email: _emailController.text.trim(),
        tempPassword: _tempPasswordController.text.trim(),
        role: _selectedRole,
        displayName: _nameController.text.trim().isEmpty 
            ? null 
            : _nameController.text.trim(),
        assignedDevices: _selectedRole == 'client' ? _selectedDevices : null,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (result['needsSetup'] == true) {
          // AWS credentials not configured - show instructions
          _showAWSCLIInstructions();
        } else if (result['success'] == true) {
          // Success - user created
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ User created successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Error occurred
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['message']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showAWSCLIInstructions() {
    final email = _emailController.text.trim();
    final tempPassword = _tempPasswordController.text.trim();
    final role = _selectedRole;
    final devicesStr = _selectedDevices.join(',');
    final displayName = _nameController.text.trim();
    
    // Generate AWS CLI command
    // AWS Cognito configuration (from setup)
    const userPoolId = 'ap-south-1_LSTShtM9R';
    const region = 'ap-south-1';
    
    String command = '''
aws cognito-idp admin-create-user \\
  --user-pool-id $userPoolId \\
  --username $email \\
  --user-attributes \\
    Name=email,Value=$email \\
    Name=email_verified,Value=true \\
    Name=custom:role,Value=$role''';

    if (devicesStr.isNotEmpty) {
      command += ' \\\n    Name=custom:assigned_devices,Value="$devicesStr"';
    }
    
    if (displayName.isNotEmpty) {
      command += ' \\\n    Name=name,Value="$displayName"';
    }
    
    command += ''' \\
  --temporary-password "$tempPassword" \\
  --message-action SUPPRESS \\
  --region $region''';

    // Show dialog with instructions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Text('Create User via AWS'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User creation requires AWS Console or AWS CLI. Use one of the options below:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Option 1: AWS Console
              ExpansionTile(
                title: const Text('Option 1: AWS Console (Easiest)'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Go to:'),
                        const SizedBox(height: 8),
                        SelectableText(
                          'https://console.aws.amazon.com/cognito/v2/idp/user-pools?region=$region',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 16),
                        Text('2. Click on: $userPoolId'),
                        const SizedBox(height: 8),
                        const Text('3. Click "Users" → "Create user"'),
                        const SizedBox(height: 8),
                        const Text('4. Fill in:'),
                        Text('   - Email: $email'),
                        Text('   - Password: $tempPassword'),
                        const Text('   - Mark email verified: ✅'),
                        const SizedBox(height: 8),
                        const Text('5. Add custom attributes:'),
                        Text('   - custom:role = $role'),
                        if (devicesStr.isNotEmpty)
                          Text('   - custom:assigned_devices = $devicesStr'),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Option 2: AWS CLI
              ExpansionTile(
                title: const Text('Option 2: AWS CLI (Faster)'),
                initiallyExpanded: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Copy and run this command:'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: SelectableText(
                            command,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'After creating, set permanent password:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: SelectableText(
                            'aws cognito-idp admin-set-user-password \\\n'
                            '  --user-pool-id $userPoolId \\\n'
                            '  --username $email \\\n'
                            '  --password "$tempPassword" \\\n'
                            '  --permanent \\\n'
                            '  --region $region',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.white,
                            ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close create dialog too
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Instructions shown - create user via AWS Console/CLI'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}


