import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { system, light, dark }

class AppPreferencesState {
  final AppThemePreference themePreference;
  final bool notificationSoundEnabled;
  final bool notificationsEnabled;
  final bool reservationRemindersEnabled;
  final bool appUpdatesEnabled;

  const AppPreferencesState({
    required this.themePreference,
    required this.notificationSoundEnabled,
    required this.notificationsEnabled,
    required this.reservationRemindersEnabled,
    required this.appUpdatesEnabled,
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
  }) {
    return AppPreferencesState(
      themePreference: themePreference ?? this.themePreference,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reservationRemindersEnabled:
          reservationRemindersEnabled ?? this.reservationRemindersEnabled,
      appUpdatesEnabled: appUpdatesEnabled ?? this.appUpdatesEnabled,
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

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppPreferencesState loadState() {
    return AppPreferencesState(
      themePreference: _readThemePreference(),
      notificationSoundEnabled: _prefs.getBool(_notificationSoundKey) ?? true,
      notificationsEnabled: _prefs.getBool(_notificationsEnabledKey) ?? true,
      reservationRemindersEnabled:
          _prefs.getBool(_reservationRemindersKey) ?? true,
      appUpdatesEnabled: _prefs.getBool(_appUpdatesKey) ?? true,
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

  AppThemePreference _readThemePreference() {
    final raw = _prefs.getString(_themeKey);
    for (final value in AppThemePreference.values) {
      if (value.name == raw) return value;
    }
    return AppThemePreference.system;
  }
}
