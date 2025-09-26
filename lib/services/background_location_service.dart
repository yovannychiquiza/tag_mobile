import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class BackgroundLocationService {
  static StreamSubscription<Position>? _positionStream;

  static Future<void> initialize() async {
    debugPrint('BackgroundLocationService: Initializing');
    await Geolocator.requestPermission();
    debugPrint('BackgroundLocationService: Initialized');
  }

  static Future<void> start() async {
    debugPrint('BackgroundLocationService: Starting foreground location service');
    LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'App is tracking your location in the background',
        notificationTitle: 'Location Tracking',
        enableWakeLock: true,
      ),
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      debugPrint('Background location: \\${position.latitude}, \\${position.longitude}');
      // TODO: Handle location update (e.g., send to server, save locally, etc.)
    });
    debugPrint('BackgroundLocationService: Foreground location service started');
  }

  static Future<void> stop() async {
    await _positionStream?.cancel();
    debugPrint('BackgroundLocationService: Foreground location service stopped');
  }
}

// NOTE: For best results, instruct users to exclude the app from battery optimization settings.
// Also, ensure you have FOREGROUND_SERVICE and ACCESS_BACKGROUND_LOCATION permissions in AndroidManifest.xml.
