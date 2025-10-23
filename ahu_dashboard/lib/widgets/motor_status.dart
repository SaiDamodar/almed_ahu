import 'package:flutter/material.dart';
import '../models/ahu_state.dart';

/// Widget to display motor and component status
class MotorStatus extends StatelessWidget {
  final AhuState? state;

  const MotorStatus({super.key, this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Component Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatusIndicator(
                  icon: Icons.water,
                  label: 'Motor 1 (Drain)',
                  isActive: state?.m1 ?? false,
                  color: Colors.blue,
                ),
                _buildStatusIndicator(
                  icon: Icons.cleaning_services,
                  label: 'Motor 2 (Filter)',
                  isActive: state?.m2 ?? false,
                  color: Colors.purple,
                ),
                _buildStatusIndicator(
                  icon: Icons.ac_unit,
                  label: 'Compressor',
                  isActive: state?.cp ?? false,
                  color: Colors.cyan,
                ),
                _buildStatusIndicator(
                  icon: Icons.whatshot,
                  label: 'Heater',
                  isActive: state?.heater ?? false,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? color : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : Colors.grey,
                ),
              ),
              Text(
                isActive ? 'ACTIVE' : 'IDLE',
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


