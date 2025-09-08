import 'dart:convert';
import 'auth_service.dart';

class UserSettingsService {
  static Future<UserSettings?> getUserSettings() async {
    try {
      final response = await AuthService.authenticatedRequest(
        'GET',
        '/user-settings',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserSettings.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load user settings');
      }
    } catch (e) {
      throw Exception('Error fetching user settings: ${e.toString()}');
    }
  }

  static Future<void> updateUserSettings(UserSettingsUpdate settings) async {
    try {
      final response = await AuthService.authenticatedRequest(
        'PUT',
        '/user-settings',
        body: settings.toJson(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update user settings');
      }
    } catch (e) {
      throw Exception('Error updating user settings: ${e.toString()}');
    }
  }

  static Future<void> deleteUserSettings() async {
    try {
      final response = await AuthService.authenticatedRequest(
        'DELETE',
        '/user-settings',
      );

      if (response.statusCode != 200 && response.statusCode != 404) {
        throw Exception('Failed to delete user settings');
      }
    } catch (e) {
      throw Exception('Error deleting user settings: ${e.toString()}');
    }
  }
}

class UserSettings {
  final int? id;
  final int? routePathId;
  final int? pickupStopId;
  final double? homeLat;
  final double? homeLng;
  final String? routeName;
  final String? routeDescription;
  final DateTime? updatedAt;

  UserSettings({
    this.id,
    this.routePathId,
    this.pickupStopId,
    this.homeLat,
    this.homeLng,
    this.routeName,
    this.routeDescription,
    this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['Id'],
      routePathId: json['RoutePathId'],
      pickupStopId: json['PickupStopId'],
      homeLat: json['HomeLat']?.toDouble(),
      homeLng: json['HomeLng']?.toDouble(),
      routeName: json['route_name'],
      routeDescription: json['route_description'],
      updatedAt: json['UpdatedAt'] != null 
          ? DateTime.parse(json['UpdatedAt']) 
          : null,
    );
  }
}

class UserSettingsUpdate {
  final int? routePathId;
  final int? pickupStopId;
  final double? homeLat;
  final double? homeLng;

  UserSettingsUpdate({
    this.routePathId,
    this.pickupStopId,
    this.homeLat,
    this.homeLng,
  });

  Map<String, dynamic> toJson() {
    return {
      'RoutePathId': routePathId,
      'PickupStopId': pickupStopId,
      'HomeLat': homeLat,
      'HomeLng': homeLng,
    };
  }
}