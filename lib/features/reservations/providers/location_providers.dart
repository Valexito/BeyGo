import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_api/features/reservations/services/geolocator.dart'
    as helper;

/// Ubicación actual con fallback (misma lógica que ya usabas).
final currentLocationProvider = FutureProvider<LatLng>((ref) async {
  try {
    final loc = await helper.getCurrentLocation();
    print('[LOCATION] success: ${loc.latitude}, ${loc.longitude}');
    return loc;
  } catch (e) {
    print('[LOCATION] error: $e');
    print('[LOCATION] using fallback coordinates');
    return LatLng(14.834999, -91.518669);
  }
});

/// Stream de posición en tiempo real (para seguir al usuario en la ruta).
final positionStreamProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    ),
  ).map((pos) {
    print('[LOCATION STREAM] ${pos.latitude}, ${pos.longitude}');
    return pos;
  });
});
