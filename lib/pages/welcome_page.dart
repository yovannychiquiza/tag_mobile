import 'package:flutter/material.dart';
import '../components/menu_card.dart';
import '../store/auth_store.dart';
import '../constants/roles.dart';

class WelcomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const WelcomePage({super.key, this.onNavigate});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final AuthStore _authStore = AuthStore();

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
              
              // User info display
              _buildUserInfo(),
              
              const SizedBox(height: 16),
              
              Text(
                'Your smart school bus tracking companion',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Menu Options - Role-based functional features
              Expanded(
                child: _buildRoleBasedMenuCards(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _authStore.user;
    
    if (user == null) {
      return const SizedBox.shrink();
    }

    final name = user['name'] ?? '';
    final lastName = user['lastName'] ?? '';
    final login = user['login'] ?? '';
    final roleName = user['role'] ?? '';
    final roleId = user['roleId'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // User avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // User details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name $lastName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'User: $login',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(roleId),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        roleName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Color _getRoleColor(int? roleId) {
    switch (roleId) {
      case 1: // Admin
        return Colors.purple;
      case 2: // Tracker
        return Colors.green;
      case 3: // Driver
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRoleBasedMenuCards() {
    final user = _authStore.user;
    final roleId = user?['roleId'] as int?;
    
    List<Widget> menuCards = [];
    
    // Show Track Bus for drivers
    if (hasPageAccess(roleId, 'bus_tracking')) {
      menuCards.add(
        MenuCard(
          icon: Icons.directions_bus,
          title: 'Track Bus',
          subtitle: 'Real-time location',
          color: Colors.blue,
          onTap: () {
            widget.onNavigate?.call(1); // Navigate to bus tracking tab
          },
        ),
      );
    }
    
    // Show Advanced Tracker for trackers
    if (hasPageAccess(roleId, 'tracker')) {
      menuCards.add(
        MenuCard(
          icon: Icons.gps_fixed,
          title: 'Advanced Tracker',
          subtitle: 'Smart ETA & alerts',
          color: Colors.green,
          onTap: () {
            widget.onNavigate?.call(3); // Navigate to advanced tracker tab
          },
        ),
      );
    }
    
    // If no cards available, show a message
    if (menuCards.isEmpty) {
      menuCards.add(
        Container(
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text(
              'No features available for your role',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }
    
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: menuCards,
    );
  }
}