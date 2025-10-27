# Pages & Features Documentation

## Overview

Tag Mobile has 5 main pages, each serving a specific purpose in the bus tracking workflow.

---

## LoginPage

**File:** [lib/pages/login_page.dart](../lib/pages/login_page.dart)

### Purpose
User authentication

### Features
- Username/password form
- Password visibility toggle
- App version display at bottom
- Gradient background
- Error handling with SnackBars
- Loading state during authentication

### UI Components
- TextField for username
- TextField for password (obscured by default)
- Eye icon to toggle password visibility
- Login button (disabled during loading)
- App version text at bottom

### Flow
1. User enters credentials
2. Tap "Login" button
3. Call `AuthService.login(username, password)`
4. On success: Navigate to MainScreen
5. On failure: Show error SnackBar

### Code Example
```dart
Future<void> _handleLogin() async {
  setState(() => _isLoading = true);

  try {
    final success = await AuthService.login(_usernameController.text, _passwordController.text);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      _showError('Invalid credentials');
    }
  } catch (e) {
    _showError('Login failed: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

---

## WelcomePage

**File:** [lib/pages/welcome_page.dart](../lib/pages/welcome_page.dart)

### Purpose
Dashboard with quick access to features

### Features
- User profile card with avatar
- Personalized greeting ("Welcome, John Doe")
- Role badge (color-coded by role)
- Animated entrance (fade + slide)
- GridView of feature cards
- Role-specific navigation

### UI Components
- **Profile Card:**
  - Circle avatar with user initials
  - User name and role
  - Colored role badge

- **Feature Cards (MenuCard):**
  - Icon
  - Title
  - Subtitle
  - Color
  - Tap to navigate

### Role-Based Cards

**Tracker Role:**
1. Smart Track - Real-time bus tracking
2. Settings - User preferences

**Driver Role:**
1. Track Bus - Manual bus tracking

### Code Example
```dart
GridView.count(
  crossAxisCount: 2,
  children: [
    if (Roles.isTracker(roleId))
      MenuCard(
        icon: Icons.location_on,
        title: 'Smart Track',
        subtitle: 'Track your bus',
        color: Colors.blue,
        onTap: () => onNavigate(1), // Go to tracker tab
      ),
    // ... more cards
  ],
)
```

---

## BusTrackingPage

**File:** [lib/pages/bus_tracking_page.dart](../lib/pages/bus_tracking_page.dart)

### Purpose
Manual bus tracking for drivers

### Features
- List all available buses
- Select bus to track
- Configurable tracking frequency (5s - 60s)
- Start/stop tracking per bus
- Real-time GPS location capture
- Display last known location with speed
- Interactive map preview (OpenStreetMap)
- Location markers for bus and user

### UI Components
- Dropdown to select tracking frequency
- List of buses with expansion tiles
- Map preview showing bus location
- Latitude, longitude, speed display
- Start/Stop tracking buttons

### Tracking Flow
1. User selects bus from list
2. Choose tracking frequency
3. Tap "Start Tracking"
4. App requests location permission
5. Timer starts at selected interval
6. Each tick:
   - Get current GPS position
   - Send to backend via `ApiService.createBusLocation()`
   - Update map marker
7. Tap "Stop Tracking" to end

### Map Integration
```dart
FlutterMap(
  options: MapOptions(
    center: LatLng(latitude, longitude),
    zoom: 15.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MarkerLayer(
      markers: [
        Marker(
          point: LatLng(busLat, busLng),
          builder: (ctx) => Icon(Icons.directions_bus, color: Colors.blue),
        ),
      ],
    ),
  ],
)
```

### Code Example
```dart
Future<void> _startTracking(Bus bus) async {
  final position = await Geolocator.getCurrentPosition();

  _trackingTimers[bus.id] = Timer.periodic(
    Duration(seconds: _trackingFrequency),
    (timer) async {
      final currentPosition = await Geolocator.getCurrentPosition();

      await ApiService.createBusLocation(
        bus.id,
        currentPosition.latitude,
        currentPosition.longitude,
        currentPosition.speed,
        currentPosition.heading,
      );

      setState(() {
        _lastLocations[bus.id] = currentPosition;
      });
    },
  );
}
```

---

## AdvancedTrackerPage

**File:** [lib/pages/advanced_tracker_page.dart](../lib/pages/advanced_tracker_page.dart)

### Purpose
Smart real-time tracking with ETA calculations

### Features

#### Real-Time Tracking
- 10-second update intervals
- Automatic bus location updates
- Distance calculations using Haversine formula
- ETA calculations considering route

#### Personalized Information
- Walking distance from home to pickup stop
- Personalized ETA including walking time
- "When to leave home" calculation
- Time-sensitive alerts when departure is imminent

#### Map Visualization
- Full route map with OpenStreetMap
- Route polyline showing complete path
- Color-coded stop markers:
  - Orange: User's pickup stop
  - Red: Other stops
  - Green: Bus current position
- Zoom to fit route or center on bus

#### Route Schema
- Vertical timeline of all stops
- Current bus position highlighted
- Stop names and order
- Click to highlight on map

#### Control Toggles
- Live tracking on/off
- Notifications enable/disable
- Show/hide route on map
- Center map on bus vs free navigation

#### Status Cards
- Distance to pickup stop
- ETA in minutes
- Current bus speed
- Next stop name

### UI Layout
```
AppBar
  ↓
Status Cards (Grid)
  ↓
Map (Full route + bus marker)
  ↓
Control Toggles (Switch buttons)
  ↓
Route Schema (Vertical list)
```

### ETA Calculation
```dart
final eta = BusTrackingService.calculateETAToPickupStop(
  busLat: busLocation.latitude,
  busLng: busLocation.longitude,
  routePoints: _routePoints,
  pickupStopId: _pickupStopId,
  busSpeed: busLocation.speed ?? 30.0,
);

// Personalized ETA with walking time
final walkingDistance = BusTrackingService.calculateDistance(
  _homeLat, _homeLng,
  pickupStopLat, pickupStopLng,
);

final walkingTimeMinutes = (walkingDistance / 5.0) * 60; // 5 km/h walking speed
final timeToLeaveHome = eta['eta'] - walkingTimeMinutes;

if (timeToLeaveHome <= 5 && timeToLeaveHome > 0) {
  _showAlert('Leave home in ${timeToLeaveHome.toStringAsFixed(0)} minutes!');
}
```

### Code Example
```dart
void _startLiveTracking() {
  _trackingTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
    final location = await ApiService.getCurrentBusLocation(_busId);

    setState(() {
      _busLocation = location;
      _calculateETA();
      _updateMapMarkers();
    });
  });
}
```

---

## SettingsPage

**File:** [lib/pages/settings_page.dart](../lib/pages/settings_page.dart)

### Purpose
User configuration and preferences

### Features

#### Route Selection
- Dropdown of available routes
- Loads route points when route selected

#### Pickup Stop Selection
- Dropdown of stops in selected route
- Only shows stops (IsStop = true)

#### Home Location
- Manual coordinate input (latitude/longitude)
- GPS capture button ("Use Current Location")
- Coordinate validation (lat: -90 to 90, lng: -180 to 180)

#### Current Settings Display
- Shows persisted settings on load
- Real-time preview of selections

#### Actions
- Save button
- Reset button (clear all settings with confirmation)
- Logout button (with confirmation dialog)

### UI Components
- Dropdown for route selection
- Dropdown for pickup stop selection
- TextField for home latitude
- TextField for home longitude
- "Use Current Location" button
- Save settings button
- Reset settings button
- Logout button

### Validation
```dart
bool _validateCoordinates() {
  final lat = double.tryParse(_homeLatController.text);
  final lng = double.tryParse(_homeLngController.text);

  if (lat == null || lng == null) {
    _showError('Invalid coordinates');
    return false;
  }

  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    _showError('Coordinates out of range');
    return false;
  }

  return true;
}
```

### Save Flow
```dart
Future<void> _saveSettings() async {
  if (!_validateCoordinates()) return;

  try {
    await UserSettingsService.updateUserSettings(
      UserSettingsUpdate(
        routePathId: _selectedRouteId,
        pickupStopId: _selectedStopId,
        homeLat: double.parse(_homeLatController.text),
        homeLng: double.parse(_homeLngController.text),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings saved successfully')),
    );
  } catch (e) {
    _showError('Failed to save settings: $e');
  }
}
```

### GPS Capture
```dart
Future<void> _useCurrentLocation() async {
  try {
    final position = await Geolocator.getCurrentPosition();

    setState(() {
      _homeLatController.text = position.latitude.toString();
      _homeLngController.text = position.longitude.toString();
    });
  } catch (e) {
    _showError('Failed to get location: $e');
  }
}
```

### Reset Settings
```dart
Future<void> _resetSettings() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reset Settings'),
      content: Text('Are you sure? This will clear all your preferences.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Reset'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await UserSettingsService.deleteUserSettings();
    _loadSettings(); // Reload empty state
  }
}
```

---

## Common UI Patterns

### Loading State
```dart
if (_isLoading) {
  return Center(child: CircularProgressIndicator());
}
```

### Error Display
```dart
void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}
```

### Success Message
```dart
void _showSuccess(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ),
  );
}
```

### Confirmation Dialog
```dart
Future<bool?> _confirmAction(String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Confirm'),
        ),
      ],
    ),
  );
}
```

---

## Navigation Between Pages

### Tab Navigation (MainScreen)
```dart
_pages[_currentIndex] // Displays current page
```

### Programmatic Navigation
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => const LoginPage()),
);
```

### Pop Back
```dart
Navigator.pop(context);
```
