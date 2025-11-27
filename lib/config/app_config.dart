class AppConfig {
  static const String _devBaseUrl = 'http://192.168.2.10:8000';
  // static const String _devBaseUrl = 'https://tagback.onrender.com';
  static const String _prodBaseUrl = 'https://your-production-api.com';

  // Google Places API Key
  // Get your API key from: https://console.cloud.google.com/google/maps-apis/
  // Enable: Places API, Geocoding API
  static const String googlePlacesApiKey = 'AIzaSyAaqPk4VIypRekKkZsdXo9nrWXuJjm4p7k';

  // Automatically detect environment
  static String get baseUrl {
    // You can also use --dart-define for build-time configuration
    const String? configuredUrl = String.fromEnvironment('API_BASE_URL');

    if (configuredUrl != null && configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

    // Default to development URL
    return _devBaseUrl;
  }
  
  // Other configuration constants
  static const int defaultTrackingFrequency = 10; // seconds
  static const int minTrackingFrequency = 5;
  static const int maxTrackingFrequency = 300;
  
  // GPS settings
  static const double locationAccuracyThreshold = 10.0; // meters
  static const int locationTimeoutSeconds = 30;
  
  // Map settings  
  static const double defaultLatitude = 45.2733; // Saint John, NB
  static const double defaultLongitude = -66.0633;
  static const double defaultZoom = 13.0;
  
  // API timeouts
  static const int apiTimeoutSeconds = 30;
  static const int connectTimeoutSeconds = 10;
  
  static bool get isProduction {
    return baseUrl.contains('https') && !baseUrl.contains('localhost');
  }
  
  static bool get isDevelopment => !isProduction;
}

// Usage examples:
// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
// flutter build apk --dart-define=API_BASE_URL=https://api.yourserver.com