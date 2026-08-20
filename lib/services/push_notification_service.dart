import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screengate/supabase/supabase_config.dart';

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Received: ${message.messageId}');
}

const bool _pushNotificationsEnabled = bool.fromEnvironment(
  'ENABLE_PUSH',
  defaultValue: false,
);

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize push notifications
  Future<void> initialize() async {
    if (_initialized) return;

    if (!_pushNotificationsEnabled) {
      debugPrint(
          '[FCM] Skipping initialization. Configure Firebase and build with --dart-define=ENABLE_PUSH=true to enable push notifications.');
      _initialized = true;
      return;
    }

    // Disable FCM on web entirely (not supported in this environment)
    if (kIsWeb) {
      debugPrint('[FCM] Skipping initialization on web (not supported)');
      _initialized = true;
      return;
    }

    try {
      // Get FCM instance (mobile only)
      _fcm = FirebaseMessaging.instance;

      // Request permission (iOS)
      final settings = await _fcm!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] User declined notification permission');
        return;
      }

      // Initialize local notifications (for Android foreground)
      await _initializeLocalNotifications();

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Get FCM token
      _fcmToken = await _fcm!.getToken();
      debugPrint('[FCM] Token: $_fcmToken');

      // Save token to user profile in Supabase
      if (_fcmToken != null) {
        await _saveFcmToken(_fcmToken!);
      }

      // Listen for token refresh
      _fcm!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
        debugPrint('[FCM] Token refreshed: $newToken');
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (when app is in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state notification
      final initialMessage = await _fcm!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('[FCM] Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[FCM] Initialization error: $e');
      debugPrint('[FCM] Stack trace: $stackTrace');
      _fcm = null; // Ensure FCM is null on error
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Received: ${message.messageId}');
    debugPrint('[FCM Foreground] Title: ${message.notification?.title}');
    debugPrint('[FCM Foreground] Body: ${message.notification?.body}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Show local notification (Android foreground)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'screengate_default',
      'ScreenGate Notifications',
      channelDescription: 'General notifications for ScreenGate',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.messageId}');
    debugPrint('[FCM] Data: ${message.data}');

    // TODO: Navigate based on notification type/data
    // Example: if (message.data['type'] == 'mission') { navigate to mission }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        debugPrint('[FCM] Local notification tapped, data: $data');
        // TODO: Navigate based on data
      } catch (e) {
        debugPrint('[FCM] Error parsing notification payload: $e');
      }
    }
  }

  /// Save FCM token to user profile
  Future<void> _saveFcmToken(String token) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseConfig.client.from('users').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', userId);

      debugPrint('[FCM] Token saved to user profile');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// Delete FCM token on logout
  Future<void> deleteToken() async {
    try {
      if (_fcm != null) {
        await _fcm!.deleteToken();
      }

      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        await SupabaseConfig.client.from('users').update({
          'fcm_token': null,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('id', userId);
      }

      _fcmToken = null;
      debugPrint('[FCM] Token deleted');
    } catch (e) {
      debugPrint('[FCM] Error deleting token: $e');
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    if (_fcm == null) {
      debugPrint('[FCM] Cannot subscribe to topic: FCM not initialized');
      return;
    }
    try {
      await _fcm!.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_fcm == null) {
      debugPrint('[FCM] Cannot unsubscribe from topic: FCM not initialized');
      return;
    }
    try {
      await _fcm!.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error unsubscribing from topic: $e');
    }
  }
}
