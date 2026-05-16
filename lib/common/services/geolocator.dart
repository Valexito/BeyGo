import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/services/app_navigator.dart';
import 'package:beygo/common/services/app_preferences_service.dart';

Future<LatLng> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception(
      'El servicio de ubicación está desactivado. Activa el GPS.',
    );
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    final accepted = await _ensureLocationDisclosureAccepted();
    if (!accepted) {
      throw Exception('Debes aceptar el uso de ubicación para continuar.');
    }
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      'Permisos de ubicación permanentemente denegados. '
      'Actívalos en Configuración → Aplicaciones.',
    );
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  return LatLng(position.latitude, position.longitude);
}

Future<bool> _ensureLocationDisclosureAccepted() async {
  final prefs = AppPreferencesService.instance;
  if (prefs.locationDisclosureAccepted) return true;

  final context = AppNavigator.key.currentContext;
  if (context == null) {
    return false;
  }

  final accepted =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Uso de tu ubicación'),
              content: const Text(
                'BeyGo usa tu ubicación para mostrarte parqueos cercanos y '
                'trazar rutas hacia ellos. Solo se usa mientras tienes la app '
                'abierta y nunca se comparte con terceros. ¿Continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
      ) ??
      false;

  if (accepted) {
    await prefs.setLocationDisclosureAccepted(true);
  }

  return accepted;
}
