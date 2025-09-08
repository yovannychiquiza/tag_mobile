import 'dart:convert';
import 'auth_service.dart';

class RoutesService {
  static Future<List<RoutePath>> getRoutes() async {
    try {
      final response = await AuthService.authenticatedRequest(
        'GET',
        '/routepath',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RoutePath.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load routes');
      }
    } catch (e) {
      throw Exception('Error fetching routes: ${e.toString()}');
    }
  }

  static Future<List<RoutePoint>> getRoutePoints(int routeId) async {
    try {
      final response = await AuthService.authenticatedRequest(
        'GET',
        '/routepath/$routeId/points',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RoutePoint.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load route points');
      }
    } catch (e) {
      throw Exception('Error fetching route points: ${e.toString()}');
    }
  }
}

class RoutePath {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;

  RoutePath({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  factory RoutePath.fromJson(Map<String, dynamic> json) {
    return RoutePath(
      id: json['Id'],
      name: json['Name'],
      description: json['Description'],
      createdAt: DateTime.parse(json['CreatedAt']),
    );
  }
}

class RoutePoint {
  final int id;
  final int routePathId;
  final double latitude;
  final double longitude;
  final int? pointOrder;
  final bool isStop;
  final int? averageStopTime;
  final double? averageSpeed;
  final int? timeToNext;
  final double? distanceToNext;

  RoutePoint({
    required this.id,
    required this.routePathId,
    required this.latitude,
    required this.longitude,
    this.pointOrder,
    required this.isStop,
    this.averageStopTime,
    this.averageSpeed,
    this.timeToNext,
    this.distanceToNext,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      id: json['Id'],
      routePathId: json['RoutePathId'],
      latitude: json['Latitude'].toDouble(),
      longitude: json['Longitude'].toDouble(),
      pointOrder: json['PointOrder'],
      isStop: json['IsStop'] ?? false,
      averageStopTime: json['AverageStopTime'],
      averageSpeed: json['AverageSpeed']?.toDouble(),
      timeToNext: json['TimeToNext'],
      distanceToNext: json['DistanceToNext']?.toDouble(),
    );
  }
}