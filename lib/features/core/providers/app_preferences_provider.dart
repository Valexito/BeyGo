import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/services/app_preferences_service.dart';

final appPreferencesServiceProvider = Provider<AppPreferencesService>((ref) {
  return AppPreferencesService.instance;
});

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferencesState>((ref) {
      return AppPreferencesController(ref.watch(appPreferencesServiceProvider));
    });

class AppPreferencesController extends StateNotifier<AppPreferencesState> {
  AppPreferencesController(this._service) : super(_service.loadState());

  final AppPreferencesService _service;

  Future<void> setThemePreference(AppThemePreference value) async {
    await _service.setThemePreference(value);
    state = state.copyWith(themePreference: value);
  }

  Future<void> setNotificationSoundEnabled(bool value) async {
    await _service.setNotificationSoundEnabled(value);
    state = state.copyWith(notificationSoundEnabled: value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _service.setNotificationsEnabled(value);
    state = state.copyWith(notificationsEnabled: value);
  }

  Future<void> setReservationRemindersEnabled(bool value) async {
    await _service.setReservationRemindersEnabled(value);
    state = state.copyWith(reservationRemindersEnabled: value);
  }

  Future<void> setAppUpdatesEnabled(bool value) async {
    await _service.setAppUpdatesEnabled(value);
    state = state.copyWith(appUpdatesEnabled: value);
  }

  Future<void> setOwnerRevenueVisible(bool value) async {
    await _service.setOwnerRevenueVisible(value);
    state = state.copyWith(ownerRevenueVisible: value);
  }

  Future<void> setOwnerRevenuePin(String value) async {
    await _service.setOwnerRevenuePin(value);
    state = state.copyWith(ownerRevenuePin: value);
  }

  Future<void> clearOwnerRevenuePin() async {
    await _service.clearOwnerRevenuePin();
    state = state.copyWith(clearOwnerRevenuePin: true);
  }
}
