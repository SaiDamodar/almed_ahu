import 'package:flutter/material.dart';

/// Notifications Page - Alert configuration, push sender
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity( 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Notifications',
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


