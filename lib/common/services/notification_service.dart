import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/reservations/reservations.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM BG] ${message.messageId}: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId = 'beygo_notifications';
  static const _channelName = 'BeyGo';
  static const _channelDesc = 'Notificaciones de reservas y parqueos de BeyGo';

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestPermissions();
    await _initLocalNotifications();
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onNotificationTap(initialMessage);
      });
    }

    // ✅ FIX: Auth state listener saves token whenever a user signs in.
    // This handles both first run and subsequent logins.
    // The 300ms delay lets Firestore rules settle for the new user.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _saveTokenWithRetry(user.uid);
      }
    });

    // Refresh token on FCM rotation
    _fcm.onTokenRefresh.listen((token) => _saveToken(token));
  }

  // ── Save with retry (fixes first-run failures) ────────────────────────────
  Future<void> _saveTokenWithRetry(String uid, {int retries = 3}) async {
    final token = await _fcm.getToken();
    if (token == null) return;

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] Token saved for $uid (attempt $attempt)');
        return;
      } catch (e) {
        debugPrint('[FCM] Attempt $attempt failed for $uid: $e');
        if (attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
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
  Future<void> onSignIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _saveTokenWithRetry(uid);
  }

  /// ✅ Call this BEFORE sign-out.
  /// Removes the FCM token from Firestore so this device stops receiving
  /// notifications for the user that is logging out.
  Future<void> onSignOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
            'fcmToken': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 4));
      debugPrint('[FCM] Token removed for $uid');
    } catch (e) {
      debugPrint('[FCM] Error removing token on sign-out: $e');
    }

    try {
      // Delete local token so a fresh one is generated on next login.
      await _fcm.deleteToken().timeout(const Duration(seconds: 4));
      debugPrint('[FCM] Local FCM token deleted');
    } catch (e) {
      debugPrint('[FCM] Error deleting local FCM token on sign-out: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[LocalNotif] Tapped: ${details.payload}');
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _navigateFromData(decoded);
          } else if (decoded is Map) {
            _navigateFromData(
              decoded.map((key, value) => MapEntry('$key', '$value')),
            );
          }
        } catch (e) {
          debugPrint('[LocalNotif] Payload parse error: $e');
        }
      },
    );

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

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    final prefs = AppPreferencesService.instance.loadState();
    if (!_shouldDisplayMessage(message, prefs)) {
      debugPrint('[FCM FG] Skipped by user preferences: ${message.data}');
      return;
    }

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
          playSound: prefs.notificationSoundEnabled,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: prefs.notificationSoundEnabled,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Tapped notification: ${message.data}');
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[FCM] Navigator not ready for payload: $data');
      return;
    }

    final route = (data['route'] as String? ?? '').trim();
    final reservationId = (data['reservationId'] as String? ?? '').trim();
    final type = (data['type'] as String? ?? '').trim();

    if (route == 'reservations') {
      nav.push(
        MaterialPageRoute(
          builder:
              (_) => ReservationsPage(
                initialReservationId:
                    reservationId.isEmpty ? null : reservationId,
              ),
        ),
      );
      return;
    }

    if (route == 'ownerRequests') {
      nav.push(
        MaterialPageRoute(
          builder:
              (_) => OwnerRequestsPage(
                initialReservationId:
                    reservationId.isEmpty ? null : reservationId,
                initialTab:
                    type == 'cancel_requested'
                        ? OwnerRequestTab.cancellations
                        : OwnerRequestTab.exits,
              ),
        ),
      );
      return;
    }

    if (route == 'ownerReservations') {
      nav.push(
        MaterialPageRoute(
          builder:
              (_) => OwnerReservationsPage(
                initialReservationId:
                    reservationId.isEmpty ? null : reservationId,
                initialTab:
                    type == 'new_reservation'
                        ? OwnerReservationsTab.pending
                        : OwnerReservationsTab.active,
              ),
        ),
      );
    }
  }

  bool _shouldDisplayMessage(
    RemoteMessage message,
    AppPreferencesState preferences,
  ) {
    if (!preferences.notificationsEnabled) return false;

    final category = _resolveCategory(message.data);
    switch (category) {
      case _NotificationCategory.reminder:
        return preferences.reservationRemindersEnabled;
      case _NotificationCategory.update:
        return preferences.appUpdatesEnabled;
      case _NotificationCategory.general:
        return true;
    }
  }

  _NotificationCategory _resolveCategory(Map<String, dynamic> data) {
    final raw =
        ((data['category'] ?? data['type'] ?? data['kind']) as String? ?? '')
            .toLowerCase();

    if (raw.contains('reservation') ||
        raw.contains('reminder') ||
        raw.contains('checkin') ||
        raw.contains('checkout')) {
      return _NotificationCategory.reminder;
    }

    if (raw.contains('update') ||
        raw.contains('system') ||
        raw.contains('news')) {
      return _NotificationCategory.update;
    }

    return _NotificationCategory.general;
  }
}

enum _NotificationCategory { reminder, update, general }
