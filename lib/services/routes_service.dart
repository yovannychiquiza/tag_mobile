import 'dart:convert';
import 'http_client.dart';

class RoutesService {
  static Future<List<RoutePath>> getRoutes() async {
    try {
      final response = await HttpClient.get('/routepath');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RoutePath.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load routes');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<RoutePoint>> getRoutePoints(int routeId) async {
    try {
      final response = await HttpClient.get('/routepath/$routeId/points');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RoutePoint.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load route points');
      }
    } catch (e) {
      rethrow;
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
  final String? pointName;
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
    this.pointName,
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
      pointName: json['PointName'],
      isStop: json['IsStop'] ?? false,
      averageStopTime: json['AverageStopTime'],
      averageSpeed: json['AverageSpeed']?.toDouble(),
      timeToNext: json['TimeToNext'],
      distanceToNext: json['DistanceToNext']?.toDouble(),
    );
  }
}