import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SystemNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static int _notificationIdCounter = 1000;

  static const String channelId = 'pasadanorte_critical_dispatch';
  static const String channelName = 'PasadaNorte Dispatch & Trips';
  static const String channelDescription =
      'Real-time alerts for active tricycle bookings, driver assignments, and Digital Pila queue progression.';

  /// Initializes the native phone notification plugin for Android & iOS.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
              'User tapped system notification with payload: ${response.payload}');
        },
      );

      // Create high-importance Android notification channel with default system sound
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _isInitialized = true;
      debugPrint('SystemNotificationService successfully initialized.');
    } catch (e) {
      debugPrint('SystemNotificationService initialization fallback: $e');
    }
  }

  static NotificationDetails _getNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.status,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Sends a native phone notification using the phone's default ringtone and vibration.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int? customId,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final id = customId ?? _notificationIdCounter++;
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _getNotificationDetails(),
        payload: payload,
      );
      debugPrint('System notification sent: [$title] - $body');
    } catch (e) {
      debugPrint('Failed to send system notification: $e');
    }
  }

  // ==========================================
  // 1. TRIP & BOOKING NOTIFICATIONS (PASSENGER)
  // ==========================================

  /// When driver accepts the booking while passenger is waiting or on another app.
  static Future<void> showDriverAcceptedNotification({
    required String driverName,
    required String bodyNumber,
  }) async {
    await showNotification(
      customId: 101,
      title: 'Tricycle Confirmed 🛺',
      body: 'Driver $driverName (#$bodyNumber) accepted your ride!',
      payload: 'trip_accepted',
    );
  }

  /// When driver arrives at the pickup point.
  static Future<void> showDriverArrivedNotification({
    required String driverName,
    required String pickupLocation,
  }) async {
    await showNotification(
      customId: 102,
      title: 'Driver Arrived 📍',
      body: '$driverName (#0042) has arrived at $pickupLocation.',
      payload: 'driver_arrived',
    );
  }

  /// When the trip officially begins.
  static Future<void> showTripStartedNotification({
    required String dropoffLocation,
  }) async {
    await showNotification(
      customId: 103,
      title: 'Trip in Progress 🛵',
      body: 'On the way to $dropoffLocation.',
      payload: 'trip_in_transit',
    );
  }

  /// When trip completes and fare is finalized.
  static Future<void> showTripCompletedNotification({
    required double fareAmount,
    String paymentMethod = 'Cash',
  }) async {
    await showNotification(
      customId: 104,
      title: 'Trip Completed ✅',
      body: 'Arrived safely at destination • ₱${fareAmount.toStringAsFixed(2)} $paymentMethod collected.',
      payload: 'trip_completed',
    );
  }

  // ===============================================
  // 2. DIGITAL PILA & DISPATCH NOTIFICATIONS (DRIVER)
  // ===============================================

  /// When driver enters geofence and gets queued in FIFO line.
  static Future<void> showQueuedInPilaNotification({
    required int rank,
    required String terminalName,
  }) async {
    await showNotification(
      customId: 201,
      title: 'Queued in Digital Pila 📋',
      body: 'You are Rank #$rank in line at $terminalName.',
      payload: 'pila_queued',
    );
  }

  /// When queue moves and driver reaches #1 priority spot.
  static Future<void> showRankOneNotification({
    required String terminalName,
  }) async {
    await showNotification(
      customId: 202,
      title: 'Pila Rank #1 Priority! 🥇',
      body: 'You are now #1 in line at $terminalName. Next commuter will be dispatched to you.',
      payload: 'pila_rank_one',
    );
  }

  /// When incoming ride offer arrives for the driver.
  static Future<void> showNewDispatchOfferNotification({
    required String passengerName,
    required String pickup,
    required double fare,
  }) async {
    await showNotification(
      customId: 203,
      title: 'New Commuter Dispatch Offer! 🔔',
      body: '$passengerName at $pickup • ₱${fare.toStringAsFixed(2)} fare. Tap to accept!',
      payload: 'dispatch_offer',
    );
  }
}
