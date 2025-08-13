import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  static const routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Add debug print
    print('Dashboard arguments: ${ModalRoute.of(context)?.settings.arguments}');

    final userData = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final firstName = userData['name']?.toString().split(' ')[0] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Hi, $firstName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}