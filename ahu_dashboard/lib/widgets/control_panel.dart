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
            const SizedBox(height: 24),

            // Fan control
            _buildFanControl(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFanControl(BuildContext context) {
    final currentSpeed = state?.fanSpeed ?? 0;  // Default to 0 (OFF) when system not running
    final isFanOn = state?.fan ?? false;  // Fan is OFF until system starts
    final isSystemRunning = state?.run ?? false;

    Color speedColor = Colors.grey;
    if (currentSpeed == 1) speedColor = Colors.green.shade300;
    else if (currentSpeed == 2) speedColor = Colors.green.shade600;
    else if (currentSpeed == 3) speedColor = Colors.green.shade900;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air, color: speedColor, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Fan Control',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current: ${_getFanSpeedLabel(currentSpeed)}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          // Single toggle button - cycles LOW → MID → HIGH → LOW
          // Only enabled when system is running
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (isOnline && isSystemRunning)
                  ? () {
                      final provider = Provider.of<AppProvider>(context, listen: false);
                      provider.toggleFanSpeed(ahuId);
                    }
                  : null,
              icon: Icon(Icons.air, size: 24, color: speedColor),
              label: Text(
                'Toggle Fan Speed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: speedColor,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: speedColor.withOpacity(0.1),
                foregroundColor: speedColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: speedColor, width: 2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Speed indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSystemRunning || currentSpeed == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                )
              else ...[
                _FanSpeedIndicator(label: 'LOW', speed: 1, isActive: currentSpeed == 1),
                const SizedBox(width: 8),
                _FanSpeedIndicator(label: 'MID', speed: 2, isActive: currentSpeed == 2),
                const SizedBox(width: 8),
                _FanSpeedIndicator(label: 'HIGH', speed: 3, isActive: currentSpeed == 3),
              ],
            ],
          ),
          // Show message when system not running
          if (!isSystemRunning) ...[
            const SizedBox(height: 8),
            Text(
              'Fan will turn ON when system starts',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _getFanSpeedLabel(int speed) {
    switch (speed) {
      case 0:
        return 'OFF';
      case 1:
        return 'LOW (5V)';
      case 2:
        return 'MID (9V)';
      case 3:
        return 'HIGH (12V)';
      default:
        return 'OFF';  // Default to OFF (fan off when system not running)
    }
  }
}

class _FanSpeedIndicator extends StatelessWidget {
  final String label;
  final int speed;
  final bool isActive;

  const _FanSpeedIndicator({
    required this.label,
    required this.speed,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green.shade300;
    if (speed == 2) color = Colors.green.shade600;
    if (speed == 3) color = Colors.green.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.white : Colors.grey.shade700,
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


