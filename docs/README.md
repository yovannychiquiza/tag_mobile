# Tag Mobile App Documentation

## Overview
BusTracker Mobile is a Flutter-based cross-platform mobile application for real-time school bus tracking. It features GPS tracking, real-time ETA calculations, personalized route information, and role-based access for trackers and drivers.

## Technology Stack
- **Framework**: Flutter (Dart >=3.3.4 <4.0.0)
- **Platform**: Cross-platform (Android/iOS)
- **Mapping**: flutter_map 6.1.0 (OpenStreetMap)
- **Location**: geolocator 10.1.0
- **HTTP Client**: http 1.1.0
- **State Management**: ChangeNotifier (Provider pattern)
- **Storage**: shared_preferences 2.2.2

## Quick Start

### Prerequisites
- Flutter SDK 3.3.4+
- Dart SDK 3.3.4+
- Android Studio / Xcode
- Physical device or emulator

### Installation
```bash
cd tag_mobile
flutter pub get
```

### Run on Device/Emulator
```bash
flutter run
```

### Build APK (Android)
```bash
flutter build apk --release
```

### Build iOS
```bash
flutter build ios --release
```

### Run Tests
```bash
flutter test
```

## Project Structure
```
tag_mobile/lib/
├── main.dart                          # App entry point
├── pages/                             # Screen components
│   ├── login_page.dart               # Authentication
│   ├── welcome_page.dart             # Dashboard
│   ├── bus_tracking_page.dart        # Manual tracking (Driver)
│   ├── advanced_tracker_page.dart    # Smart tracking (Tracker)
│   └── settings_page.dart            # User preferences
├── services/                          # Business logic & API
│   ├── auth_service.dart             # Authentication
│   ├── api_service.dart              # Bus & location APIs
│   ├── bus_tracking_service.dart     # Real-time tracking
│   ├── background_location_service.dart # GPS background
│   ├── routes_service.dart           # Route data
│   └── user_settings_service.dart    # User preferences
├── store/                             # State management
│   └── auth_store.dart               # Auth state (singleton)
├── components/                        # Reusable widgets
│   └── menu_card.dart                # Menu card widget
├── constants/                         # App constants
│   └── roles.dart                    # Role definitions
└── config/                            # Configuration
    └── app_config.dart               # API URLs, defaults
```

## Key Features
- JWT-based authentication with persistent sessions
- Real-time GPS bus tracking with 10-second updates
- Haversine-based distance calculations
- Route-based ETA calculations considering stops and speed
- Personalized ETA with walking time from home
- Interactive OpenStreetMap integration
- Background GPS tracking for drivers
- Role-based access (Tracker, Driver)
- User settings and preferences

## Environment Configuration
```dart
// lib/config/app_config.dart
static const String baseUrl = 'http://192.168.2.10:8000'; // Development
// static const String baseUrl = 'https://your-production-api.com'; // Production
```

## Documentation Files
- [Architecture](ARCHITECTURE.md) - Application architecture and patterns
- [Pages & Features](PAGES.md) - Screen-by-screen guide
- [Services](SERVICES.md) - Service layer documentation
- [State Management](STATE_MANAGEMENT.md) - Auth store and state
- [GPS & Location](GPS_LOCATION.md) - Location tracking guide
- [API Integration](API_INTEGRATION.md) - Backend communication

## Platform-Specific Setup

### Android
Minimum SDK: 21 (Android 5.0)
Target SDK: 34

**Permissions required:**
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION` (Android 10+)
- `FOREGROUND_SERVICE`
- `INTERNET`

### iOS
Deployment Target: iOS 12.0+

**Info.plist keys:**
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

## Build Configuration

### Development Build
```bash
flutter run --debug
```

### Release Build
```bash
flutter build apk --release
flutter build appbundle --release  # For Play Store
flutter build ios --release
```

### Custom API URL
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

## Version
Current: 1.0.3+1
