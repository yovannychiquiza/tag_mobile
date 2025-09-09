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
  List<RoutePoint> _routePoints = [];
  UserSettings? _userSettings;
  bool _loading = true;
  Timer? _trackingTimer;

  final MapController _mapController = MapController();
  final LatLng _defaultLocation = const LatLng(45.2733, -66.0633);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
    _startRealTimeTracking();
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
        nextStopName = 'Stop ${point.pointOrder ?? point.id}';
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
        setState(() {
          _assignedBus = routeBus;
          _busData = _busData.copyWith(
            busPos: LatLng(routeBus.currentLocation!.latitude, routeBus.currentLocation!.longitude),
            speed: routeBus.currentLocation!.speed ?? _busData.speed,
          );
        });
      }
    } catch (error) {
      print('Failed to refresh bus location: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
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
                        child: const Text('🚌', style: TextStyle(fontSize: 24)),
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

                    // Route Timeline
                    if (_showRoute && _routePoints.isNotEmpty)
                      _buildRouteTimeline(),

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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
                    icon: Icons.home,
                    label: 'Walking Distance',
                    value: '${_personalizedETA.homeToStop} km',
                    subtitle: '${_personalizedETA.walkingTime} minutes to your pickup stop',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPersonalizedCard(
                    icon: Icons.timer,
                    label: 'Departure Time',
                    value: _personalizedETA.needToLeaveIn > 0 
                      ? '${_personalizedETA.needToLeaveIn} min' 
                      : 'Leave Now!',
                    subtitle: _personalizedETA.needToLeaveIn > 0 
                      ? 'Leave home in ${_personalizedETA.needToLeaveIn} minutes' 
                      : 'You should leave home now',
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
      color: Colors.white.withOpacity(0.8),
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
                      fontWeight: FontWeight.w500,
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
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizationPrompt() {
    return Card(
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
            Text(
              'Configure your home location and pickup stop in Settings to get personalized travel times and alerts.',
              style: TextStyle(color: Colors.blue.shade700),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_userSettings?.homeLat == null)
                  Text('• Set your home coordinates', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                if (_userSettings?.pickupStopId == null)
                  Text('• Choose your pickup stop', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
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
            backgroundColor: _isTracking ? Colors.green : Colors.grey.shade300,
            foregroundColor: _isTracking ? Colors.white : Colors.black87,
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
            backgroundColor: _notifications ? Colors.blue : Colors.grey.shade300,
            foregroundColor: _notifications ? Colors.white : Colors.black87,
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
            backgroundColor: _showRoute ? Colors.purple : Colors.grey.shade300,
            foregroundColor: _showRoute ? Colors.white : Colors.black87,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement share functionality
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMapContainer() {
    return Card(
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
                  ),
                ),
                const Spacer(),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.yellow,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bus Location',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                        width: 40,
                        height: 40,
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
                            size: 24,
                          ),
                        ),
                      ),
                    // Show home location if configured
                    if (_userSettings?.homeLat != null && _userSettings?.homeLng != null)
                      Marker(
                        width: 35,
                        height: 35,
                        point: LatLng(_userSettings!.homeLat!, _userSettings!.homeLng!),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.orange,
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
                            size: 20,
                          ),
                        ),
                      ),
                    // Show route points
                    if (_showRoute)
                      ..._routePoints
                          .where((point) => point.isStop)
                          .map((stop) {
                            final isUserPickupStop = stop.id == _userSettings?.pickupStopId;
                            return Marker(
                              width: isUserPickupStop ? 35 : 25,
                              height: isUserPickupStop ? 35 : 25,
                              point: LatLng(stop.latitude, stop.longitude),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isUserPickupStop ? Colors.green : Colors.blue,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: isUserPickupStop ? 20 : 15,
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
                        color: Colors.purple.withOpacity(0.8),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._routePoints
                .where((point) => point.isStop)
                .take(5)
                .toList()
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final stop = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: index == 0 ? Colors.yellow.shade400 : Colors.grey.shade200,
                            border: Border.all(
                              color: index == 0 ? Colors.yellow.shade500 : Colors.grey.shade300,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stop ${stop.pointOrder ?? stop.id}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: index == 0 ? Colors.yellow.shade700 : Colors.black87,
                                ),
                              ),
                              if (index == 0)
                                Text(
                                  'Current stop area',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.yellow.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${7 + index}:${30 + (index * 5)} AM',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusMessage() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'No Bus Assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No bus is assigned to your route. Please contact administration to assign a bus to your route.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return const Card(
      child: Padding(
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
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait while we load your assigned route and bus information.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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