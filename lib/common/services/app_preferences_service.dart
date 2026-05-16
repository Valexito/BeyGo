import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { system, light, dark }

class AppPreferencesState {
  final AppThemePreference themePreference;
  final bool notificationSoundEnabled;
  final bool notificationsEnabled;
  final bool reservationRemindersEnabled;
  final bool appUpdatesEnabled;
  final bool ownerRevenueVisible;
  final String? ownerRevenuePin;

  const AppPreferencesState({
    required this.themePreference,
    required this.notificationSoundEnabled,
    required this.notificationsEnabled,
    required this.reservationRemindersEnabled,
    required this.appUpdatesEnabled,
    required this.ownerRevenueVisible,
    required this.ownerRevenuePin,
  });

  ThemeMode get themeMode {
    switch (themePreference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  AppPreferencesState copyWith({
    AppThemePreference? themePreference,
    bool? notificationSoundEnabled,
    bool? notificationsEnabled,
    bool? reservationRemindersEnabled,
    bool? appUpdatesEnabled,
    bool? ownerRevenueVisible,
    String? ownerRevenuePin,
    bool clearOwnerRevenuePin = false,
  }) {
    return AppPreferencesState(
      themePreference: themePreference ?? this.themePreference,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reservationRemindersEnabled:
          reservationRemindersEnabled ?? this.reservationRemindersEnabled,
      appUpdatesEnabled: appUpdatesEnabled ?? this.appUpdatesEnabled,
      ownerRevenueVisible: ownerRevenueVisible ?? this.ownerRevenueVisible,
      ownerRevenuePin:
          clearOwnerRevenuePin ? null : ownerRevenuePin ?? this.ownerRevenuePin,
    );
  }
}

class AppPreferencesService {
  AppPreferencesService._();

  static final AppPreferencesService instance = AppPreferencesService._();

  static const _themeKey = 'app.theme_preference';
  static const _notificationSoundKey = 'app.notifications.sound';
  static const _notificationsEnabledKey = 'app.notifications.enabled';
  static const _reservationRemindersKey = 'app.notifications.reminders';
  static const _appUpdatesKey = 'app.notifications.updates';
  static const _ownerRevenueVisibleKey = 'owner.dashboard.revenue_visible';
  static const _ownerRevenuePinKey = 'owner.dashboard.revenue_pin';
  static const _locationDisclosureAcceptedKey =
      'app.location_disclosure_accepted';
  static const _secureStorage = FlutterSecureStorage();

  late SharedPreferences _prefs;
  String? _ownerRevenuePin;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateOwnerRevenuePinIfNeeded();
    _ownerRevenuePin = await _secureStorage.read(key: _ownerRevenuePinKey);
  }

  AppPreferencesState loadState() {
    return AppPreferencesState(
      themePreference: _readThemePreference(),
      notificationSoundEnabled: _prefs.getBool(_notificationSoundKey) ?? true,
      notificationsEnabled: _prefs.getBool(_notificationsEnabledKey) ?? true,
      reservationRemindersEnabled:
          _prefs.getBool(_reservationRemindersKey) ?? true,
      appUpdatesEnabled: _prefs.getBool(_appUpdatesKey) ?? true,
      ownerRevenueVisible: _prefs.getBool(_ownerRevenueVisibleKey) ?? false,
      ownerRevenuePin: _ownerRevenuePin,
    );
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    await _prefs.setString(_themeKey, value.name);
  }

  Future<void> setNotificationSoundEnabled(bool value) async {
    await _prefs.setBool(_notificationSoundKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool(_notificationsEnabledKey, value);
  }

  Future<void> setReservationRemindersEnabled(bool value) async {
    await _prefs.setBool(_reservationRemindersKey, value);
  }

  Future<void> setAppUpdatesEnabled(bool value) async {
    await _prefs.setBool(_appUpdatesKey, value);
  }

  Future<void> setOwnerRevenueVisible(bool value) async {
    await _prefs.setBool(_ownerRevenueVisibleKey, value);
  }

  Future<void> setOwnerRevenuePin(String value) async {
    await _secureStorage.write(key: _ownerRevenuePinKey, value: value);
    _ownerRevenuePin = value;
  }

  Future<void> clearOwnerRevenuePin() async {
    await _secureStorage.delete(key: _ownerRevenuePinKey);
    _ownerRevenuePin = null;
  }

  bool get locationDisclosureAccepted =>
      _prefs.getBool(_locationDisclosureAcceptedKey) ?? false;

  Future<void> setLocationDisclosureAccepted(bool value) async {
    await _prefs.setBool(_locationDisclosureAcceptedKey, value);
  }

  AppThemePreference _readThemePreference() {
    final raw = _prefs.getString(_themeKey);
    for (final value in AppThemePreference.values) {
      if (value.name == raw) return value;
    }
    return AppThemePreference.system;
  }

  Future<void> _migrateOwnerRevenuePinIfNeeded() async {
    final legacyPin = _prefs.getString(_ownerRevenuePinKey);
    if (legacyPin == null || legacyPin.isEmpty) return;

    final securePin = await _secureStorage.read(key: _ownerRevenuePinKey);
    if (securePin == null || securePin.isEmpty) {
      await _secureStorage.write(key: _ownerRevenuePinKey, value: legacyPin);
    }

    await _prefs.remove(_ownerRevenuePinKey);
  }
}
