import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pages/welcome_page.dart';
import 'pages/bus_tracking_page.dart';
import 'pages/advanced_tracker_page.dart';
import 'pages/settings_page.dart';
import 'pages/login_page.dart';
import 'store/auth_store.dart';
import 'constants/roles.dart';
import 'services/background_location_service.dart';
import 'services/http_client.dart';
import 'widgets/navigation_drawer.dart';
import 'theme/app_colors.dart'; // Import the new AppColors

// Global navigator key for showing session expiration dialog
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await BackgroundLocationService.initialize();
  await BackgroundLocationService.start(); // Start background location updates

  // Set up session expiration handler
  _setupSessionExpirationHandler();

  runApp(const BusTrackerApp());
}

void _setupSessionExpirationHandler() {
  HttpClient.onSessionExpired = () async {
    final authStore = AuthStore();
    await authStore.forceLogout();

    // Show session expired dialog
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
              'Your session has expired. Please log in again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigation will be handled automatically by AuthWrapper
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  };
}

Future<void> _requestPermissions() async {
  final status = await Permission.location.request();
  if (status.isGranted) {
    // For Android 10+ request background location
    if (await Permission.locationAlways.isDenied) {
      await Permission.locationAlways.request();
    }
  } else {
    // Handle permission denied
    debugPrint('Location permission denied');
  }
}

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BusTracker Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final AuthStore _authStore;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _authStore = AuthStore();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authStore.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _authStore,
      builder: (context, child) {
        if (_authStore.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_authStore.isAuthenticated) {
          return const MainScreen();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final AuthStore _authStore;
  List<NavigationItem> _navigationItems = [];
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _authStore = AuthStore();
    _updateNavigationBasedOnRole();
  }

  void _updateNavigationBasedOnRole() {
    final user = _authStore.user;
    final roleId = user?['roleId'] as int?;
    
    _navigationItems = getNavigationItems(roleId);
    
    _screens = _navigationItems.map((item) {
      switch (item.page) {
        case 'home':
          return WelcomePage(onNavigate: _onNavigate);
        case 'bus_tracking':
          return const BusTrackingPage();
        case 'settings':
          return const SettingsPage();
        case 'tracker':
          return const AdvancedTrackerPage();
        default:
          return WelcomePage(onNavigate: _onNavigate);
      }
    }).toList();
    
    if (_selectedIndex >= _screens.length) {
      _selectedIndex = 0;
    }
  }

  void _onNavigate(int originalIndex) {
    final targetItem = _navigationItems.firstWhere(
      (item) => item.index == originalIndex,
      orElse: () => _navigationItems.first,
    );
    
    final screenIndex = _navigationItems.indexOf(targetItem);
    
    if (screenIndex >= 0 && screenIndex < _screens.length) {
      setState(() {
        _selectedIndex = screenIndex;
      });
    }
  }

  void _onSelectItem(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authStore,
      builder: (context, child) {
        _updateNavigationBasedOnRole();
        
        if (_screens.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('No access available for your role'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_navigationItems[_selectedIndex].label),
            backgroundColor: AppColors.primary,
          ),
          drawer: NavigationDrawerWidget(
            navigationItems: _navigationItems,
            onSelectItem: _onSelectItem,
            onLogout: () async {
              await _authStore.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          body: _screens[_selectedIndex],
        );
      },
    );
  }
}
