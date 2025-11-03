import 'package:flutter/material.dart';

/// OTA Page - Firmware deployments
class OTAPage extends StatelessWidget {
  const OTAPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.system_update_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity( 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'OTA Deployment',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity( 0.6),
            ),
          ),
        ],
      ),
    );
  }
}


