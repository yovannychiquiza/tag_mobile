import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../store/auth_store.dart';
import '../services/user_settings_service.dart';
import '../services/routes_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserSettings? _userSettings;
  List<RoutePath> _routes = [];
  List<RoutePoint> _routePoints = [];
  int? _selectedRouteId;
  int? _selectedPickupStopId;
  final _homeLatController = TextEditingController();
  final _homeLngController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _loadingRoutePoints = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _homeLatController.dispose();
    _homeLngController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() => _loading = true);
      
      final results = await Future.wait([
        UserSettingsService.getUserSettings(),
        RoutesService.getRoutes(),
      ]);
      
      final userSettings = results[0] as UserSettings?;
      final routes = results[1] as List<RoutePath>;
      
      setState(() {
        _userSettings = userSettings;
        _routes = routes;
        _selectedRouteId = userSettings?.routePathId;
        _selectedPickupStopId = userSettings?.pickupStopId;
        _homeLatController.text = userSettings?.homeLat?.toString() ?? '';
        _homeLngController.text = userSettings?.homeLng?.toString() ?? '';
      });
      
      if (_selectedRouteId != null) {
        await _fetchRoutePoints(_selectedRouteId!);
      }
    } catch (e) {
      _showSnackBar('Error loading settings: ${e.toString()}', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchRoutePoints(int routeId) async {
    try {
      setState(() => _loadingRoutePoints = true);
      final points = await RoutesService.getRoutePoints(routeId);
      setState(() => _routePoints = points);
    } catch (e) {
      _showSnackBar('Error loading route points: ${e.toString()}', isError: true);
      setState(() => _routePoints = []);
    } finally {
      setState(() => _loadingRoutePoints = false);
    }
  }

  Future<void> _handleRouteChange(int? routeId) async {
    setState(() {
      _selectedRouteId = routeId;
      _selectedPickupStopId = null;
      _routePoints = [];
    });
    
    if (routeId != null) {
      await _fetchRoutePoints(routeId);
    }
  }

  String? _validateCoordinates() {
    final latText = _homeLatController.text.trim();
    final lngText = _homeLngController.text.trim();
    
    if (latText.isNotEmpty && lngText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      
      if (lat == null || lng == null) {
        return 'Invalid coordinates. Please enter valid numbers.';
      }
      
      if (lat < -90 || lat > 90) {
        return 'Latitude must be between -90 and 90 degrees.';
      }
      
      if (lng < -180 || lng > 180) {
        return 'Longitude must be between -180 and 180 degrees.';
      }
    } else if (latText.isNotEmpty || lngText.isNotEmpty) {
      return 'Please provide both latitude and longitude, or leave both empty.';
    }
    
    return null;
  }

  Future<void> _saveSettings() async {
    final validationError = _validateCoordinates();
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }

    try {
      setState(() => _saving = true);
      
      final latText = _homeLatController.text.trim();
      final lngText = _homeLngController.text.trim();
      
      await UserSettingsService.updateUserSettings(
        UserSettingsUpdate(
          routePathId: _selectedRouteId,
          pickupStopId: _selectedPickupStopId,
          homeLat: latText.isNotEmpty ? double.parse(latText) : null,
          homeLng: lngText.isNotEmpty ? double.parse(lngText) : null,
        ),
      );
      
      await _fetchData();
      _showSnackBar('Settings saved successfully!');
    } catch (e) {
      _showSnackBar('Error saving settings: ${e.toString()}', isError: true);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await _showConfirmDialog(
      'Reset Settings',
      'Are you sure you want to reset your settings to default? This will remove your home location, route selection, and pickup stop configuration.',
    );
    
    if (!confirmed) return;
    
    try {
      setState(() => _saving = true);
      await UserSettingsService.deleteUserSettings();
      
      setState(() {
        _selectedRouteId = null;
        _selectedPickupStopId = null;
        _homeLatController.clear();
        _homeLngController.clear();
        _routePoints = [];
      });
      
      await _fetchData();
      _showSnackBar('Settings reset successfully!');
    } catch (e) {
      _showSnackBar('Error resetting settings: ${e.toString()}', isError: true);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied.', isError: true);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied.', isError: true);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _homeLatController.text = position.latitude.toString();
        _homeLngController.text = position.longitude.toString();
      });
      
      _showSnackBar('Current location set successfully!');
    } catch (e) {
      _showSnackBar('Error getting current location: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading settings...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings, size: 28),
            SizedBox(width: 8),
            Text(
              'User Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default Route Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Route Selection
                      const Row(
                        children: [
                          Icon(Icons.route, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Select Default Route',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedRouteId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        hint: const Text('No default route'),
                        items: _routes.map((route) {
                          return DropdownMenuItem<int>(
                            value: route.id,
                            child: Text(
                              '${route.name}${route.description != null ? ' - ${route.description}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _handleRouteChange,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This route will be automatically selected when you access the Route Path page.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      // Pickup Stop Selection
                      if (_selectedRouteId != null) ...[
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Select Your Pickup Stop',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_loadingRoutePoints)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Loading pickup stops...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            value: _selectedPickupStopId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            hint: const Text('Select a pickup stop'),
                            items: _routePoints
                                .where((point) => point.isStop)
                                .map((stop) {
                              return DropdownMenuItem<int>(
                                value: stop.id,
                                child: Text(
                                  'Stop ${stop.pointOrder ?? stop.id} - (${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList()..sort((a, b) => a.child.toString().compareTo(b.child.toString())),
                            onChanged: (value) {
                              setState(() {
                                _selectedPickupStopId = value;
                              });
                            },
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Select the bus stop where you will be picked up. Only stops from the selected route are shown.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      
                      // Home Location
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Icon(Icons.home, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Home Location (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Latitude',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _homeLatController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., 45.2733',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Longitude',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _homeLngController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., -66.0633',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set your home coordinates for better route tracking and distance calculations.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Current Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[100],
                              foregroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _homeLatController.clear();
                              _homeLngController.clear();
                            },
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      
                      // Current Settings Display
                      if (_userSettings?.routeName != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Settings:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Default Route: ${_userSettings!.routeName}',
                                style: const TextStyle(color: Colors.blue),
                              ),
                              if (_userSettings!.routeDescription != null)
                                Text(
                                  ' - ${_userSettings!.routeDescription}',
                                  style: TextStyle(color: Colors.blue[600]),
                                ),
                              if (_userSettings!.pickupStopId != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Pickup Stop: ${(() {
                                    final stop = _routePoints.firstWhere(
                                      (p) => p.id == _userSettings!.pickupStopId,
                                      orElse: () => RoutePoint(
                                        id: _userSettings!.pickupStopId!,
                                        routePathId: 0,
                                        latitude: 0,
                                        longitude: 0,
                                        isStop: true,
                                      ),
                                    );
                                    return 'Stop ${stop.pointOrder ?? stop.id} at (${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)})';
                                  })()}',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ],
                              if (_userSettings!.homeLat != null && _userSettings!.homeLng != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Home Location: (${_userSettings!.homeLat!.toStringAsFixed(4)}, ${_userSettings!.homeLng!.toStringAsFixed(4)})',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ],
                              if (_userSettings!.updatedAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Last updated: ${_userSettings!.updatedAt!.toLocal().toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      
                      // Action Buttons
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveSettings,
                              icon: _saving 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_saving ? 'Saving...' : 'Save Settings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _resetSettings,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Logout Section
              Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red[700]),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final authStore = AuthStore();
                await authStore.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}