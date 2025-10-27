# Tag Mobile Architecture

## Application Architecture

Tag Mobile follows Flutter's recommended architecture with clear separation of concerns:

```
Presentation Layer (Pages/Widgets)
         ↓
Business Logic Layer (Services)
         ↓
Data Layer (API / Local Storage)
```

---

## Architecture Patterns

### 1. Singleton Pattern

**AuthStore** ([lib/store/auth_store.dart](../lib/store/auth_store.dart))
```dart
class AuthStore extends ChangeNotifier {
  static final AuthStore _instance = AuthStore._internal();
  factory AuthStore() => _instance;

  AuthStore._internal();

  // Single source of truth for auth state
}
```

**Purpose:**
- Ensures single instance across the app
- Centralized authentication state
- Prevents multiple auth state sources

### 2. Service Layer Pattern

Each service handles a specific domain:
- **AuthService**: Authentication and token management
- **ApiService**: Bus and location data
- **BusTrackingService**: Real-time tracking logic
- **BackgroundLocationService**: GPS background tracking
- **RoutesService**: Route and stop data
- **UserSettingsService**: User preferences

**Benefits:**
- Separation of concerns
- Testable business logic
- Reusable across pages

### 3. ChangeNotifier Pattern

```dart
class AuthStore extends ChangeNotifier {
  User? _user;

  void login(User user) {
    _user = user;
    notifyListeners(); // Triggers UI rebuild
  }
}

// In widgets
ListenableBuilder(
  listenable: AuthStore(),
  builder: (context, child) {
    // Rebuilds when AuthStore changes
  },
)
```

### 4. Dependency Injection

```dart
// Services are stateless and can be called directly
final buses = await ApiService.getBuses();
final location = await ApiService.getCurrentBusLocation(busId);
```

**Benefits:**
- No complex DI framework needed
- Static methods for simplicity
- Clear dependencies

---

## App Structure

### Entry Point

**File:** [lib/main.dart](../lib/main.dart)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request location permissions
  await _requestLocationPermissions();

  // Initialize background location service
  await BackgroundLocationService.initialize();
  await BackgroundLocationService.start();

  runApp(const BusTrackerApp());
}
```

### App Widget

```dart
class BusTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusTracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AuthWrapper(),
    );
  }
}
```

### Authentication Wrapper

```dart
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthStore(),
      builder: (context, child) {
        final authStore = AuthStore();

        if (authStore.isAuthenticated) {
          return const MainScreen(); // Tab navigation
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
```

### Main Screen (Tab Navigation)

```dart
class MainScreen extends StatefulWidget {
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    final user = AuthStore().user;
    final roleId = user?.roleId ?? 0;

    // Role-based navigation
    if (Roles.isTracker(roleId)) {
      _pages = [
        const WelcomePage(),
        const AdvancedTrackerPage(), // Smart tracking
        const SettingsPage(),
      ];
    } else if (Roles.isDriver(roleId)) {
      _pages = [
        const WelcomePage(),
        const BusTrackingPage(), // Manual tracking
      ];
    } else {
      _pages = [const WelcomePage()];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: _getNavigationItems(),
      ),
    );
  }
}
```

---

## Data Flow

### Authentication Flow

```
1. User enters credentials in LoginPage
    ↓
2. AuthService.login(username, password)
    ↓
3. POST /auth/login to backend
    ↓
4. Receive token + user object
    ↓
5. Save to SharedPreferences
    ↓
6. AuthStore().login(user)
    ↓
7. notifyListeners() triggers rebuild
    ↓
8. AuthWrapper shows MainScreen
```

### Real-Time Tracking Flow

```
1. AdvancedTrackerPage initializes
    ↓
2. Load user settings (route, pickup stop, home)
    ↓
3. Fetch assigned bus with current location
    ↓
4. Load route points
    ↓
5. Start Timer (10-second interval)
    ↓
6. Each tick:
   - Fetch latest bus location
   - Calculate distance using Haversine
   - Calculate ETA considering route
   - Update map markers
   - Show personalized info
    ↓
7. User sees real-time updates
```

### GPS Tracking Flow (Driver)

```
1. BusTrackingPage opens
    ↓
2. User selects bus and frequency
    ↓
3. Request location permissions
    ↓
4. Start Timer at selected frequency
    ↓
5. Each tick:
   - Geolocator.getCurrentPosition()
   - Get lat, lng, speed, heading
   - ApiService.createBusLocation(busId, lat, lng, speed, direction)
   - Update UI with last known location
    ↓
6. Backend receives location updates
```

---

## State Management

### Local State (StatefulWidget)

Used for:
- Form inputs
- Loading states
- Page-specific data
- UI state (selected tab, expanded panels)

```dart
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _isLoading = false;
  List<Bus> _buses = [];

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() => _isLoading = true);
    try {
      final buses = await ApiService.getBuses();
      setState(() {
        _buses = buses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
```

### Global State (AuthStore)

Used for:
- Authentication state
- User information
- Token management

```dart
// Access auth state
final authStore = AuthStore();
final isAuthenticated = authStore.isAuthenticated;
final user = authStore.user;

// Update auth state
authStore.login(user);
authStore.logout();

// Listen to changes
ListenableBuilder(
  listenable: AuthStore(),
  builder: (context, child) {
    // Rebuilds when auth state changes
  },
)
```

---

## Navigation Architecture

### Tab-Based Navigation

Main screen uses `BottomNavigationBar` with role-specific tabs:

**Tracker Role:**
1. Home (WelcomePage)
2. Smart Track (AdvancedTrackerPage)
3. Settings (SettingsPage)

**Driver Role:**
1. Home (WelcomePage)
2. Track Bus (BusTrackingPage)

### Programmatic Navigation

```dart
// Navigate to login
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => const LoginPage()),
);

// Pop back
Navigator.pop(context);
```

---

## Service Architecture

### Stateless Services

All services use static methods for simplicity:

```dart
class ApiService {
  static Future<List<Bus>> getBuses() async {
    final response = await AuthService.authenticatedRequest('GET', '/bus/');
    // Parse and return
  }
}
```

**Benefits:**
- No instantiation needed
- Clear API
- Easy to test

### Service Composition

```dart
// BusTrackingService uses ApiService
class BusTrackingService {
  void startTracking() {
    _timer = Timer.periodic(Duration(seconds: _intervalSeconds), (timer) async {
      // Fetch location via ApiService
      final location = await ApiService.getCurrentBusLocation(_busId);
      _controller.add(location);
    });
  }
}
```

---

## Data Models

### Model Pattern

```dart
class Bus {
  final int id;
  final String busNumber;
  final int? routePathId;
  final BusLocation? currentLocation;

  Bus({
    required this.id,
    required this.busNumber,
    this.routePathId,
    this.currentLocation,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['Id'] ?? json['id'],
      busNumber: json['BusNumber'] ?? json['busNumber'],
      routePathId: json['RoutePathId'] ?? json['routePathId'],
      currentLocation: json['currentLocation'] != null
          ? BusLocation.fromJson(json['currentLocation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'BusNumber': busNumber,
      'RoutePathId': routePathId,
    };
  }
}
```

**Features:**
- Flexible JSON parsing (camelCase/PascalCase)
- Null safety
- Nested model support
- Bidirectional serialization

---

## Algorithms

### Haversine Distance Formula

**Purpose:** Calculate great-circle distance between two GPS coordinates

```dart
static double calculateDistance(
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
```

### Route-Based ETA Calculation

```dart
static Map<String, dynamic> calculateETAToPickupStop({
  required double busLat,
  required double busLng,
  required List<RoutePoint> routePoints,
  required int pickupStopId,
  double busSpeed = 30.0, // Default 30 km/h
}) {
  // 1. Find bus's closest position on route
  // 2. Sort route points by order
  // 3. Calculate cumulative time to pickup stop
  // 4. Add stop times at intermediate stops
  // 5. Return ETA in minutes
}
```

---

## Error Handling

### Try-Catch Pattern

```dart
Future<void> _loadData() async {
  try {
    final data = await ApiService.getData();
    setState(() => _data = data);
  } catch (e) {
    print('Error loading data: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load data')),
    );
  }
}
```

### Null Safety

```dart
// Safe navigation
final user = AuthStore().user;
final roleId = user?.roleId ?? 0;

// Null-aware operators
final location = bus.currentLocation?.latitude ?? 0.0;
```

---

## Performance Optimizations

### 1. Lazy Loading
```dart
late final List<Widget> _pages; // Initialized in initState
```

### 2. Const Constructors
```dart
const SizedBox(height: 16),
const Icon(Icons.location_on),
```

### 3. ListView.builder
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)
```

### 4. Stream Controllers
```dart
// BusTrackingService uses StreamController for efficient updates
final _controller = StreamController<BusLocation>.broadcast();
Stream<BusLocation> get locationStream => _controller.stream;
```

---

## Security Architecture

### Token Storage

```dart
// Secure storage in SharedPreferences
await prefs.setString('auth_token', token);
final token = prefs.getString('auth_token');
```

### Authenticated Requests

```dart
static Future<http.Response> authenticatedRequest(
  String method,
  String endpoint, {
  Map<String, dynamic>? body,
}) async {
  final token = await getToken();
  final headers = {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // Make request with token
}
```

### Role-Based Access

```dart
// Pages check role before rendering
if (!Roles.isTracker(user.roleId)) {
  return Center(child: Text('Unauthorized'));
}
```

---

## Module Dependencies

```
main.dart
  ├── AuthWrapper
  │     └── AuthStore (listenable)
  │           ├── LoginPage (not authenticated)
  │           └── MainScreen (authenticated)
  │                 ├── WelcomePage
  │                 ├── AdvancedTrackerPage (Tracker)
  │                 ├── BusTrackingPage (Driver)
  │                 └── SettingsPage (Tracker)
  │
  └── Services
        ├── AuthService
        ├── ApiService
        ├── BusTrackingService
        ├── BackgroundLocationService
        ├── RoutesService
        └── UserSettingsService
```

---

## Future Enhancements

### 1. State Management
Consider adding Provider or Riverpod for complex state

### 2. WebSocket Support
Replace polling with WebSocket for real-time updates

### 3. Offline Support
Cache data locally for offline functionality

### 4. Push Notifications
Alert users when bus is near their stop

### 5. Analytics
Track usage patterns and performance metrics
