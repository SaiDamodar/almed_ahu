import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../providers/app_provider.dart';
import 'package:provider/provider.dart';

class DeviceAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const DeviceAssignmentDialog({
    super.key,
    required this.userData,
    required this.userId,
  });

  @override
  State<DeviceAssignmentDialog> createState() => _DeviceAssignmentDialogState();
}

class _DeviceAssignmentDialogState extends State<DeviceAssignmentDialog> {
  final FirebaseService _firebaseService = FirebaseService();
  List<String> _selectedDevices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDevices = List<String>.from(
      (widget.userData['assignedDevices'] as List<dynamic>?) ?? [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.userData['role'] ?? 'client';
    final email = widget.userData['email'] ?? widget.userId;
    
    if (role == 'admin') {
      return AlertDialog(
        title: const Text('Device Assignment'),
        content: const Text('Admin users have access to all devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }
    
    return AlertDialog(
      title: const Text('Assign Devices'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User: $email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Select devices to assign:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Consumer<AppProvider>(
                builder: (context, provider, child) {
                  final devices = provider.ahuUnits;
                  
                  if (devices.isEmpty) {
                    return const Center(
                      child: Text('No devices available'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isSelected = _selectedDevices.contains(device.id);
                      
                      return CheckboxListTile(
                        title: Text(device.name),
                        subtitle: Text('${device.id} • ${device.site}/${device.room}'),
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
                  );
                },
              ),
            ),
            if (_selectedDevices.isEmpty)
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _selectedDevices.isEmpty) 
              ? null 
              : _updateDevices,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _updateDevices() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _firebaseService.updateUser(
        email: widget.userData['email'] ?? widget.userId,
        assignedDevices: _selectedDevices,
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devices assigned successfully'),
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

