import 'package:flutter/material.dart';

class NavigationDrawerWidget extends StatelessWidget {
  final List<dynamic> navigationItems;
  final Function(int) onSelectItem;

  const NavigationDrawerWidget({
    super.key,
    required this.navigationItems,
    required this.onSelectItem,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'settings':
        return Icons.settings;
      case 'gps_fixed':
        return Icons.gps_fixed;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Bus Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ...navigationItems.map((item) {
            final int index = navigationItems.indexOf(item);
            return ListTile(
              leading: Icon(_getIconData(item.icon)),
              title: Text(item.label),
              onTap: () {
                onSelectItem(index);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}
