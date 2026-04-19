// lib/common/services/notification_service.dart
//
// Handles:
//   1. FCM token registration → saved to users/{uid}/fcmToken in Firestore
//   2. Foreground message display (flutter_local_notifications)
//   3. Notification tap routing
//
// Push delivery is handled by Cloud Functions (see functions/index.js)
// which trigger on reservation state changes in Firestore.
//
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─── Background message handler (must be top-level) ───────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs.
  // Just print for now; flutter_local_notifications can't be used here
  // without additional setup.
  debugPrint('[FCM BG] ${message.messageId}: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId = 'parking_app_channel';
  static const _channelName = 'Parking App';
  static const _channelDesc = 'Reservations and parking notifications';

  // ── Init (call from main.dart AFTER Firebase.initializeApp) ───────────────
  Future<void> init() async {
    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permissions
    await _requestPermissions();

    // 3. Init local notifications
    await _initLocalNotifications();

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5. Handle notification tap when app in background (opened from notif)
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // 6. Save token to Firestore if user is signed in
    await _saveTokenIfSignedIn();

    // 7. Refresh token on change
    _fcm.onTokenRefresh.listen((token) => _saveToken(token));
  }

  // ── Save FCM token to Firestore ───────────────────────────────────────────
  Future<void> _saveTokenIfSignedIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token, uid: uid);
  }

  Future<void> _saveToken(String token, {String? uid}) async {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(resolvedUid).set(
        {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      debugPrint('[FCM] Token saved for $resolvedUid');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Call this after sign-in to ensure token is registered.
  Future<void> onSignIn() => _saveTokenIfSignedIn();

  /// Call this on sign-out to remove the token (stop notifications).
  Future<void> onSignOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _fcm.deleteToken();
    } catch (_) {}
  }

  // ── Permissions ───────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (Platform.isAndroid) {
      // Android 13+ requires explicit permission via local notifications plugin
      await _localNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  // ── Local notifications setup ─────────────────────────────────────────────
  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        // Tap while app is in foreground
        debugPrint('[LocalNotif] Tapped: ${details.payload}');
      },
    );

    // Create Android notification channel
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
  }

  // ── Foreground message handler ────────────────────────────────────────────
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    debugPrint('[FCM FG] ${notif.title}: ${notif.body}');

    await _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'],
    );
  }

  // ── Notification tap ──────────────────────────────────────────────────────
  void _onNotificationTap(RemoteMessage message) {
    // Add routing logic here if needed
    debugPrint('[FCM] Tapped notification: ${message.data}');
  }
}
