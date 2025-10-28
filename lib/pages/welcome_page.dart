import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../store/auth_store.dart';
import '../constants/roles.dart';
import '../theme/app_colors.dart';

class WelcomePage extends StatefulWidget {
  final Function(int)? onNavigate;

  const WelcomePage({super.key, this.onNavigate});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  final AuthStore _authStore = AuthStore();
  String _version = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadVersion();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${packageInfo.version}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Modern Header
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.directions_bus_rounded, size: 32, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'BusTracker',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User info card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildModernUserInfo(),
                  ),

                  const SizedBox(height: 20),

                  // Content Area
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              'Quick Access',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Menu Cards
                            Expanded(
                              child: _buildModernMenuCards(),
                            ),

                            // Version Badge
                            if (_version.isNotEmpty)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(26),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _version,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernUserInfo() {
    final user = _authStore.user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final name = user['name'] ?? '';
    final lastName = user['lastName'] ?? '';
    final roleName = user['role'] ?? '';
    final roleId = user['roleId'] as int?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Modern avatar with gradient
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(51),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${name.isNotEmpty ? name[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$name $lastName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(roleId).withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleName,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getRoleColor(roleId),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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
        return AppColors.secondary;
      case 3: // Driver
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  Widget _buildModernMenuCards() {
    final user = _authStore.user;
    final roleId = user?['roleId'] as int?;

    List<Widget> menuCards = [];

    // Show Track Bus for drivers
    if (hasPageAccess(roleId, 'bus_tracking')) {
      menuCards.add(
        _buildModernCard(
          icon: Icons.directions_bus_rounded,
          title: 'Track Bus',
          subtitle: 'Real-time location tracking',
          gradient: AppColors.primaryGradient,
          onTap: () => widget.onNavigate?.call(1),
        ),
      );
    }

    // Show Advanced Tracker for trackers
    if (hasPageAccess(roleId, 'tracker')) {
      menuCards.add(
        _buildModernCard(
          icon: Icons.gps_fixed_rounded,
          title: 'Smart Track',
          subtitle: 'Smart ETA & live alerts',
          gradient: const LinearGradient(
            colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
          ),
          onTap: () => widget.onNavigate?.call(3),
        ),
      );
    }

    // If no cards available, show a message
    if (menuCards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 60, color: Color(0xFFBDBDBD)),
            SizedBox(height: 16),
            Text(
              'No features available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF757575),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Contact admin for access',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.95,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: menuCards,
      ),
    );
  }

  Widget _buildModernCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
