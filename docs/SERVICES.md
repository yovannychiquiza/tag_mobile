# Services Layer Documentation

## Overview

The services layer handles all business logic, API communication, and data management. All services use static methods for simplicity and clarity.

---

## AuthService

**File:** [lib/services/auth_service.dart](../lib/services/auth_service.dart)

### Purpose
User authentication, token management, and authenticated HTTP requests.

### Key Methods

#### login
```dart
static Future<bool> login(String username, String password) async
```
**Purpose:** Authenticate user with backend

**Flow:**
1. Send POST request to `/auth/login`
2. Receive token and user data
3. Save to SharedPreferences
4. Update AuthStore
5. Return success/failure

**Usage:**
```dart
final success = await AuthService.login('john', 'password123');
if (success) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen()));
}
```

#### logout
```dart
static Future<void> logout() async
```
**Purpose:** Clear authentication state

**Actions:**
- Remove 'auth_token' from SharedPreferences
- Remove 'user_data' from SharedPreferences
- Call AuthStore().logout()

#### isAuthenticated
```dart
static Future<bool> isAuthenticated() async
```
**Purpose:** Check if user has valid token

**Returns:** True if token exists in SharedPreferences

#### getToken
```dart
static Future<String?> getToken() async
```
**Purpose:** Retrieve stored JWT token

**Returns:** Token string or null

#### getUser
```dart
static Future<Map<String, dynamic>?> getUser() async
```
**Purpose:** Retrieve stored user data

**Returns:** User object as Map or null

#### authenticatedRequest
```dart
static Future<http.Response> authenticatedRequest(
  String method,
  String endpoint, {
  Map<String, dynamic>? body,
}) async
```
**Purpose:** Make authenticated HTTP request with Bearer token

**Supported Methods:** GET, POST, PUT, DELETE

**Headers:**
- Content-Type: application/json
- Authorization: Bearer {token}

**Usage:**
```dart
final response = await AuthService.authenticatedRequest(
  'GET',
  '/user-settings/',
);

final data = json.decode(response.body);
```

---

## ApiService

**File:** [lib/services/api_service.dart](../lib/services/api_service.dart)

### Purpose
Bus and location data management

### Data Models

#### Bus
```dart
class Bus {
  final int id;
  final String busNumber;
  final int? routePathId;
  final String? licensePlate;
  final String? model;
  final int? capacity;
  final bool isActive;
  final BusLocation? currentLocation;
}
```

#### BusLocation
```dart
class BusLocation {
  final int id;
  final int busId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? direction;
  final bool isActive;
  final DateTime updatedAt;
}
```

### Key Methods

#### getBuses
```dart
static Future<List<Bus>> getBuses() async
```
**Endpoint:** GET `/bus/`

**Returns:** List of all buses

#### getBusesWithLocation
```dart
static Future<List<Bus>> getBusesWithLocation() async
```
**Endpoint:** GET `/bus/with-location`

**Returns:** List of buses with their current location

**Response:**
```json
[
  {
    "Id": 1,
    "BusNumber": "BUS-101",
    "currentLocation": {
      "Latitude": 45.2733,
      "Longitude": -66.0633,
      "Speed": 30.5
    }
  }
]
```

#### getCurrentBusLocation
```dart
static Future<BusLocation> getCurrentBusLocation(int busId) async
```
**Endpoint:** GET `/bus/{busId}/current-location`

**Returns:** Latest GPS location for bus

**Throws:** Exception if location not found

#### createBusLocation
```dart
static Future<BusLocation> createBusLocation(
  int busId,
  double latitude,
  double longitude,
  double? speed,
  double? direction,
) async
```
**Endpoint:** POST `/bus/{busId}/locations`

**Body:**
```json
{
  "Latitude": 45.2733,
  "Longitude": -66.0633,
  "Speed": 30.5,
  "Direction": 90.0
}
```

**Returns:** Created BusLocation object

**Usage:**
```dart
final location = await ApiService.createBusLocation(
  busId: 1,
  latitude: 45.2733,
  longitude: -66.0633,
  speed: 30.5,
  direction: 90.0,
);
```

#### getBusLocations
```dart
static Future<List<BusLocation>> getBusLocations(int busId) async
```
**Endpoint:** GET `/bus/{busId}/locations`

**Returns:** Location history for bus

---

## BusTrackingService

**File:** [lib/services/bus_tracking_service.dart](../lib/services/bus_tracking_service.dart)

### Purpose
Real-time bus tracking logic with ETA calculations

### Data Models

#### RoutePoint
```dart
class RoutePoint {
  final int id;
  final int routePathId;
  final double latitude;
  final double longitude;
  final int? pointOrder;
  final String? pointName;
  final bool isStop;
  final int averageStopTime;
  final double averageSpeed;
  final int timeToNext;
  final double distanceToNext;
}
```

#### BusData
```dart
class BusData {
  final String busNumber;
  final int? routeId;
  final BusLocation? currentLocation;
  final double? etaMinutes;
}
```

### Key Methods

#### startTracking
```dart
void startTracking({int intervalSeconds = 10})
```
**Purpose:** Start periodic location updates

**Parameters:**
- `intervalSeconds`: Update frequency (default: 10)

**Usage:**
```dart
final service = BusTrackingService(busId: 1);
service.startTracking(intervalSeconds: 10);

service.locationStream.listen((location) {
  print('Bus location: ${location.latitude}, ${location.longitude}');
});
```

#### stopTracking
```dart
void stopTracking()
```
**Purpose:** Stop periodic updates and clean up

#### calculateDistance
```dart
static double calculateDistance(
  double lat1, double lon1,
  double lat2, double lon2,
)
```
**Purpose:** Calculate distance between two GPS coordinates using Haversine formula

**Returns:** Distance in kilometers

**Usage:**
```dart
final distance = BusTrackingService.calculateDistance(
  45.2733, -66.0633,  // Point A
  45.2750, -66.0650,  // Point B
);
print('Distance: ${distance.toStringAsFixed(2)} km');
```

#### calculateETAToPickupStop
```dart
static Map<String, dynamic> calculateETAToPickupStop({
  required double busLat,
  required double busLng,
  required List<RoutePoint> routePoints,
  required int pickupStopId,
  double busSpeed = 30.0,
})
```
**Purpose:** Calculate ETA to specific stop considering route

**Algorithm:**
1. Find bus's closest position on route
2. Sort route points by order
3. Calculate cumulative time through remaining segments
4. Add stop times at intermediate stops
5. Return rounded ETA in minutes

**Returns:**
```dart
{
  'eta': 15.0,  // Minutes to pickup stop
  'distance': 7.5,  // Kilometers to pickup stop
}
```

**Usage:**
```dart
final eta = BusTrackingService.calculateETAToPickupStop(
  busLat: 45.2733,
  busLng: -66.0633,
  routePoints: routePoints,
  pickupStopId: 5,
  busSpeed: 30.0,
);

print('ETA: ${eta['eta']} minutes');
```

---

## BackgroundLocationService

**File:** [lib/services/background_location_service.dart](../lib/services/background_location_service.dart)

### Purpose
Continuous GPS tracking in background (for drivers)

### Key Methods

#### initialize
```dart
static Future<void> initialize() async
```
**Purpose:** Request location permissions

**Permissions:**
- Android: ACCESS_FINE_LOCATION, ACCESS_BACKGROUND_LOCATION
- iOS: When in use, Always

**Usage:**
```dart
await BackgroundLocationService.initialize();
```

#### start
```dart
static Future<void> start() async
```
**Purpose:** Start background location tracking

**Configuration:**
- Accuracy: High
- Distance filter: 0 (capture all updates)
- Interval: 10 seconds
- Android foreground service: Enabled

**Usage:**
```dart
await BackgroundLocationService.start();
```

#### stop
```dart
static Future<void> stop() async
```
**Purpose:** Stop background tracking

---

## RoutesService

**File:** [lib/services/routes_service.dart](../lib/services/routes_service.dart)

### Purpose
Route and stop data management

### Data Models

#### RoutePath
```dart
class RoutePath {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
}
```

### Key Methods

#### getRoutes
```dart
static Future<List<RoutePath>> getRoutes() async
```
**Endpoint:** GET `/routepath/`

**Returns:** List of all routes

**Usage:**
```dart
final routes = await RoutesService.getRoutes();
for (var route in routes) {
  print('${route.name}: ${route.description}');
}
```

#### getRoutePoints
```dart
static Future<List<RoutePoint>> getRoutePoints(int routeId) async
```
**Endpoint:** GET `/routepath/{routeId}/points`

**Returns:** List of stops/waypoints for route, sorted by pointOrder

**Usage:**
```dart
final points = await RoutesService.getRoutePoints(1);
for (var point in points) {
  print('${point.pointName}: ${point.latitude}, ${point.longitude}');
}
```

---

## UserSettingsService

**File:** [lib/services/user_settings_service.dart](../lib/services/user_settings_service.dart)

### Purpose
User preferences and personalization

### Data Models

#### UserSettings
```dart
class UserSettings {
  final int id;
  final int userId;
  final int? routePathId;
  final int? pickupStopId;
  final double? homeLat;
  final double? homeLng;
  final String? routeName;
  final String? routeDescription;
  final DateTime updatedAt;
}
```

#### UserSettingsUpdate
```dart
class UserSettingsUpdate {
  final int? routePathId;
  final int? pickupStopId;
  final double? homeLat;
  final double? homeLng;
}
```

### Key Methods

#### getUserSettings
```dart
static Future<UserSettings?> getUserSettings() async
```
**Endpoint:** GET `/user-settings/` (authenticated)

**Returns:** Current user's settings or null if not configured

**Usage:**
```dart
final settings = await UserSettingsService.getUserSettings();
if (settings != null) {
  print('Pickup Stop: ${settings.pickupStopId}');
  print('Home: ${settings.homeLat}, ${settings.homeLng}');
}
```

#### updateUserSettings
```dart
static Future<void> updateUserSettings(UserSettingsUpdate settings) async
```
**Endpoint:** PUT `/user-settings/` (authenticated)

**Body:**
```json
{
  "RoutePathId": 1,
  "PickupStopId": 5,
  "HomeLat": 45.2750,
  "HomeLng": -66.0650
}
```

**Usage:**
```dart
await UserSettingsService.updateUserSettings(
  UserSettingsUpdate(
    routePathId: 1,
    pickupStopId: 5,
    homeLat: 45.2750,
    homeLng: -66.0650,
  ),
);
```

#### deleteUserSettings
```dart
static Future<void> deleteUserSettings() async
```
**Endpoint:** DELETE `/user-settings/` (authenticated)

**Purpose:** Clear all user settings

---

## Error Handling Patterns

### Try-Catch with User Feedback

```dart
Future<void> _loadBuses() async {
  try {
    final buses = await ApiService.getBuses();
    setState(() => _buses = buses);
  } catch (e) {
    print('Error loading buses: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load buses')),
    );
  }
}
```

### Null Safety

```dart
final location = await ApiService.getCurrentBusLocation(busId);
if (location == null) {
  throw Exception('Bus location not found');
}
```

### HTTP Status Codes

```dart
if (response.statusCode == 200) {
  return json.decode(response.body);
} else if (response.statusCode == 401) {
  throw Exception('Unauthorized');
} else if (response.statusCode == 404) {
  throw Exception('Not found');
} else {
  throw Exception('Server error: ${response.statusCode}');
}
```

---

## Best Practices

### 1. Always Use Try-Catch
```dart
try {
  final data = await ApiService.getData();
} catch (e) {
  // Handle error
}
```

### 2. Provide User Feedback
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Operation successful')),
);
```

### 3. Loading States
```dart
setState(() => _isLoading = true);
try {
  final data = await ApiService.getData();
} finally {
  setState(() => _isLoading = false);
}
```

### 4. Clean Up Resources
```dart
@override
void dispose() {
  _timer?.cancel();
  _controller.close();
  super.dispose();
}
```

### 5. Validate Input
```dart
if (latitude < -90 || latitude > 90) {
  throw Exception('Invalid latitude');
}
```
