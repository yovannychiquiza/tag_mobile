import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferencesService {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _trackingKey = 'tracking_enabled';
  static const String _routeKey = 'route_enabled';
  static const String _centeredKey = 'centered_enabled';

  /// Save notification preference
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  /// Get notification preference (default: true)
  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true; // Default to true
  }

  /// Save tracking preference
  static Future<void> setTrackingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingKey, enabled);
  }

  /// Get tracking preference (default: false)
  static Future<bool> getTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingKey) ?? false; // Default to false
  }

  /// Save route preference
  static Future<void> setRouteEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_routeKey, enabled);
  }

  /// Get route preference (default: false)
  static Future<bool> getRouteEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_routeKey) ?? false; // Default to false
  }

  /// Save centered preference
  static Future<void> setCenteredEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_centeredKey, enabled);
  }

  /// Get centered preference (default: true)
  static Future<bool> getCenteredEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_centeredKey) ?? true; // Default to true
  }

  /// Clear all preferences
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
