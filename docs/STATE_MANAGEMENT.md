# State Management Guide

## Overview

Tag Mobile uses a hybrid state management approach:
- **AuthStore (ChangeNotifier)** for global authentication state
- **Local State (StatefulWidget)** for page-specific state

---

## AuthStore

**File:** [lib/store/auth_store.dart](../lib/store/auth_store.dart)

### Purpose
Centralized authentication state management with reactive UI updates.

### Implementation

```dart
import 'package:flutter/foundation.dart';

class User {
  final int id;
  final String login;
  final String email;
  final String name;
  final String lastName;
  final String role;
  final int roleId;

  User({
    required this.id,
    required this.login,
    required this.email,
    required this.name,
    required this.lastName,
    required this.role,
    required this.roleId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      login: json['login'],
      email: json['email'],
      name: json['name'],
      lastName: json['lastName'],
      role: json['role'],
      roleId: json['roleId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'email': email,
      'name': name,
      'lastName': lastName,
      'role': role,
      'roleId': roleId,
    };
  }
}

class AuthStore extends ChangeNotifier {
  static final AuthStore _instance = AuthStore._internal();
  factory AuthStore() => _instance;

  AuthStore._internal();

  User? _user;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  void login(User user) {
    _user = user;
    _isAuthenticated = true;
    notifyListeners(); // Triggers UI rebuild
  }

  void logout() {
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
```

### Singleton Pattern

**Why Singleton?**
- Ensures single instance across entire app
- Prevents multiple sources of truth
- Shared state accessible from anywhere

**How it Works:**
```dart
static final AuthStore _instance = AuthStore._internal();
factory AuthStore() => _instance;

// Always returns same instance
final authStore1 = AuthStore();
final authStore2 = AuthStore();
assert(identical(authStore1, authStore2)); // true
```

---

## Using AuthStore

### Login
```dart
import 'package:tag_mobile/store/auth_store.dart';

Future<void> _handleLogin() async {
  final response = await AuthService.login(username, password);

  if (response != null) {
    final user = User.fromJson(response['user']);
    AuthStore().login(user);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }
}
```

### Logout
```dart
Future<void> _handleLogout() async {
  await AuthService.logout();
  AuthStore().logout();

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
  );
}
```

### Access User Data
```dart
final authStore = AuthStore();

if (authStore.isAuthenticated && authStore.user != null) {
  print('Welcome, ${authStore.user!.name}');
  print('Role: ${authStore.user!.role}');
}
```

### Check Role
```dart
final user = AuthStore().user;
final roleId = user?.roleId ?? 0;

if (Roles.isTracker(roleId)) {
  // Show tracker features
} else if (Roles.isDriver(roleId)) {
  // Show driver features
}
```

---

## ChangeNotifier Pattern

### How It Works

1. **Extend ChangeNotifier:**
```dart
class AuthStore extends ChangeNotifier {
  // State variables
}
```

2. **Call notifyListeners():**
```dart
void login(User user) {
  _user = user;
  _isAuthenticated = true;
  notifyListeners(); // Triggers rebuild
}
```

3. **Listen in Widgets:**
```dart
ListenableBuilder(
  listenable: AuthStore(),
  builder: (context, child) {
    final authStore = AuthStore();
    return Text('User: ${authStore.user?.name}');
  },
)
```

### Benefits
- Simple and lightweight
- No external dependencies
- Built into Flutter SDK
- Reactive UI updates
- Easy to debug

---

## Reactive UI with ListenableBuilder

### AuthWrapper Example

```dart
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthStore(),
      builder: (context, child) {
        final authStore = AuthStore();

        if (authStore.isAuthenticated) {
          return const MainScreen();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
```

**How it Works:**
1. `ListenableBuilder` listens to `AuthStore()`
2. When `notifyListeners()` is called
3. Builder function re-executes
4. UI updates automatically

### Profile Card Example

```dart
class ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthStore(),
      builder: (context, child) {
        final user = AuthStore().user;

        if (user == null) {
          return SizedBox.shrink();
        }

        return Card(
          child: Column(
            children: [
              CircleAvatar(
                child: Text('${user.name[0]}${user.lastName[0]}'),
              ),
              Text('${user.name} ${user.lastName}'),
              Text(user.role),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Local State Management

### StatefulWidget

Used for page-specific state that doesn't need to be shared.

#### Example: BusTrackingPage

```dart
class BusTrackingPage extends StatefulWidget {
  @override
  State<BusTrackingPage> createState() => _BusTrackingPageState();
}

class _BusTrackingPageState extends State<BusTrackingPage> {
  List<Bus> _buses = [];
  bool _isLoading = false;
  Map<int, Timer> _trackingTimers = {};
  Map<int, Position> _lastLocations = {};

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  @override
  void dispose() {
    // Clean up timers
    _trackingTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
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

  void _startTracking(Bus bus) {
    // Update local state
    setState(() {
      _trackingTimers[bus.id] = Timer.periodic(...);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _buses.length,
      itemBuilder: (context, index) => BusItem(_buses[index]),
    );
  }
}
```

### When to Use Local State

✅ **Use Local State for:**
- Form inputs
- Loading states
- Page-specific data
- UI state (expanded/collapsed)
- Timers and animations
- Temporary data

❌ **Don't Use Local State for:**
- User authentication
- App-wide settings
- Shared data between pages

---

## State Persistence

### SharedPreferences

Used to persist data across app restarts.

#### Saving Data
```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', token);
}

Future<void> saveUser(User user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_data', json.encode(user.toJson()));
}
```

#### Loading Data
```dart
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

Future<User?> getUser() async {
  final prefs = await SharedPreferences.getInstance();
  final userStr = prefs.getString('user_data');

  if (userStr != null) {
    return User.fromJson(json.decode(userStr));
  }

  return null;
}
```

#### Clearing Data
```dart
Future<void> clearAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
  await prefs.remove('user_data');
}
```

---

## State Initialization

### Check Auth on App Start

```dart
class BusTrackerApp extends StatefulWidget {
  @override
  State<BusTrackerApp> createState() => _BusTrackerAppState();
}

class _BusTrackerAppState extends State<BusTrackerApp> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isAuth = await AuthService.isAuthenticated();

    if (isAuth) {
      final user = await AuthService.getUser();
      if (user != null) {
        AuthStore().login(User.fromJson(user));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AuthWrapper(),
    );
  }
}
```

---

## Best Practices

### 1. Single Source of Truth
```dart
// Good: AuthStore is single source
final user = AuthStore().user;

// Bad: Multiple sources of truth
final user1 = AuthStore().user;
final user2 = someOtherStore.user;
```

### 2. Immutability
```dart
// Good: Create new object
void updateUser(User newUser) {
  _user = newUser;
  notifyListeners();
}

// Avoid: Mutating existing object
void updateUserName(String name) {
  _user?.name = name; // Don't do this
  notifyListeners();
}
```

### 3. Clean Up Resources
```dart
@override
void dispose() {
  _timer?.cancel();
  _controller.dispose();
  super.dispose();
}
```

### 4. Loading States
```dart
bool _isLoading = false;

Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    final data = await fetchData();
    setState(() => _data = data);
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 5. Error Handling
```dart
String? _errorMessage;

Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final data = await fetchData();
    setState(() => _data = data);
  } catch (e) {
    setState(() => _errorMessage = e.toString());
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 6. Avoid setState in Build
```dart
// Bad
@override
Widget build(BuildContext context) {
  setState(() => _counter++); // Never do this
  return Text('$_counter');
}

// Good
@override
void initState() {
  super.initState();
  _incrementCounter();
}

void _incrementCounter() {
  setState(() => _counter++);
}
```

---

## Alternative: Provider Pattern

If your app grows more complex, consider using the Provider package:

```dart
// pubspec.yaml
dependencies:
  provider: ^6.0.0

// Wrap app
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthStore()),
  ],
  child: MyApp(),
)

// Consume in widgets
Consumer<AuthStore>(
  builder: (context, authStore, child) {
    return Text(authStore.user?.name ?? 'Guest');
  },
)

// Or
final authStore = Provider.of<AuthStore>(context);
```

**Benefits:**
- Better dependency injection
- Scoped providers
- More features (ProxyProvider, etc.)
- Industry standard for Flutter state management
