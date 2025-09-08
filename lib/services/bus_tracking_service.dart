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

  // Calculate ETA to pickup stop (simplified version of the web logic)
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

    // Calculate direct distance and basic ETA
    double distance = calculateDistance(
      busLocation.latitude,
      busLocation.longitude,
      pickupStop.latitude,
      pickupStop.longitude,
    );

    // Simple ETA calculation (can be enhanced with route-based logic)
    double averageSpeed = busLocation.speed > 0 ? busLocation.speed : 30; // km/h
    int etaMinutes = ((distance / averageSpeed) * 60).round();

    return {
      'distanceToStop': double.parse(distance.toStringAsFixed(1)),
      'etaMinutes': etaMinutes,
      'nextStopName': 'Stop ${pickupStop.pointOrder ?? pickupStop.id}',
    };
  }

  void dispose() {
    stopTracking();
  }
}