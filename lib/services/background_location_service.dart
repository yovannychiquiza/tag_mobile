import 'dart:isolate';
import 'dart:ui';
import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:flutter/material.dart';

class BackgroundLocationService {
  static const String isolateName = 'LocatorIsolate';
  static ReceivePort port = ReceivePort();

  static Future<void> initialize() async {
    debugPrint('BackgroundLocationService: Initializing');
    IsolateNameServer.registerPortWithName(port.sendPort, isolateName);
    port.listen((dynamic data) {
      debugPrint('BackgroundLocationService: Received data from isolate: $data');
      // Handle data from background isolate if needed
    });
    await BackgroundLocator.initialize();
    debugPrint('BackgroundLocationService: Initialized');
  }

  static Future<void> start() async {
    debugPrint('BackgroundLocationService: Starting location updates');
    await BackgroundLocator.registerLocationUpdate(
      callback,
      androidSettings: AndroidSettings(
        interval: 5,
        distanceFilter: 0,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: 'Location tracking',
          notificationTitle: 'Location Tracking',
          notificationMsg: 'App is tracking your location in the background',
          notificationBigMsg: 'App is tracking your location in the background',
          notificationIcon: '@mipmap/ic_launcher', // Use your launcher icon or a custom one
        ),
      ),
      iosSettings: IOSSettings(
        distanceFilter: 0,
      ),
      autoStop: false,
    );
    debugPrint('BackgroundLocationService: Location updates started');
  }

  @pragma('vm:entry-point')
  static void callback(LocationDto locationDto) async {
    debugPrint('BackgroundLocationService: Callback triggered');
    debugPrint('Background location: \\${locationDto.latitude}, \\${locationDto.longitude}');
    // You can add logic here to save/send location
  }

  static Future<void> stop() async {
    await BackgroundLocator.unRegisterLocationUpdate();
  }
}

// NOTE: On some Android devices, battery optimizations can kill background services. Instruct users to exclude the app from battery optimization settings for best results.
