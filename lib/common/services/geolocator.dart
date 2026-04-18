// lib/common/services/geolocator.dart
//
// ✅ NO latlong2 — returns google_maps_flutter.LatLng directly.
// Place this file at BOTH locations if you have two copies:
//   lib/common/services/geolocator.dart
//   lib/features/reservations/services/geolocator.dart
// (same content, just copy it)
//
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<LatLng> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception(
      'El servicio de ubicación está desactivado. Activa el GPS.',
    );
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
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
    desiredAccuracy: LocationAccuracy.high,
  );

  return LatLng(position.latitude, position.longitude);
}
