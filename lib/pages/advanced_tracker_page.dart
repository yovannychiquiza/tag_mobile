import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../services/api_service.dart';
import '../services/user_settings_service.dart';
import '../services/routes_service.dart';

class AdvancedTrackerPage extends StatefulWidget {
  const AdvancedTrackerPage({super.key});

  @override
  State<AdvancedTrackerPage> createState() => _AdvancedTrackerPageState();
}

class _AdvancedTrackerPageState extends State<AdvancedTrackerPage> {
  // Bus tracking state
  BusData _busData = BusData(
    distance: 0.8,
    eta: 5,
    speed: 25,
    nextStop: 'Loading...',
    busNumber: 'Loading...',
    route: 'Loading...',
    busPos: const LatLng(45.2733, -66.0633), // Default Saint John position
  );
  
  PersonalizedETA _personalizedETA = PersonalizedETA(
    homeToStop: 0,
    busToStop: 0,
    totalETA: 0,
    walkingTime: 0,
    needToLeaveIn: 0,
    pickupStopName: 'Your Stop',
  );

  Bus? _assignedBus;
  LatLng? _userPos;
  bool _isTracking = true;
  bool _notifications = false;
  bool _showRoute = true;
  bool _centerOnBus = true;
  List<RoutePoint> _routePoints = [];
  UserSettings? _userSettings;
  bool _loading = true;
  Timer? _trackingTimer;
  int? _selectedStopId;

  final MapController _mapController = MapController();
  final LatLng _defaultLocation = const LatLng(45.2733, -66.0633);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Radius of the Earth in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Get the closest route point (stop) to the bus
  int? _getClosestPointToBus() {
    if (_assignedBus?.currentLocation == null || _routePoints.isEmpty) {
      return null;
    }

    final busLat = _assignedBus!.currentLocation!.latitude;
    final busLng = _assignedBus!.currentLocation!.longitude;

    // Only check stops, not all route points
    final stops = _routePoints.where((point) => point.isStop).toList();
    if (stops.isEmpty) {
      return null;
    }

    RoutePoint? closestPoint;
    double minDistance = double.infinity;

    for (final point in stops) {
      final distance = _calculateDistance(busLat, busLng, point.latitude, point.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint?.id;
  }

  // Calculate ETA to pickup stop using route points
  ETAResult _calculateETAToPickupStop(
    double busLat, 
    double busLng, 
    List<RoutePoint> routePoints, 
    int? userPickupStopId
  ) {
    if (userPickupStopId == null || routePoints.isEmpty) {
      return ETAResult(distanceToStop: 0, etaMinutes: 0, nextStopName: 'Unknown');
    }

    // Find user's pickup stop in route points
    final pickupStop = routePoints.firstWhere(
      (point) => point.id == userPickupStopId && point.isStop,
      orElse: () => RoutePoint(id: 0, routePathId: 0, latitude: 0, longitude: 0, isStop: false),
    );
    
    if (pickupStop.id == 0) {
      return ETAResult(distanceToStop: 0, etaMinutes: 0, nextStopName: 'Stop not found');
    }

    // Sort route points by order
    final sortedPoints = [...routePoints];
    sortedPoints.sort((a, b) {
      if (a.pointOrder == null && b.pointOrder == null) return a.id.compareTo(b.id);
      if (a.pointOrder == null) return 1;
      if (b.pointOrder == null) return -1;
      return a.pointOrder!.compareTo(b.pointOrder!);
    });

    // Find current bus position in route (closest point to bus)
    RoutePoint closestPoint = sortedPoints.first;
    double minDistance = _calculateDistance(busLat, busLng, closestPoint.latitude, closestPoint.longitude);
    int currentPointIndex = 0;

    for (int i = 0; i < sortedPoints.length; i++) {
      final point = sortedPoints[i];
      final distance = _calculateDistance(busLat, busLng, point.latitude, point.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
        currentPointIndex = i;
      }
    }

    // Find the index of the user's pickup stop in the sorted route
    final pickupStopIndex = sortedPoints.indexWhere((point) => point.id == userPickupStopId);
    if (pickupStopIndex == -1) {
      return ETAResult(distanceToStop: 0, etaMinutes: 0, nextStopName: 'Stop not found in route');
    }

    // If bus has already passed the pickup stop, return 0 ETA
    if (currentPointIndex > pickupStopIndex) {
      return ETAResult(distanceToStop: 0, etaMinutes: 0, nextStopName: 'Bus has passed this stop');
    }

    // Calculate ETA using route-based approach with remaining stops
    double totalTime = 0;
    double totalDistance = 0;

    // Add time from bus to first route point (if bus is not exactly on a route point)
    final distanceToCurrentPoint = _calculateDistance(busLat, busLng, closestPoint.latitude, closestPoint.longitude);
    if (distanceToCurrentPoint > 0.05) { // If more than 50 meters away
      const averageSpeed = 30; // km/h
      totalTime += (distanceToCurrentPoint / averageSpeed) * 60; // Convert to minutes
      totalDistance += distanceToCurrentPoint;
    }

    // Calculate time through all remaining points until pickup stop
    for (int i = currentPointIndex; i < pickupStopIndex; i++) {
      final currentPoint = sortedPoints[i];
      final nextPoint = i + 1 < sortedPoints.length ? sortedPoints[i + 1] : null;

      if (nextPoint != null) {
        // Calculate from coordinates
        final segmentDistance = _calculateDistance(
          currentPoint.latitude, currentPoint.longitude,
          nextPoint.latitude, nextPoint.longitude
        );
        const speed = 30; // km/h default speed
        totalTime += (segmentDistance / speed) * 60; // Convert to minutes
        totalDistance += segmentDistance;
      }

      // Add stop time if this is a stop (but not for the final pickup stop)
      if (currentPoint.isStop && i < pickupStopIndex - 1) {
        totalTime += 2; // Default 2 minutes stop time
      }
    }

    // Calculate total distance to pickup stop for display
    if (totalDistance == 0) {
      // Fallback to direct distance calculation
      totalDistance = _calculateDistance(busLat, busLng, pickupStop.latitude, pickupStop.longitude);
    }

    // Find next upcoming stop for display
    String nextStopName = 'Unknown';
    for (int i = currentPointIndex; i <= pickupStopIndex; i++) {
      final point = sortedPoints[i];
      if (point.isStop) {
        nextStopName = point.pointName ?? 'Stop ${point.pointOrder ?? point.id}';
        break;
      }
    }

    return ETAResult(
      distanceToStop: (totalDistance * 10).round() / 10, // Round to 1 decimal
      etaMinutes: totalTime.round(),
      nextStopName: nextStopName,
    );
  }

  // Calculate personalized ETA including walking time
  PersonalizedETAResult _calculatePersonalizedETA(
    double? userHomeLat,
    double? userHomeLng,
    double busLat,
    double busLng,
    List<RoutePoint> routePoints,
    int? userPickupStopId,
  ) {
    if (userHomeLat == null || userHomeLng == null || userPickupStopId == null) {
      return PersonalizedETAResult(
        homeToStop: 0, 
        busToStop: 0, 
        totalETA: 0, 
        walkingTime: 0
      );
    }

    final pickupStop = routePoints.firstWhere(
      (point) => point.id == userPickupStopId && point.isStop,
      orElse: () => RoutePoint(id: 0, routePathId: 0, latitude: 0, longitude: 0, isStop: false),
    );
    
    if (pickupStop.id == 0) {
      return PersonalizedETAResult(
        homeToStop: 0, 
        busToStop: 0, 
        totalETA: 0, 
        walkingTime: 0
      );
    }

    // Calculate walking distance from home to pickup stop
    final homeToStopDistance = _calculateDistance(
      userHomeLat, userHomeLng, 
      pickupStop.latitude, pickupStop.longitude
    );
    const walkingSpeed = 5; // km/h average walking speed
    final walkingTime = (homeToStopDistance / walkingSpeed) * 60; // minutes

    // Calculate bus ETA to pickup stop
    final busETA = _calculateETAToPickupStop(busLat, busLng, routePoints, userPickupStopId);

    // Total ETA is the maximum of walking time and bus ETA (accounting for when you need to leave)
    final totalETA = max(busETA.etaMinutes - walkingTime, 0).toDouble();

    return PersonalizedETAResult(
      homeToStop: (homeToStopDistance * 10).round() / 10,
      busToStop: busETA.distanceToStop,
      totalETA: totalETA.round(),
      walkingTime: walkingTime.round(),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _userPos = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _loading = true);
      
      // Load all data in parallel
      final futures = await Future.wait([
        UserSettingsService.getUserSettings(),
        ApiService.getBusesWithLocation(),
      ]);
      
      final userSettings = futures[0] as UserSettings?;
      final buses = futures[1] as List<Bus>;
      
      setState(() {
        _userSettings = userSettings;
      });
      
      // Find assigned bus
      if (userSettings?.routePathId != null) {
        final routeBus = buses.firstWhere(
          (bus) => bus.routePathId == userSettings!.routePathId,
          orElse: () => Bus(id: 0, busNumber: '', routePathId: null, isActive: true),
        );
        
        if (routeBus.id != 0) {
          setState(() {
            _assignedBus = routeBus;
            _busData = _busData.copyWith(
              busNumber: routeBus.busNumber,
              route: userSettings?.routeName ?? 'Route ${userSettings?.routePathId}',
              busPos: routeBus.currentLocation != null 
                ? LatLng(routeBus.currentLocation!.latitude, routeBus.currentLocation!.longitude)
                : _busData.busPos,
              speed: routeBus.currentLocation?.speed ?? _busData.speed,
            );
          });
        }
        
        // Load route points
        try {
          final routePoints = await RoutesService.getRoutePoints(userSettings!.routePathId!);
          setState(() {
            _routePoints = routePoints;
          });
          
          // Calculate initial ETA
          if (routeBus.currentLocation != null) {
            _calculateAndUpdateETA(routeBus.currentLocation!, userSettings, routePoints);
          }
        } catch (error) {
          print('Failed to load route points: $error');
        }
      }
    } catch (error) {
      print('Failed to load user data: $error');
    } finally {
      setState(() => _loading = false);
      // Start tracking after user data is loaded
      if (_isTracking) {
        _startRealTimeTracking();
      }
    }
  }

  void _calculateAndUpdateETA(BusLocation busLocation, UserSettings? settings, List<RoutePoint> routePoints) {
    if (settings?.pickupStopId == null || routePoints.isEmpty) return;
    
    final busETACalc = _calculateETAToPickupStop(
      busLocation.latitude,
      busLocation.longitude,
      routePoints,
      settings!.pickupStopId,
    );

    // Update basic bus data
    setState(() {
      _busData = _busData.copyWith(
        distance: busETACalc.distanceToStop,
        eta: busETACalc.etaMinutes,
        nextStop: busETACalc.nextStopName,
      );
    });

    // Calculate personalized ETA if user has home location
    if (settings.homeLat != null && settings.homeLng != null) {
      final personalizedCalc = _calculatePersonalizedETA(
        settings.homeLat,
        settings.homeLng,
        busLocation.latitude,
        busLocation.longitude,
        routePoints,
        settings.pickupStopId,
      );

      final needToLeaveIn = max(0, busETACalc.etaMinutes - personalizedCalc.walkingTime);

      setState(() {
        _personalizedETA = PersonalizedETA(
          homeToStop: personalizedCalc.homeToStop,
          busToStop: personalizedCalc.busToStop,
          totalETA: personalizedCalc.totalETA,
          walkingTime: personalizedCalc.walkingTime,
          needToLeaveIn: needToLeaveIn.round(),
          pickupStopName: busETACalc.nextStopName,
        );
      });
    }
  }

  void _startRealTimeTracking() {
    if (!_isTracking || _userSettings?.routePathId == null) return;
    
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _refreshBusLocation();
      
      // Calculate ETA using consolidated function
      if (_assignedBus?.currentLocation != null) {
        _calculateAndUpdateETA(_assignedBus!.currentLocation!, _userSettings, _routePoints);
      }
    });
  }

  Future<void> _refreshBusLocation() async {
    try {
      if (_userSettings?.routePathId == null) return;
      
      final buses = await ApiService.getBusesWithLocation();
      
      // Find bus assigned to user's route
      final routeBus = buses.firstWhere(
        (bus) => bus.routePathId == _userSettings!.routePathId,
        orElse: () => Bus(id: 0, busNumber: '', routePathId: null, isActive: true),
      );
      
      if (routeBus.id != 0 && routeBus.currentLocation != null) {
        final newBusPos = LatLng(routeBus.currentLocation!.latitude, routeBus.currentLocation!.longitude);
        setState(() {
          _assignedBus = routeBus;
          _busData = _busData.copyWith(
            busPos: newBusPos,
            speed: routeBus.currentLocation!.speed ?? _busData.speed,
          );
        });

        // Center map on bus if the toggle is enabled
        if (_centerOnBus) {
          _mapController.move(newBusPos, _mapController.camera.zoom);
        }
      }
    } catch (error) {
      print('Failed to refresh bus location: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD), // Light blue
              Color(0xFFF3E5F5), // Light purple
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_bus, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BusTracker',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_busData.busNumber} • ${_busData.route}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _isTracking ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTracking ? 'Live' : 'Offline',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Status Cards
                    _buildStatusCards(),
                    
                    const SizedBox(height: 16),

                    // Personalized ETA Cards
                    if (_userSettings?.homeLat != null && _userSettings?.homeLng != null && _userSettings?.pickupStopId != null)
                      _buildPersonalizedETACard(),
                    
                    // Message for users without personalized settings
                    if ((_userSettings?.homeLat == null || _userSettings?.homeLng == null || _userSettings?.pickupStopId == null) && !_loading)
                      _buildPersonalizationPrompt(),

                    const SizedBox(height: 16),

                    // Control Buttons
                    _buildControlButtons(),

                    const SizedBox(height: 16),

                    // Map Container
                    _buildMapContainer(),

                    const SizedBox(height: 16),

                    // Route Schema (Vertical Line with Stops)
                    if (_showRoute && _routePoints.isNotEmpty)
                      _buildRouteSchema(),

                    const SizedBox(height: 16),

                    // No Bus Assigned Message
                    if (!_loading && _assignedBus == null)
                      _buildNoBusMessage(),

                    // Loading Message
                    if (_loading)
                      _buildLoadingMessage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatusCard(
          icon: Icons.navigation,
          label: 'Distance',
          value: '${_busData.distance.toStringAsFixed(1)} km',
          color: Colors.blue,
        ),
        _buildStatusCard(
          icon: Icons.schedule,
          label: 'ETA',
          value: '${_busData.eta} min',
          color: Colors.green,
        ),
        _buildStatusCard(
          icon: Icons.speed,
          label: 'Speed',
          value: '${_busData.speed.round()} km/h',
          color: Colors.purple,
        ),
        _buildStatusCard(
          icon: Icons.location_on,
          label: 'Next Stop',
          value: _busData.nextStop,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF616161), // Darker grey[700]
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedETACard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home, color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Personalized Travel Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPersonalizedCard(
                    icon: Icons.directions_walk,
                    label: 'Walking Distance',
                    value: '${_personalizedETA.homeToStop} km',
                    subtitle: '${_personalizedETA.walkingTime} min walk to pickup stop',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPersonalizedCard(
                    icon: Icons.schedule,
                    label: 'Departure Time',
                    value: _personalizedETA.needToLeaveIn > 0
                      ? '${_personalizedETA.needToLeaveIn} min'
                      : 'Now!',
                    subtitle: _personalizedETA.needToLeaveIn > 0
                      ? 'Leave in ${_personalizedETA.needToLeaveIn} min'
                      : 'Leave home now',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            
            // Time-sensitive alerts
            if (_personalizedETA.needToLeaveIn <= 5 && _personalizedETA.needToLeaveIn > 0)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade100,
                  border: Border.all(color: Colors.yellow.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⏰ You should leave home in ${_personalizedETA.needToLeaveIn} minutes to reach your pickup stop on time!',
                  style: TextStyle(
                    color: Colors.yellow.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            if (_personalizedETA.needToLeaveIn <= 0 && _busData.eta > 0)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🏃‍♂️ You should leave home now or you might miss the bus! It takes ${_personalizedETA.walkingTime} minutes to walk to your stop.',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF424242), // Darker grey[800]
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizationPrompt() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home, color: Colors.blue.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Get Personalized Tracking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure your home location and pickup stop in Settings to get personalized travel times and alerts.',
              style: TextStyle(
                color: Color(0xFF1976D2), // Fixed blue[700]
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_userSettings?.homeLat == null)
                  const Text('• Set your home coordinates', style: TextStyle(fontSize: 12, color: Color(0xFF1E88E5), fontWeight: FontWeight.w500)),
                if (_userSettings?.pickupStopId == null)
                  const Text('• Choose your pickup stop', style: TextStyle(fontSize: 12, color: Color(0xFF1E88E5), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isTracking = !_isTracking;
            });
            if (_isTracking) {
              _startRealTimeTracking();
            } else {
              _trackingTimer?.cancel();
            }
          },
          icon: Icon(_isTracking ? Icons.directions_bus : Icons.play_arrow),
          label: Text(_isTracking ? 'Tracking' : 'Start Track'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isTracking ? Colors.green : const Color(0xFFE0E0E0),
            foregroundColor: _isTracking ? Colors.white : Colors.black87,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _notifications = !_notifications;
            });
          },
          icon: const Icon(Icons.notifications),
          label: const Text('Notify'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _notifications ? Colors.blue : const Color(0xFFE0E0E0),
            foregroundColor: _notifications ? Colors.white : Colors.black87,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showRoute = !_showRoute;
            });
          },
          icon: const Icon(Icons.route),
          label: const Text('Route'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showRoute ? Colors.purple : const Color(0xFFE0E0E0),
            foregroundColor: _showRoute ? Colors.white : Colors.black87,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _centerOnBus = !_centerOnBus;
            });
            if (_centerOnBus && _assignedBus?.currentLocation != null) {
              _mapController.move(_busData.busPos, 15);
            }
          },
          icon: Icon(_centerOnBus ? Icons.my_location : Icons.location_disabled),
          label: Text(_centerOnBus ? 'Centered' : 'Free Move'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _centerOnBus ? Colors.orange : const Color(0xFFE0E0E0),
            foregroundColor: _centerOnBus ? Colors.white : Colors.black87,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapContainer() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // Fixed black with 10% opacity
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Card(
        color: Colors.white,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Live Map',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bus Location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF616161),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 250,
              child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userPos ?? _busData.busPos,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tag_mobile',
                ),
                MarkerLayer(
                  markers: [
                    // Show assigned bus
                    if (_assignedBus?.currentLocation != null)
                      Marker(
                        width: 23,
                        height: 23,
                        point: _busData.busPos,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    // Show home location if configured
                    if (_userSettings?.homeLat != null && _userSettings?.homeLng != null)
                      Marker(
                        width: 23,
                        height: 23,
                        point: LatLng(_userSettings!.homeLat!, _userSettings!.homeLng!),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 235, 165, 59),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.home,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    // Show route points
                    if (_showRoute)
                      ..._routePoints
                          .where((point) => point.isStop)
                          .map((stop) {
                            final isUserPickupStop = stop.id == _userSettings?.pickupStopId;
                            final isSelected = stop.id == _selectedStopId;
                            final stopName = stop.pointName ?? 'Stop ${stop.pointOrder ?? stop.id}';
                            return Marker(
                              width: 80,
                              height: 50,
                              point: LatLng(stop.latitude, stop.longitude),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedStopId = isSelected ? null : stop.id;
                                  });
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 3,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          stopName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: isUserPickupStop ?  const Color.fromARGB(255, 235, 165, 59) : const Color.fromARGB(255, 225, 112, 104),
                                          size: isUserPickupStop ? 27 : 25,
                                        ),
                                        Icon(
                                          Icons.directions_bus,
                                          color: Colors.white,
                                          size: isUserPickupStop ? 16 : 14,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                  ],
                ),
                // Show route polyline
                if (_showRoute && _routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
                        color: const Color.fromARGB(204, 107, 115, 201), // Blue route line
                        strokeWidth: 7,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRouteSchema() {
    final stops = _routePoints.where((point) => point.isStop).toList();
    final closestPointId = _getClosestPointToBus();

    // Sort stops by point order
    stops.sort((a, b) {
      if (a.pointOrder == null && b.pointOrder == null) return a.id.compareTo(b.id);
      if (a.pointOrder == null) return 1;
      if (b.pointOrder == null) return -1;
      return a.pointOrder!.compareTo(b.pointOrder!);
    });

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Route Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (closestPointId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 76, 175, 80),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_bus,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Bus tracking',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  final stop = stops[index];
                  final isClosest = stop.id == closestPointId;
                  final isUserPickup = stop.id == _userSettings?.pickupStopId;
                  final isLast = index == stops.length - 1;
                  final stopName = stop.pointName ?? 'Stop ${stop.pointOrder ?? stop.id}';

                  return IntrinsicHeight(
                    child: GestureDetector(
                      onTap: () {
                        // Center map on this stop
                        _mapController.move(
                          LatLng(stop.latitude, stop.longitude),
                          16,
                        );
                        // Temporarily disable center on bus
                        setState(() {
                          _centerOnBus = false;
                        });
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vertical line and circle
                          SizedBox(
                            width: 30,
                            child: Column(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isClosest
                                        ? const Color.fromARGB(255, 76, 175, 80)
                                        : (isUserPickup
                                            ? const Color.fromARGB(255, 235, 165, 59)
                                            : const Color.fromARGB(255, 225, 112, 104)),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isClosest ? Icons.directions_bus : Icons.circle,
                                    color: Colors.white,
                                    size: isClosest ? 12 : 8,
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 4,
                                      color: const Color.fromARGB(204, 107, 115, 201),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stop info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text(
                                  stopName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isClosest ? FontWeight.bold : FontWeight.w500,
                                    color: isClosest ? const Color.fromARGB(255, 76, 175, 80) : Colors.black87,
                                  ),
                                ),
                                if (isClosest)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 76, 175, 80),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Bus is near here',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isUserPickup)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 235, 165, 59),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Your pickup stop',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusMessage() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'No Bus Assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No bus is assigned to your route. Please contact administration to assign a bus to your route.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading Route...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait while we load your assigned route and bus information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF616161),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data classes
class BusData {
  final double distance;
  final int eta;
  final double speed;
  final String nextStop;
  final String busNumber;
  final String route;
  final LatLng busPos;

  BusData({
    required this.distance,
    required this.eta,
    required this.speed,
    required this.nextStop,
    required this.busNumber,
    required this.route,
    required this.busPos,
  });

  BusData copyWith({
    double? distance,
    int? eta,
    double? speed,
    String? nextStop,
    String? busNumber,
    String? route,
    LatLng? busPos,
  }) {
    return BusData(
      distance: distance ?? this.distance,
      eta: eta ?? this.eta,
      speed: speed ?? this.speed,
      nextStop: nextStop ?? this.nextStop,
      busNumber: busNumber ?? this.busNumber,
      route: route ?? this.route,
      busPos: busPos ?? this.busPos,
    );
  }
}

class PersonalizedETA {
  final double homeToStop;
  final double busToStop;
  final int totalETA;
  final int walkingTime;
  final int needToLeaveIn;
  final String pickupStopName;

  PersonalizedETA({
    required this.homeToStop,
    required this.busToStop,
    required this.totalETA,
    required this.walkingTime,
    required this.needToLeaveIn,
    required this.pickupStopName,
  });
}

class ETAResult {
  final double distanceToStop;
  final int etaMinutes;
  final String nextStopName;

  ETAResult({
    required this.distanceToStop,
    required this.etaMinutes,
    required this.nextStopName,
  });
}

class PersonalizedETAResult {
  final double homeToStop;
  final double busToStop;
  final int totalETA;
  final int walkingTime;

  PersonalizedETAResult({
    required this.homeToStop,
    required this.busToStop,
    required this.totalETA,
    required this.walkingTime,
  });
}