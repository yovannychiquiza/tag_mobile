import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class BusLocation {
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime timestamp;

  BusLocation({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });

  factory BusLocation.fromJson(Map<String, dynamic> json) {
    return BusLocation(
      latitude: json['Latitude']?.toDouble() ?? 0.0,
      longitude: json['Longitude']?.toDouble() ?? 0.0,
      speed: json['Speed']?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
  }
}

class BusData {
  final String busNumber;
  final String route;
  final BusLocation? currentLocation;
  final double distanceToStop;
  final int etaMinutes;
  final String nextStop;

  BusData({
    required this.busNumber,
    required this.route,
    this.currentLocation,
    required this.distanceToStop,
    required this.etaMinutes,
    required this.nextStop,
  });
}

class RoutePoint {
  final int id;
  final double latitude;
  final double longitude;
  final bool isStop;
  final int? pointOrder;
  final int? timeToNext;
  final double? distanceToNext;
  final double? averageSpeed;
  final int? averageStopTime;

  RoutePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.isStop,
    this.pointOrder,
    this.timeToNext,
    this.distanceToNext,
    this.averageSpeed,
    this.averageStopTime,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      id: json['Id'] ?? 0,
      latitude: json['Latitude']?.toDouble() ?? 0.0,
      longitude: json['Longitude']?.toDouble() ?? 0.0,
      isStop: json['IsStop'] ?? false,
      pointOrder: json['PointOrder'],
      timeToNext: json['TimeToNext'],
      distanceToNext: json['DistanceToNext']?.toDouble(),
      averageSpeed: json['AverageSpeed']?.toDouble(),
      averageStopTime: json['AverageStopTime'],
    );
  }

  LatLng get latLng => LatLng(latitude, longitude);
}

class BusTrackingService {
  static const String baseUrl = 'http://localhost:8000'; // Replace with your API URL
  Timer? _trackingTimer;
  StreamController<BusData>? _busDataController;

  Stream<BusData>? get busDataStream => _busDataController?.stream;

  void startTracking({int intervalSeconds = 10}) {
    _busDataController = StreamController<BusData>.broadcast();
    
    _trackingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _updateBusLocation();
    });
    
    // Initial update
    _updateBusLocation();
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _busDataController?.close();
  }

  Future<void> _updateBusLocation() async {
    try {
      // Simulate API call - replace with actual API endpoints
      final busData = await _fetchBusData();
      _busDataController?.add(busData);
    } catch (e) {
      print('Error updating bus location: $e');
    }
  }

  Future<BusData> _fetchBusData() async {
    // This is a simulation - replace with actual API calls
    // For now, return mock data similar to the web version
    return BusData(
      busNumber: 'Bus 101',
      route: 'Route East',
      currentLocation: BusLocation(
        latitude: 45.2733 + (Random().nextDouble() - 0.5) * 0.01,
        longitude: -66.0633 + (Random().nextDouble() - 0.5) * 0.01,
        speed: 20 + Random().nextDouble() * 20,
        timestamp: DateTime.now(),
      ),
      distanceToStop: 0.5 + Random().nextDouble() * 2,
      etaMinutes: 3 + Random().nextInt(10),
      nextStop: 'Stop ${Random().nextInt(10) + 1}',
    );
  }

  // Utility function to calculate distance between two points
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Calculate ETA to pickup stop using route-based logic with database variables
  static Map<String, dynamic> calculateETAToPickupStop(
    BusLocation busLocation,
    List<RoutePoint> routePoints,
    int? userPickupStopId,
  ) {
    if (userPickupStopId == null || routePoints.isEmpty) {
      return {
        'distanceToStop': 0.0,
        'etaMinutes': 0,
        'nextStopName': 'Unknown',
      };
    }

    // Find user's pickup stop
    RoutePoint? pickupStop;
    try {
      pickupStop = routePoints.firstWhere((point) => point.id == userPickupStopId && point.isStop);
    } catch (e) {
      return {
        'distanceToStop': 0.0,
        'etaMinutes': 0,
        'nextStopName': 'Stop not found',
      };
    }

    // Sort route points by order
    final sortedPoints = [...routePoints];
    sortedPoints.sort((a, b) {
      if (a.pointOrder == null && b.pointOrder == null) return a.id.compareTo(b.id);
      if (a.pointOrder == null) return 1;
      if (b.pointOrder == null) return -1;
      return a.pointOrder!.compareTo(b.pointOrder!);
    });

    // Find current bus position in route (closest point)
    RoutePoint closestPoint = sortedPoints.first;
    double minDistance = calculateDistance(
      busLocation.latitude,
      busLocation.longitude,
      closestPoint.latitude,
      closestPoint.longitude
    );
    int currentPointIndex = 0;

    for (int i = 0; i < sortedPoints.length; i++) {
      final point = sortedPoints[i];
      final distance = calculateDistance(
        busLocation.latitude,
        busLocation.longitude,
        point.latitude,
        point.longitude
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
        currentPointIndex = i;
      }
    }

    // Find pickup stop index
    final pickupStopIndex = sortedPoints.indexWhere((point) => point.id == userPickupStopId);
    if (pickupStopIndex == -1 || currentPointIndex > pickupStopIndex) {
      return {
        'distanceToStop': 0.0,
        'etaMinutes': 0,
        'nextStopName': 'Bus has passed this stop',
      };
    }

    // Calculate route-based ETA using database variables
    double totalTime = 0;
    double totalDistance = 0;

    // Add time from bus to first route point
    final distanceToCurrentPoint = calculateDistance(
      busLocation.latitude,
      busLocation.longitude,
      closestPoint.latitude,
      closestPoint.longitude
    );
    if (distanceToCurrentPoint > 0.05) {
      final averageSpeed = closestPoint.averageSpeed ?? 30;
      totalTime += (distanceToCurrentPoint / averageSpeed) * 60;
      totalDistance += distanceToCurrentPoint;
    }

    // Calculate time through all remaining points until pickup stop
    for (int i = currentPointIndex; i < pickupStopIndex; i++) {
      final currentPoint = sortedPoints[i];
      final nextPoint = i + 1 < sortedPoints.length ? sortedPoints[i + 1] : null;

      if (nextPoint != null) {
        // Use pre-calculated distanceToNext from database if available
        final segmentDistance = currentPoint.distanceToNext ?? calculateDistance(
          currentPoint.latitude, currentPoint.longitude,
          nextPoint.latitude, nextPoint.longitude
        );

        // Use timeToNext if available, otherwise calculate using averageSpeed
        if (currentPoint.timeToNext != null) {
          totalTime += currentPoint.timeToNext!.toDouble();
        } else {
          final speed = currentPoint.averageSpeed ?? 30;
          totalTime += (segmentDistance / speed) * 60;
        }

        totalDistance += segmentDistance;
      }

      // Add stop time if this is a stop (but not for the final pickup stop)
      if (currentPoint.isStop && i < pickupStopIndex - 1) {
        totalTime += (currentPoint.averageStopTime ?? 2).toDouble();
      }
    }

    return {
      'distanceToStop': double.parse(totalDistance.toStringAsFixed(1)),
      'etaMinutes': totalTime.round(),
      'nextStopName': pickupStop.pointOrder != null
        ? 'Stop ${pickupStop.pointOrder}'
        : 'Stop ${pickupStop.id}',
    };
  }

  void dispose() {
    stopTracking();
  }
}