import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ahu_state.dart';
import '../providers/app_provider.dart';

/// Control panel for AHU operations
class ControlPanel extends StatelessWidget {
  final String ahuId;
  final AhuState? state;
  final bool isOnline;

  const ControlPanel({
    super.key,
    required this.ahuId,
    this.state,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = state?.run ?? false;

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
              'Control Panel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Start/Stop button
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                onPressed: isOnline
                    ? () {
                        final provider = Provider.of<AppProvider>(context, listen: false);
                        provider.toggleAhu(ahuId);
                      }
                    : null,
                icon: Icon(
                  isRunning ? Icons.stop : Icons.play_arrow,
                  size: 32,
                ),
                label: Text(
                  isRunning ? 'STOP SYSTEM' : 'START SYSTEM',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Setpoint controls
            Row(
              children: [
                Expanded(
                  child: _buildSetpointControl(
                    context,
                    icon: Icons.thermostat,
                    label: 'Temperature',
                    value: state?.tempSet ?? 22.0,
                    unit: '°C',
                    min: 15.0,
                    max: 30.0,
                    color: Colors.orange,
                    onChanged: isOnline
                        ? (value) {
                            final provider = Provider.of<AppProvider>(context, listen: false);
                            provider.setTemperature(ahuId, value);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSetpointControl(
                    context,
                    icon: Icons.water_drop,
                    label: 'Humidity',
                    value: state?.humSet ?? 55.0,
                    unit: '%',
                    min: 30.0,
                    max: 80.0,
                    color: Colors.blue,
                    onChanged: isOnline
                        ? (value) {
                            final provider = Provider.of<AppProvider>(context, listen: false);
                            provider.setHumidity(ahuId, value);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetpointControl(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onChanged != null && value > min
                    ? () => onChanged(value - 0.5)
                    : null,
                icon: const Icon(Icons.remove_circle),
                color: color,
                iconSize: 32,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onChanged != null && value < max
                    ? () => onChanged(value + 0.5)
                    : null,
                icon: const Icon(Icons.add_circle),
                color: color,
                iconSize: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


