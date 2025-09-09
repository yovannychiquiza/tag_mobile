import 'package:flutter/material.dart';
import '../components/menu_card.dart';
import '../store/auth_store.dart';

class WelcomePage extends StatelessWidget {
  final Function(int)? onNavigate;
  
  const WelcomePage({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.directions_bus, size: 28),
            SizedBox(width: 8),
            Text(
              'BusTracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
        actions: [
          // Logout button available for all users including drivers
          IconButton(
            onPressed: () async {
              final authStore = AuthStore();
              await authStore.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Welcome Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_bus,
                  size: 80,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Welcome to BusTracker! 🚌',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Your smart school bus tracking companion',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Menu Options
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    MenuCard(
                      icon: Icons.directions_bus,
                      title: 'Track Bus',
                      subtitle: 'Real-time location',
                      color: Colors.blue,
                      onTap: () {
                        onNavigate?.call(1); // Navigate to bus tracking tab
                      },
                    ),
                    MenuCard(
                      icon: Icons.gps_fixed,
                      title: 'Advanced Tracker',
                      subtitle: 'Smart ETA & alerts',
                      color: Colors.green,
                      onTap: () {
                        onNavigate?.call(3); // Navigate to advanced tracker tab
                      },
                    ),
                    MenuCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      subtitle: 'Bus alerts',
                      color: Colors.orange,
                      onTap: () {
                        // TODO: Navigate to notifications
                      },
                    ),
                    MenuCard(
                      icon: Icons.info,
                      title: 'About',
                      subtitle: 'App information',
                      color: Colors.purple,
                      onTap: () {
                        // TODO: Navigate to about
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}