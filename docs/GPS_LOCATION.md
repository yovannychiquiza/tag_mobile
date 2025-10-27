# GPS & Location Tracking Guide

## Overview

Tag Mobile uses the `geolocator` package for GPS location tracking with support for both foreground and background tracking.

---

## Permissions

### Android

**AndroidManifest.xml** (android/app/src/main/AndroidManifest.xml)

```xml
<manifest>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
  <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

**Permission Levels:**
- `ACCESS_FINE_LOCATION`: Precise location (GPS)
- `ACCESS_COARSE_LOCATION`: Approximate location (network-based)
- `ACCESS_BACKGROUND_LOCATION`: Location when app is in background (Android 10+)
- `FOREGROUND_SERVICE`: Persistent notification for background tracking

### iOS

**Info.plist** (ios/Runner/Info.plist)

```xml
<dict>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>This app needs your location to track buses in real-time.</string>

  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>This app needs your location even in the background to update bus positions.</string>

  <key>UIBackgroundModes</key>
  <array>
    <string>location</string>
  </array>
</dict>
```

---

## Requesting Permissions

### Permission Flow

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> _requestLocationPermissions() async {
  // Request when-in-use permission first
  var status = await Permission.location.request();

  if (status.isGranted) {
    print('Location permission granted');

    // On Android 10+, request background permission
    if (Platform.isAndroid) {
      var bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isGranted) {
        print('Background location granted');
      }
    }
  } else if (status.isDenied) {
    print('Location permission denied');
  } else if (status.isPermanentlyDenied) {
    // Open app settings
    await openAppSettings();
  }
}
```

### Check Permission Status

```dart
Future<bool> _hasLocationPermission() async {
  final status = await Permission.location.status;
  return status.isGranted;
}
```

---

## Getting Current Location

### One-Time Location

```dart
import 'package:geolocator/geolocator.dart';

Future<Position> _getCurrentLocation() async {
  // Check if location services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled');
  }

  // Check permissions
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied');
  }

  // Get current position
  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  return position;
}
```

### Location Data

```dart
Position position = await _getCurrentLocation();

print('Latitude: ${position.latitude}');
print('Longitude: ${position.longitude}');
print('Altitude: ${position.altitude}');
print('Speed: ${position.speed} m/s'); // Meters per second
print('Heading: ${position.heading}°'); // Degrees
print('Accuracy: ${position.accuracy} m');
print('Timestamp: ${position.timestamp}');
```

### Convert Speed

```dart
// Speed in km/h
double speedKmh = position.speed * 3.6;

// Speed in mph
double speedMph = position.speed * 2.237;
```

---

## Location Accuracy

### Accuracy Levels

```dart
enum LocationAccuracy {
  lowest,       // ~10km
  low,          // ~1km
  medium,       // ~100m
  high,         // ~10m
  best,         // ~3m
  bestForNavigation, // Best possible
}
```

### Usage

```dart
// High accuracy (GPS)
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);

// Low accuracy (network-based, faster)
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.low,
);
```

---

## Continuous Location Updates

### Position Stream

```dart
import 'dart:async';

StreamSubscription<Position>? _positionSubscription;

void _startLocationUpdates() {
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Minimum distance (meters) before update
  );

  _positionSubscription = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((Position position) {
    print('New location: ${position.latitude}, ${position.longitude}');
    _updateBusLocation(position);
  });
}

void _stopLocationUpdates() {
  _positionSubscription?.cancel();
  _positionSubscription = null;
}

@override
void dispose() {
  _stopLocationUpdates();
  super.dispose();
}
```

### Android-Specific Settings

```dart
const AndroidSettings androidSettings = AndroidSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 0,
  intervalDuration: Duration(seconds: 10),
  foregroundNotificationConfig: ForegroundNotificationConfig(
    notificationText: 'Tracking bus location in the background',
    notificationTitle: 'Bus Tracking Active',
    enableWakeLock: true,
  ),
);

final stream = Geolocator.getPositionStream(
  locationSettings: androidSettings,
);
```

---

## Background Location Service

**File:** [lib/services/background_location_service.dart](../lib/services/background_location_service.dart)

### Purpose
Continuous GPS tracking even when app is in background (for drivers).

### Implementation

```dart
class BackgroundLocationService {
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );

  static const AndroidSettings _androidSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    intervalDuration: Duration(seconds: 10),
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationText: 'Tracking bus location',
      notificationTitle: 'Bus Tracking Active',
      enableWakeLock: true,
    ),
  );

  static StreamSubscription<Position>? _positionSubscription;

  static Future<void> initialize() async {
    await Permission.location.request();

    if (Platform.isAndroid) {
      await Permission.locationAlways.request();
    }
  }

  static Future<void> start() async {
    final settings = Platform.isAndroid
        ? _androidSettings
        : _locationSettings;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      print('Background location: ${position.latitude}, ${position.longitude}');
      _handleLocationUpdate(position);
    });
  }

  static Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  static Future<void> _handleLocationUpdate(Position position) async {
    // Send to backend or process locally
  }
}
```

### Usage

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BackgroundLocationService.initialize();
  await BackgroundLocationService.start();

  runApp(const BusTrackerApp());
}

// Stop when needed
await BackgroundLocationService.stop();
```

---

## Distance Calculation

### Haversine Formula

```dart
import 'dart:math';

double calculateDistance(
  double lat1, double lon1,
  double lat2, double lon2,
) {
  const R = 6371; // Earth radius in km

  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
      cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c; // Distance in km
}

double _toRadians(double degrees) {
  return degrees * pi / 180;
}
```

### Usage

```dart
final distance = calculateDistance(
  45.2733, -66.0633,  // Point A (Saint John, NB)
  45.2750, -66.0650,  // Point B
);

print('Distance: ${distance.toStringAsFixed(2)} km');
```

### Geolocator Distance

```dart
import 'package:geolocator/geolocator.dart';

double distance = Geolocator.distanceBetween(
  45.2733, -66.0633,  // Start lat, lng
  45.2750, -66.0650,  // End lat, lng
);

print('Distance: ${(distance / 1000).toStringAsFixed(2)} km'); // Convert m to km
```

---

## Periodic Location Updates

### Timer-Based Updates

```dart
import 'dart:async';

Timer? _locationTimer;

void _startPeriodicUpdates(int intervalSeconds) {
  _locationTimer = Timer.periodic(
    Duration(seconds: intervalSeconds),
    (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        _handleLocationUpdate(position);
      } catch (e) {
        print('Error getting location: $e');
      }
    },
  );
}

void _stopPeriodicUpdates() {
  _locationTimer?.cancel();
  _locationTimer = null;
}

Future<void> _handleLocationUpdate(Position position) async {
  // Send to backend
  await ApiService.createBusLocation(
    busId,
    position.latitude,
    position.longitude,
    position.speed * 3.6, // Convert to km/h
    position.heading,
  );
}
```

---

## Error Handling

### Common Errors

```dart
Future<void> _getLocation() async {
  try {
    final position = await Geolocator.getCurrentPosition();
    print('Location: ${position.latitude}, ${position.longitude}');
  } on LocationServiceDisabledException {
    print('Location services are disabled');
    _showError('Please enable location services');
  } on PermissionDeniedException {
    print('Location permission denied');
    _showError('Location permission is required');
  } on TimeoutException {
    print('Location request timed out');
    _showError('Could not get location');
  } catch (e) {
    print('Unknown error: $e');
    _showError('Failed to get location');
  }
}
```

---

## Testing Location

### Simulate Location (Development)

#### Android Emulator
1. Open Extended Controls (⋯ button)
2. Go to Location tab
3. Enter coordinates manually
4. Or load GPX/KML route

#### iOS Simulator
1. Debug → Location → Custom Location
2. Enter coordinates

#### Flutter Test
```dart
// Mock location for testing
final testPosition = Position(
  latitude: 45.2733,
  longitude: -66.0633,
  timestamp: DateTime.now(),
  accuracy: 5.0,
  altitude: 0.0,
  heading: 0.0,
  speed: 0.0,
  speedAccuracy: 0.0,
);
```

---

## Best Practices

### 1. Check Services Before Requesting
```dart
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
  // Prompt user to enable location services
  return;
}
```

### 2. Request Permissions Incrementally
```dart
// Start with when-in-use
await Permission.location.request();

// Later, request background (if needed)
if (needsBackgroundAccess) {
  await Permission.locationAlways.request();
}
```

### 3. Use Appropriate Accuracy
```dart
// High accuracy for tracking
LocationAccuracy.high

// Low accuracy for coarse location
LocationAccuracy.low
```

### 4. Set Distance Filter
```dart
// Only update when user moves 10 meters
distanceFilter: 10
```

### 5. Clean Up Listeners
```dart
@override
void dispose() {
  _positionSubscription?.cancel();
  _locationTimer?.cancel();
  super.dispose();
}
```

### 6. Handle Battery Impact
- Use lower accuracy when possible
- Increase distance filter
- Limit update frequency
- Stop tracking when not needed

### 7. Inform Users
- Explain why location is needed
- Show when tracking is active
- Provide option to stop tracking

---

## Battery Optimization

### Tips to Reduce Battery Drain

1. **Use Distance Filter:**
```dart
distanceFilter: 50, // Only update every 50 meters
```

2. **Reduce Frequency:**
```dart
intervalDuration: Duration(seconds: 30), // Update every 30s
```

3. **Lower Accuracy:**
```dart
accuracy: LocationAccuracy.medium, // Instead of high
```

4. **Stop When Idle:**
```dart
if (busSpeed < 1.0) {
  // Bus is stopped, reduce update frequency
  _locationTimer?.cancel();
}
```

5. **Use Geofencing:**
Only track when near route (advanced feature).
