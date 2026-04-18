// lib/features/reservations/providers/location_providers.dart
//
// ✅ FIXED — All errors resolved:
//   • No latlong2 import
//   • Uses google_maps_flutter.LatLng everywhere
//   • Imports geolocator package explicitly for Geolocator, Position,
//     LocationSettings, LocationAccuracy (was missing → caused "Undefined name")
//   • Imports the geolocator HELPER (getCurrentLocation) from common/services
//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart'; // ← Geolocator, Position, LocationSettings, LocationAccuracy
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ⚠️ Point this to whichever path your geolocator helper is at.
// If at lib/common/services/geolocator.dart:
import 'package:mapbox_api/common/services/geolocator.dart' as helper;
// If at lib/features/reservations/services/geolocator.dart, change to:
// import 'package:mapbox_api/features/reservations/services/geolocator.dart' as helper;

/// One-shot current location — used for map initial position and route origin.
/// Falls back to Xela, Guatemala if GPS is unavailable.
final currentLocationProvider = FutureProvider<LatLng>((ref) async {
  try {
    final loc = await helper.getCurrentLocation();
    debugPrint('[LOCATION] success: ${loc.latitude}, ${loc.longitude}');
    return loc;
  } catch (e) {
    debugPrint('[LOCATION] error: $e → using Xela fallback');
    return const LatLng(14.834999, -91.518669);
  }
});

/// Continuous position stream — for live tracking in route view.
final positionStreamProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    ),
  );
});
