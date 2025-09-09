import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../store/auth_store.dart';

class BusTrackingPage extends StatefulWidget {
  const BusTrackingPage({super.key});

  @override
  State<BusTrackingPage> createState() => _BusTrackingPageState();
}

class _BusTrackingPageState extends State<BusTrackingPage> {
  List<Bus> _buses = [];
  Map<int, Timer?> _trackingTimers = {};
  Map<int, int> _trackingFrequencies = {}; // Bus ID -> Frequency in seconds
  Map<int, bool> _trackingStatus = {}; // Bus ID -> Is tracking
  Map<int, BusLocation?> _lastLocations = {}; // Bus ID -> Last location
  LatLng? _userLocation;
  bool _loading = true;
  final MapController _mapController = MapController();

  // Default location (Saint John, NB)
  final LatLng _defaultLocation = const LatLng(45.2733, -66.0633);

  @override
  void initState() {
    super.initState();
    _loadBuses();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    // Stop all tracking timers
    for (Timer? timer in _trackingTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _loadBuses() async {
    try {
      setState(() => _loading = true);
      final buses = await ApiService.getBuses();
      setState(() {
        _buses = buses;
        // Initialize tracking states
        for (Bus bus in buses) {
          _trackingFrequencies[bus.id] = 10; // Default 10 seconds
          _trackingStatus[bus.id] = false;
          _lastLocations[bus.id] = bus.currentLocation;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load buses: $e');
    }
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
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _startTracking(int busId) async {
    if (_trackingStatus[busId] == true) return;

    setState(() => _trackingStatus[busId] = true);
    
    final frequency = _trackingFrequencies[busId] ?? 10;
    _trackingTimers[busId] = Timer.periodic(
      Duration(seconds: frequency),
      (timer) => _trackAndSaveLocation(busId),
    );
    
    // Track immediately
    _trackAndSaveLocation(busId);
  }

  Future<void> _stopTracking(int busId) async {
    _trackingTimers[busId]?.cancel();
    _trackingTimers[busId] = null;
    setState(() => _trackingStatus[busId] = false);
  }

  Future<void> _trackAndSaveLocation(int busId) async {
    try {
      // Get current GPS location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Save location to database via API
      BusLocation location = await ApiService.createBusLocation(
        busId: busId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed * 3.6, // Convert m/s to km/h
        direction: position.heading,
        isActive: true,
      );

      setState(() {
        _lastLocations[busId] = location;
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      print('Location saved for Bus $busId: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error tracking location for Bus $busId: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
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
              child: Row(
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus Management',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Track buses with GPS and save locations',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _loadBuses,
                        icon: const Icon(Icons.refresh, color: Colors.black87),
                      ),
                      IconButton(
                        onPressed: () async {
                          final authStore = AuthStore();
                          await authStore.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacementNamed('/login');
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.black87),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bus List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buses.isEmpty
                      ? const Center(
                          child: Text(
                            'No buses found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _buses.length,
                          itemBuilder: (context, index) {
                            final bus = _buses[index];
                            final isTracking = _trackingStatus[bus.id] ?? false;
                            final frequency = _trackingFrequencies[bus.id] ?? 10;
                            final lastLocation = _lastLocations[bus.id];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ExpansionTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isTracking ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.directions_bus,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  'Bus ${bus.busNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (bus.licensePlate != null)
                                      Text('License: ${bus.licensePlate}'),
                                    Text(
                                      isTracking 
                                          ? 'Tracking every ${frequency}s' 
                                          : 'Not tracking',
                                      style: TextStyle(
                                        color: isTracking ? Colors.green : Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (lastLocation != null)
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: isTracking,
                                      onChanged: (value) {
                                        if (value) {
                                          _startTracking(bus.id);
                                        } else {
                                          _stopTracking(bus.id);
                                        }
                                      },
                                      activeColor: Colors.green,
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Frequency Control
                                        Row(
                                          children: [
                                            const Icon(Icons.timer, size: 20),
                                            const SizedBox(width: 8),
                                            const Text('Tracking Frequency:'),
                                            const SizedBox(width: 16),
                                            DropdownButton<int>(
                                              value: frequency,
                                              items: [5, 10, 15, 30, 60].map((seconds) {
                                                return DropdownMenuItem(
                                                  value: seconds,
                                                  child: Text('${seconds}s'),
                                                );
                                              }).toList(),
                                              onChanged: isTracking ? null : (value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _trackingFrequencies[bus.id] = value;
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Location Info
                                        if (lastLocation != null) ...[
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 20, color: Colors.blue),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Last Location:',
                                                      style: TextStyle(fontWeight: FontWeight.w500),
                                                    ),
                                                    Text(
                                                      '${lastLocation.latitude.toStringAsFixed(6)}, ${lastLocation.longitude.toStringAsFixed(6)}',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                    ),
                                                    if (lastLocation.speed != null)
                                                      Text(
                                                        'Speed: ${lastLocation.speed!.toStringAsFixed(1)} km/h',
                                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          Row(
                                            children: [
                                              Icon(Icons.location_off, size: 20, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Text(
                                                'No location data',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ],
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Action Buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: isTracking 
                                                    ? () => _stopTracking(bus.id)
                                                    : () => _startTracking(bus.id),
                                                icon: Icon(
                                                  isTracking ? Icons.stop : Icons.play_arrow,
                                                ),
                                                label: Text(
                                                  isTracking ? 'Stop Tracking' : 'Start Tracking',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isTracking ? Colors.red : Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () => _trackAndSaveLocation(bus.id),
                                              icon: const Icon(Icons.my_location),
                                              label: const Text('Track Now'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Map View (Small preview)
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLocation ?? _defaultLocation,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tag_mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      // User location marker
                      if (_userLocation != null)
                        Marker(
                          width: 30,
                          height: 30,
                          point: _userLocation!,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.blue,
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
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      // Bus location markers
                      ..._lastLocations.entries.where((entry) => entry.value != null).map((entry) {
                        final busId = entry.key;
                        final location = entry.value!;
                        final isTracking = _trackingStatus[busId] ?? false;
                        
                        return Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(location.latitude, location.longitude),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isTracking ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                              boxShadow: const [
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
                        );
                      }).toList(),
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
}