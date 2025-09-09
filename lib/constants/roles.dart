// Role constants for mobile app - matching database IDs
class Roles {
  static const int admin = 1;    // Admin user (not used in mobile)
  static const int tracker = 2;  // Person that tracks the bus
  static const int driver = 3;   // Bus Driver
}

class RoleNames {
  static const Map<int, String> names = {
    Roles.admin: 'Admin',
    Roles.tracker: 'Tracker',
    Roles.driver: 'Driver',
  };
}

class RolePermissions {
  // Mobile app permissions - only Tracker and Driver roles
  static const Map<int, List<String>> permissions = {
    Roles.tracker: ['tracker', 'settings'],  // Tracker can access tracking and settings
    Roles.driver: ['bus_tracking'],          // Driver can only access bus tracking
  };
}

// Helper functions for role checking
bool isTracker(int? roleId) {
  return roleId == Roles.tracker;
}

bool isDriver(int? roleId) {
  return roleId == Roles.driver;
}

bool isAdmin(int? roleId) {
  return roleId == Roles.admin;
}

String getRoleName(int? roleId) {
  return RoleNames.names[roleId] ?? 'Unknown';
}

bool hasPageAccess(int? roleId, String page) {
  if (roleId == null) return false;
  final permissions = RolePermissions.permissions[roleId];
  return permissions != null && permissions.contains(page);
}

// Get available navigation items based on role
List<NavigationItem> getNavigationItems(int? roleId) {
  final items = <NavigationItem>[];
  
  if (roleId == null) return items;

  // Always show Home
  items.add(NavigationItem(
    index: 0,
    icon: 'home',
    label: 'Home',
    page: 'home',
  ));

  // Show based on role permissions
  if (hasPageAccess(roleId, 'tracker')) {
    items.add(NavigationItem(
      index: 3,
      icon: 'gps_fixed',
      label: 'Smart Track',
      page: 'tracker',
    ));
  }

  if (hasPageAccess(roleId, 'bus_tracking')) {
    items.add(NavigationItem(
      index: 1,
      icon: 'directions_bus',
      label: 'Track Bus',
      page: 'bus_tracking',
    ));
  }

  if (hasPageAccess(roleId, 'settings')) {
    items.add(NavigationItem(
      index: 2,
      icon: 'settings',
      label: 'Settings',
      page: 'settings',
    ));
  }

  return items;
}

class NavigationItem {
  final int index;
  final String icon;
  final String label;
  final String page;

  NavigationItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.page,
  });
}