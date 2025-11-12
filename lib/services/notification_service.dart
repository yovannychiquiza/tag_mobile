import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    _initialized = true;
  }

  // Request notification permissions (especially for Android 13+)
  static Future<bool> requestPermissions() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  // Show a simple notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Ensure initialized
    if (!_initialized) {
      await initialize();
    }

    // Request permissions
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      print('Notification permission denied');
      return;
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'bus_tracker_channel', // Channel ID
      'Bus Tracker', // Channel name
      channelDescription: 'Notifications for bus tracking updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Combined notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show the notification
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Show bus tracking notification
  static Future<void> showBusTrackingNotification({
    required String busNumber,
    required int eta,
    required double distance,
  }) async {
    await showNotification(
      id: 1,
      title: 'Bus $busNumber Tracking',
      body: 'Your bus is ${distance.toStringAsFixed(1)} km away. ETA: $eta minutes',
      payload: 'bus_tracking',
    );
  }

  // Show ETA alert notification
  static Future<void> showETAAlert({
    required String busNumber,
    required int minutesToLeave,
  }) async {
    String body;
    if (minutesToLeave <= 0) {
      body = 'Leave home NOW! Bus $busNumber is arriving soon.';
    } else {
      body = 'Leave home in $minutesToLeave minutes to catch Bus $busNumber on time!';
    }

    await showNotification(
      id: 2,
      title: '🚌 Time to Leave!',
      body: body,
      payload: 'eta_alert',
    );
  }

  // Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
