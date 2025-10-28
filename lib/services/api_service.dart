import 'dart:convert';
import '../config/app_config.dart';
import 'http_client.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;

  // Get all buses
  static Future<List<Bus>> getBuses() async {
    try {
      final response = await HttpClient.get('/bus');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Bus.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load buses');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get buses with current location
  static Future<List<Bus>> getBusesWithLocation() async {
    try {
      final response = await HttpClient.get('/bus/with-location');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Bus.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load buses with location');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Create bus location
  static Future<BusLocation> createBusLocation({
    required int busId,
    required double latitude,
    required double longitude,
    double? speed,
    double? direction,
    bool isActive = true,
  }) async {
    try {
      final response = await HttpClient.post(
        '/bus/$busId/locations',
        body: {
          'BusId': busId,
          'Latitude': latitude,
          'Longitude': longitude,
          'Speed': speed,
          'Direction': direction,
          'IsActive': isActive,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return BusLocation.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create bus location: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get current bus location
  static Future<BusLocation?> getCurrentBusLocation(int busId) async {
    try {
      final response = await HttpClient.get('/bus/$busId/current-location');

      if (response.statusCode == 200) {
        return BusLocation.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null; // No location found
      } else {
        throw Exception('Failed to get current location');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get bus locations history
  static Future<List<BusLocation>> getBusLocations(int busId) async {
    try {
      final response = await HttpClient.get('/bus/$busId/locations');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BusLocation.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load bus locations');
      }
    } catch (e) {
      rethrow;
    }
  }
}

// Data models
class Bus {
  final int id;
  final String busNumber;
  final int? routePathId;
  final String? licensePlate;
  final String? model;
  final int? capacity;
  final bool isActive;
  final BusLocation? currentLocation;

  Bus({
    required this.id,
    required this.busNumber,
    this.routePathId,
    this.licensePlate,
    this.model,
    this.capacity,
    required this.isActive,
    this.currentLocation,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['Id'] ?? json['id'] ?? 0,
      busNumber: json['BusNumber'] ?? json['busNumber'] ?? '',
      routePathId: json['RoutePathId'] ?? json['routePathId'],
      licensePlate: json['LicensePlate'] ?? json['licensePlate'],
      model: json['Model'] ?? json['model'],
      capacity: json['Capacity'] ?? json['capacity'],
      isActive: json['IsActive'] ?? json['isActive'] ?? true,
      currentLocation: json['current_location'] != null 
          ? BusLocation.fromJson(json['current_location']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'BusNumber': busNumber,
      'RoutePathId': routePathId,
      'LicensePlate': licensePlate,
      'Model': model,
      'Capacity': capacity,
      'IsActive': isActive,
    };
  }
}

class BusLocation {
  final int? id;
  final int busId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? direction;
  final bool isActive;
  final DateTime? timestamp;

  BusLocation({
    this.id,
    required this.busId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.direction,
    required this.isActive,
    this.timestamp,
  });

  factory BusLocation.fromJson(Map<String, dynamic> json) {
    return BusLocation(
      id: json['Id'] ?? json['id'],
      busId: json['BusId'] ?? json['busId'] ?? 0,
      latitude: (json['Latitude'] ?? json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['Longitude'] ?? json['longitude'] ?? 0.0).toDouble(),
      speed: json['Speed'] != null ? (json['Speed']).toDouble() : null,
      direction: json['Direction'] != null ? (json['Direction']).toDouble() : null,
      isActive: json['IsActive'] ?? json['isActive'] ?? true,
      timestamp: json['Timestamp'] != null 
          ? DateTime.tryParse(json['Timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BusId': busId,
      'Latitude': latitude,
      'Longitude': longitude,
      'Speed': speed,
      'Direction': direction,
      'IsActive': isActive,
    };
  }
}