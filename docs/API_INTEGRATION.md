# API Integration Guide

## Overview

Tag Mobile communicates with the TagBack FastAPI backend via HTTP requests using the `http` package. All API calls are centralized in service modules.

---

## Configuration

**File:** [lib/config/app_config.dart](../lib/config/app_config.dart)

### API Base URL

```dart
class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://192.168.2.10:8000'; // Development
  // static const String baseUrl = 'https://your-production-api.com'; // Production

  static const int apiTimeoutSeconds = 30;
  static const int connectTimeoutSeconds = 10;

  // Environment
  static bool get isProduction => baseUrl.contains('https://');
  static bool get isDevelopment => !isProduction;
}
```

### Environment-Specific URLs

```bash
# Development
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000

# Production
flutter build apk --dart-define=API_BASE_URL=https://api.yourserver.com
```

**Access in code:**
```dart
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.2.10:8000',
);
```

---

## HTTP Client Setup

### Basic Request

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> _makeRequest() async {
  final url = Uri.parse('${AppConfig.baseUrl}/endpoint');

  final response = await http.get(url).timeout(
    Duration(seconds: AppConfig.apiTimeoutSeconds),
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Request failed: ${response.statusCode}');
  }
}
```

### Authenticated Request

```dart
import 'package:tag_mobile/services/auth_service.dart';

Future<Map<String, dynamic>> _makeAuthenticatedRequest() async {
  final response = await AuthService.authenticatedRequest(
    'GET',
    '/user-settings/',
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Request failed');
  }
}
```

---

## AuthService API

**File:** [lib/services/auth_service.dart](../lib/services/auth_service.dart)

### Login

**Endpoint:** `POST /auth/login`

**Request:**
```dart
final response = await http.post(
  Uri.parse('${AppConfig.baseUrl}/auth/login'),
  headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  body: {
    'username': username,
    'password': password,
  },
);
```

**Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "login": "john",
    "email": "john@example.com",
    "name": "John",
    "lastName": "Doe",
    "role": "Tracker",
    "roleId": 2
  }
}
```

**Usage:**
```dart
final success = await AuthService.login('john', 'password123');
if (success) {
  // Navigate to MainScreen
}
```

### Authenticated Request

```dart
static Future<http.Response> authenticatedRequest(
  String method,
  String endpoint, {
  Map<String, dynamic>? body,
}) async {
  final token = await getToken();
  final url = Uri.parse('${AppConfig.baseUrl}$endpoint');

  final headers = {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  http.Response response;

  switch (method.toUpperCase()) {
    case 'GET':
      response = await http.get(url, headers: headers);
      break;
    case 'POST':
      response = await http.post(url, headers: headers, body: json.encode(body));
      break;
    case 'PUT':
      response = await http.put(url, headers: headers, body: json.encode(body));
      break;
    case 'DELETE':
      response = await http.delete(url, headers: headers);
      break;
    default:
      throw Exception('Unsupported HTTP method: $method');
  }

  return response;
}
```

---

## Bus API

**File:** [lib/services/api_service.dart](../lib/services/api_service.dart)

### Get All Buses

**Endpoint:** `GET /bus/`

```dart
static Future<List<Bus>> getBuses() async {
  final response = await AuthService.authenticatedRequest('GET', '/bus/');

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Bus.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load buses');
  }
}
```

**Response:**
```json
[
  {
    "Id": 1,
    "BusNumber": "BUS-101",
    "RoutePathId": 1,
    "LicensePlate": "ABC-123",
    "Model": "Blue Bird",
    "Capacity": 45,
    "IsActive": true
  }
]
```

### Get Buses with Location

**Endpoint:** `GET /bus/with-location`

```dart
static Future<List<Bus>> getBusesWithLocation() async {
  final response = await AuthService.authenticatedRequest(
    'GET',
    '/bus/with-location',
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Bus.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load buses with location');
  }
}
```

**Response:**
```json
[
  {
    "Id": 1,
    "BusNumber": "BUS-101",
    "currentLocation": {
      "Id": 100,
      "Latitude": 45.2733,
      "Longitude": -66.0633,
      "Speed": 30.5,
      "Direction": 90.0,
      "UpdatedAt": "2025-10-27T10:30:00"
    }
  }
]
```

### Get Current Bus Location

**Endpoint:** `GET /bus/{busId}/current-location`

```dart
static Future<BusLocation> getCurrentBusLocation(int busId) async {
  final response = await AuthService.authenticatedRequest(
    'GET',
    '/bus/$busId/current-location',
  );

  if (response.statusCode == 200) {
    return BusLocation.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to get bus location');
  }
}
```

### Create Bus Location

**Endpoint:** `POST /bus/{busId}/locations`

```dart
static Future<BusLocation> createBusLocation(
  int busId,
  double latitude,
  double longitude,
  double? speed,
  double? direction,
) async {
  final body = {
    'Latitude': latitude,
    'Longitude': longitude,
    if (speed != null) 'Speed': speed,
    if (direction != null) 'Direction': direction,
  };

  final response = await AuthService.authenticatedRequest(
    'POST',
    '/bus/$busId/locations',
    body: body,
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    return BusLocation.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to create bus location');
  }
}
```

**Usage:**
```dart
final location = await ApiService.createBusLocation(
  1,                 // busId
  45.2733,          // latitude
  -66.0633,         // longitude
  30.5,             // speed (km/h)
  90.0,             // direction (degrees)
);
```

---

## Routes API

**File:** [lib/services/routes_service.dart](../lib/services/routes_service.dart)

### Get All Routes

**Endpoint:** `GET /routepath/`

```dart
static Future<List<RoutePath>> getRoutes() async {
  final response = await AuthService.authenticatedRequest('GET', '/routepath/');

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => RoutePath.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load routes');
  }
}
```

### Get Route Points

**Endpoint:** `GET /routepath/{routeId}/points`

```dart
static Future<List<RoutePoint>> getRoutePoints(int routeId) async {
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
}
```

**Response:**
```json
[
  {
    "Id": 1,
    "RoutePathId": 1,
    "Latitude": 45.2733,
    "Longitude": -66.0633,
    "PointOrder": 1,
    "PointName": "Main Street Stop",
    "IsStop": true,
    "AverageStopTime": 2,
    "AverageSpeed": 30.0,
    "TimeToNext": 3,
    "DistanceToNext": 1.5
  }
]
```

---

## User Settings API

**File:** [lib/services/user_settings_service.dart](../lib/services/user_settings_service.dart)

### Get User Settings

**Endpoint:** `GET /user-settings/` (Authenticated)

```dart
static Future<UserSettings?> getUserSettings() async {
  try {
    final response = await AuthService.authenticatedRequest(
      'GET',
      '/user-settings/',
    );

    if (response.statusCode == 200) {
      return UserSettings.fromJson(json.decode(response.body));
    } else {
      return null;
    }
  } catch (e) {
    print('Error fetching user settings: $e');
    return null;
  }
}
```

### Update User Settings

**Endpoint:** `PUT /user-settings/` (Authenticated)

```dart
static Future<void> updateUserSettings(UserSettingsUpdate settings) async {
  final body = {
    if (settings.routePathId != null) 'RoutePathId': settings.routePathId,
    if (settings.pickupStopId != null) 'PickupStopId': settings.pickupStopId,
    if (settings.homeLat != null) 'HomeLat': settings.homeLat,
    if (settings.homeLng != null) 'HomeLng': settings.homeLng,
  };

  final response = await AuthService.authenticatedRequest(
    'PUT',
    '/user-settings/',
    body: body,
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update user settings');
  }
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

---

## Error Handling

### HTTP Status Codes

```dart
Future<List<Bus>> _fetchBuses() async {
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // Success
    return _parseBuses(response.body);
  } else if (response.statusCode == 401) {
    // Unauthorized
    throw Exception('Please login again');
  } else if (response.statusCode == 404) {
    // Not found
    throw Exception('Resource not found');
  } else if (response.statusCode >= 500) {
    // Server error
    throw Exception('Server error. Please try again later.');
  } else {
    throw Exception('Request failed: ${response.statusCode}');
  }
}
```

### Network Errors

```dart
import 'dart:io';

Future<void> _fetchData() async {
  try {
    final response = await http.get(url);
    // Process response
  } on SocketException {
    throw Exception('No internet connection');
  } on TimeoutException {
    throw Exception('Request timed out');
  } on FormatException {
    throw Exception('Invalid response format');
  } catch (e) {
    throw Exception('Unknown error: $e');
  }
}
```

### User-Friendly Error Messages

```dart
Future<void> _loadBuses() async {
  try {
    final buses = await ApiService.getBuses();
    setState(() => _buses = buses);
  } catch (e) {
    String errorMessage;

    if (e.toString().contains('No internet')) {
      errorMessage = 'No internet connection';
    } else if (e.toString().contains('401')) {
      errorMessage = 'Session expired. Please login again.';
    } else {
      errorMessage = 'Failed to load buses';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }
}
```

---

## Timeouts

### Request Timeout

```dart
final response = await http.get(url).timeout(
  Duration(seconds: 30),
  onTimeout: () {
    throw TimeoutException('Request timed out');
  },
);
```

### Global Timeout Configuration

```dart
class AppConfig {
  static const int apiTimeoutSeconds = 30;
}

final response = await http.get(url).timeout(
  Duration(seconds: AppConfig.apiTimeoutSeconds),
);
```

---

## Retries

### Simple Retry Logic

```dart
Future<http.Response> _fetchWithRetry(String url, {int maxRetries = 3}) async {
  int attempt = 0;

  while (attempt < maxRetries) {
    try {
      final response = await http.get(Uri.parse(url));
      return response;
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) {
        rethrow;
      }
      await Future.delayed(Duration(seconds: 2)); // Wait before retry
    }
  }

  throw Exception('Failed after $maxRetries attempts');
}
```

---

## JSON Parsing

### Flexible Parsing (camelCase/PascalCase)

```dart
class Bus {
  final int id;
  final String busNumber;

  Bus({required this.id, required this.busNumber});

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['Id'] ?? json['id'],
      busNumber: json['BusNumber'] ?? json['busNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'BusNumber': busNumber,
    };
  }
}
```

### Null Safety

```dart
factory BusLocation.fromJson(Map<String, dynamic> json) {
  return BusLocation(
    id: json['Id'] ?? 0,
    latitude: (json['Latitude'] ?? 0.0).toDouble(),
    longitude: (json['Longitude'] ?? 0.0).toDouble(),
    speed: json['Speed']?.toDouble(),
    direction: json['Direction']?.toDouble(),
    updatedAt: json['UpdatedAt'] != null
        ? DateTime.parse(json['UpdatedAt'])
        : DateTime.now(),
  );
}
```

---

## Best Practices

### 1. Centralize API Calls
```dart
// Good: Centralized in services
await ApiService.getBuses();

// Bad: Direct HTTP calls in widgets
await http.get(Uri.parse('$baseUrl/bus/'));
```

### 2. Use Try-Catch
```dart
try {
  final data = await ApiService.getData();
} catch (e) {
  // Handle error
}
```

### 3. Show Loading States
```dart
setState(() => _isLoading = true);
try {
  final data = await ApiService.getData();
} finally {
  setState(() => _isLoading = false);
}
```

### 4. Provide User Feedback
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Operation successful')),
);
```

### 5. Validate Responses
```dart
if (response.statusCode == 200) {
  final data = json.decode(response.body);
  if (data is List && data.isNotEmpty) {
    // Process data
  }
}
```

### 6. Use Timeouts
```dart
final response = await http.get(url).timeout(Duration(seconds: 30));
```

### 7. Clean Up Resources
```dart
@override
void dispose() {
  _httpClient?.close();
  super.dispose();
}
```
